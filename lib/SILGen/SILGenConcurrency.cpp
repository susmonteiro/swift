//===--- SILGenConcurrency.cpp - Concurrency-specific SILGen --------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "ArgumentSource.h"
#include "ExecutorBreadcrumb.h"
#include "RValue.h"
#include "Scope.h"
#include "swift/AST/ASTContext.h"
#include "swift/AST/AvailabilityContext.h"
#include "swift/AST/ConformanceLookup.h"
#include "swift/AST/DistributedDecl.h"
#include "swift/AST/ProtocolConformance.h"
#include "swift/Basic/Assertions.h"
#include "swift/Basic/Range.h"

using namespace swift;
using namespace Lowering;

static void setExpectedExecutorForGeneric(SILGenFunction &SGF) {
  auto loc = RegularLocation::getAutoGeneratedLocation(SGF.F.getLocation());
  SGF.ExpectedExecutor.set(SGF.emitGenericExecutor(loc));
}

static void setExpectedExecutorForGlobalActor(SILGenFunction &SGF,
                                              Type globalActor) {
  SGF.ExpectedExecutor.set(SGF.emitLoadGlobalActorExecutor(globalActor));
}

static void setExpectedExecutorForLocalVar(SILGenFunction &SGF,
                                           VarDecl *var) {
  auto loc = RegularLocation::getAutoGeneratedLocation(SGF.F.getLocation());
  Type actorType = var->getTypeInContext();
  RValue actorInstanceRV = SGF.emitRValueForDecl(
      loc, var, actorType, AccessSemantics::Ordinary);
  ManagedValue actorInstance =
      std::move(actorInstanceRV).getScalarValue();
  SGF.ExpectedExecutor.set(SGF.emitLoadActorExecutor(loc, actorInstance));
}

static void
setExpectedExecutorForParameterIsolation(SILGenFunction &SGF,
                                         ActorIsolation actorIsolation) {
  auto loc = RegularLocation::getAutoGeneratedLocation(SGF.F.getLocation());

  if (actorIsolation.isActorInstanceIsolated()) {
    if (actorIsolation.isActorInstanceForSelfParameter()) {
      ManagedValue selfMV;
      auto selfArg = SGF.F.getSelfArgument();
      if (selfArg->getOwnershipKind() == OwnershipKind::Guaranteed) {
        selfMV = ManagedValue::forBorrowedRValue(selfArg);
      } else {
        selfMV = ManagedValue::forUnmanagedOwnedValue(selfArg);
      }
      SGF.ExpectedExecutor.set(SGF.emitLoadActorExecutor(loc, selfMV));
      return;
    }

    // See if our actorIsolation actually has an actor instance associated with
    // it.
    if (auto param = actorIsolation.getActorInstance()) {
      return setExpectedExecutorForLocalVar(SGF, param);
    }
  }

  // If we have caller isolation inheriting... just grab from our isolated
  // argument.
  if (actorIsolation.getKind() == ActorIsolation::CallerIsolationInheriting) {
    auto *isolatedArg = SGF.F.maybeGetIsolatedArgument();
    ASSERT(isolatedArg &&
           "Caller Isolation Inheriting without isolated parameter");
    ManagedValue isolatedMV;
    if (isolatedArg->getOwnershipKind() == OwnershipKind::Guaranteed) {
      isolatedMV = ManagedValue::forBorrowedRValue(isolatedArg);
    } else {
      isolatedMV = ManagedValue::forUnmanagedOwnedValue(isolatedArg);
    }

    SGF.ExpectedExecutor.set(SGF.emitLoadActorExecutor(loc, isolatedMV));
    return;
  }

  llvm_unreachable("Unhandled case?!");
}

void SILGenFunction::emitExpectedExecutorProlog() {
  // Whether the given declaration context is nested within an actor's
  // destructor.
  auto isInActorDestructor = [](DeclContext *dc) {
    while (!dc->isModuleScopeContext() && !dc->isTypeContext()) {
      if (auto destructor = dyn_cast<DestructorDecl>(dc)) {
        switch (getActorIsolation(destructor)) {
        case ActorIsolation::ActorInstance:
          return true;

        case ActorIsolation::GlobalActor:
          // Global-actor-isolated types should likely have deinits that
          // are not themselves actor-isolated, yet still have access to
          // the instance properties of the class.
          return false;

        case ActorIsolation::Nonisolated:
        case ActorIsolation::NonisolatedUnsafe:
        case ActorIsolation::Unspecified:
        case ActorIsolation::CallerIsolationInheriting:
          return false;

        case ActorIsolation::Erased:
          llvm_unreachable("deinit cannot have erased isolation");
        }
      }

      dc = dc->getParent();
    }

    return false;
  };

  // Initialize ExpectedExecutor if:
  // - this function is async or
  // - this function is sync and isolated to an actor, and we want to
  //   dynamically check that we're on the right executor.
  //
  // Actor destructors are isolated in the sense that we now have a
  // unique reference to the actor, but we probably aren't running on
  // the actor's executor, so we cannot safely do this check.
  //
  // Defer bodies are always called synchronously within their enclosing
  // function, so the check is unnecessary; in addition, we cannot
  // necessarily perform the check because the defer may not have
  // captured the isolated parameter of the enclosing function, and
  // forcing a capture would cause DI problems in actor initializers.
  bool wantDataRaceChecks = [&] {
    if (F.isAsync() || F.isDefer())
      return false;

    if (getOptions().EnableActorDataRaceChecks &&
        !isInActorDestructor(FunctionDC))
      return true;

    if (getASTContext().LangOpts.isDynamicActorIsolationCheckingEnabled()) {
      if (auto closure = dyn_cast<ClosureExpr>(FunctionDC))
        if (closure->requiresDynamicIsolationChecking())
          return true;
    }

    return false;
  }();

  // FIXME: Avoid loading and checking the expected executor if concurrency is
  // unavailable. This is specifically relevant for MainActor-isolated contexts,
  // which are allowed to be available on OSes where concurrency is not
  // available. rdar://106827064

  if (auto *funcDecl =
        dyn_cast_or_null<AbstractFunctionDecl>(FunctionDC->getAsDecl())) {
    auto actorIsolation = getActorIsolation(funcDecl);
    switch (actorIsolation.getKind()) {
    case ActorIsolation::Unspecified:
    case ActorIsolation::Nonisolated:
    case ActorIsolation::NonisolatedUnsafe:
      break;

    case ActorIsolation::Erased:
      llvm_unreachable("method cannot have erased isolation");

    case ActorIsolation::ActorInstance: {
      // Only produce an executor for actor-isolated functions that are async
      // or are local functions. The former require a hop, while the latter
      // are prone to dynamic data races in code that does not enforce Sendable
      // completely.
      if (F.isAsync() ||
          (wantDataRaceChecks && funcDecl->isLocalCapture())) {
        auto loweredCaptures = SGM.Types.getLoweredLocalCaptures(SILDeclRef(funcDecl));
        if (auto isolatedParam = loweredCaptures.getIsolatedParamCapture()) {
          setExpectedExecutorForLocalVar(*this, isolatedParam);
        } else {
          setExpectedExecutorForParameterIsolation(*this, actorIsolation);
        }
      }
      break;
    }

    case ActorIsolation::CallerIsolationInheriting:
      assert(F.isAsync());
      setExpectedExecutorForParameterIsolation(*this, actorIsolation);
      break;

    case ActorIsolation::GlobalActor:
      if (F.isAsync() || wantDataRaceChecks) {
        auto globalActorType = F.mapTypeIntoContext(actorIsolation.getGlobalActor());
        setExpectedExecutorForGlobalActor(*this, globalActorType);
      }
      break;
    }
  } else if (auto *closureExpr = dyn_cast<AbstractClosureExpr>(FunctionDC)) {
    bool wantExecutor = F.isAsync() || wantDataRaceChecks;

    auto actorIsolation = closureExpr->getActorIsolation();
    switch (actorIsolation.getKind()) {
    case ActorIsolation::Unspecified:
    case ActorIsolation::Nonisolated:
    case ActorIsolation::NonisolatedUnsafe:
      break;

    case ActorIsolation::CallerIsolationInheriting:
      assert(F.isAsync());
      setExpectedExecutorForParameterIsolation(*this, actorIsolation);
      break;

    case ActorIsolation::Erased:
      llvm_unreachable("closure cannot have erased isolation");

    case ActorIsolation::ActorInstance: {
      if (wantExecutor) {
        setExpectedExecutorForLocalVar(*this, actorIsolation.getActorInstance());
      }
      break;
    }

    case ActorIsolation::GlobalActor:
      if (wantExecutor) {
        auto globalActorType = F.mapTypeIntoContext(actorIsolation.getGlobalActor());
        setExpectedExecutorForGlobalActor(*this, globalActorType);
        break;
      }
    }
  }

  // In async functions, the generic executor is our expected executor
  // if we don't have any sort of isolation.
  if (!ExpectedExecutor.isValid()) {
    if (F.isAsync() && !unsafelyInheritsExecutor()) {
      setExpectedExecutorForGeneric(*this);
    } else {
      ExpectedExecutor.setUnnecessary();
    }
  }
  assert(ExpectedExecutor.isValid());

  // Jump to the expected executor.
  if (ExpectedExecutor.isNecessary()) {
    auto executor = ExpectedExecutor.getEager(); // never lazy
    if (F.isAsync()) {
      // For an async function, hop to the executor.
      B.createHopToExecutor(
          RegularLocation::getDebugOnlyLocation(F.getLocation(), getModule()),
          executor,
          /*mandatory*/ false);
    } else {
      // For a synchronous function, check that we're on the same executor.
      // Note: if we "know" that the code is completely Sendable-safe, this
      // is unnecessary. The type checker will need to make this determination.
      emitPreconditionCheckExpectedExecutor(
                    RegularLocation::getAutoGeneratedLocation(F.getLocation()),
                    executor);
    }
  }
}

void SILGenFunction::emitConstructorExpectedExecutorProlog() {
  auto ctor = cast<ConstructorDecl>(F.getDeclRef().getDecl());

  // In async actor initializers that are isolated to self, we need
  // to emit the ExpectedExecutor reference lazily.
  if (ctor->hasAsync()) {
    auto isolation = getActorIsolation(ctor);
    auto selfDecl = ctor->getImplicitSelfDecl();

    if (isolation.getKind() == ActorIsolation::ActorInstance &&
        isolation.getActorInstance() == selfDecl) {
      assert(isCtorWithHopsInjectedByDefiniteInit());
      ExpectedExecutor.setLazy();

      auto loc = SILLocation(selfDecl);
      loc.markAsPrologue();
      loc = loc.asAutoGenerated();

      auto initialExecutor = emitGenericExecutor(loc);
      B.createHopToExecutor(loc, initialExecutor, /*mandatory*/ false);
      return;
    }
  }

  // Otherwise, emit the normal expected executor prolog.
  emitExpectedExecutorProlog();
}

void SILGenFunction::emitPrologGlobalActorHop(SILLocation loc,
                                              Type globalActor) {
  auto executor = emitLoadGlobalActorExecutor(globalActor);
  ExpectedExecutor.set(executor);
  B.createHopToExecutor(RegularLocation::getDebugOnlyLocation(loc, getModule()),
                        executor, /*mandatory*/ false);
}

SILValue SILGenFunction::emitMainExecutor(SILLocation loc) {
  auto &ctx = getASTContext();
  auto builtinName = ctx.getIdentifier(
      getBuiltinName(BuiltinValueKind::BuildMainActorExecutorRef));
  auto resultType = SILType::getPrimitiveObjectType(ctx.TheExecutorType);

  return B.createBuiltin(loc, builtinName, resultType, {}, {});
}

SILValue SILGenFunction::emitGenericExecutor(SILLocation loc) {
  // The generic executor is encoded as the nil value of
  // std::optional<Builtin.SerialExecutor>.
  auto ty = SILType::getOptionalType(
              SILType::getPrimitiveObjectType(
                getASTContext().TheExecutorType));
  return B.createOptionalNone(loc, ty);
}

ManagedValue SILGenFunction::emitNonIsolatedIsolation(SILLocation loc) {
  return B.createManagedOptionalNone(loc,
                     SILType::getOpaqueIsolationType(getASTContext()));
}

SILValue SILGenFunction::emitLoadGlobalActorExecutor(Type globalActor) {
  auto loc = RegularLocation::getAutoGeneratedLocation(F.getLocation());
  auto actorAndFormalType =
    emitLoadOfGlobalActorShared(loc, globalActor->getCanonicalType());
  return emitLoadActorExecutor(loc, actorAndFormalType.first);
}

std::pair<ManagedValue, CanType>
SILGenFunction::emitLoadOfGlobalActorShared(SILLocation loc, CanType actorType) {
  NominalTypeDecl *nominal = actorType->getNominalOrBoundGenericNominal();
  VarDecl *sharedInstanceDecl = nominal->getGlobalActorInstance();
  assert(sharedInstanceDecl && "no shared actor field in global actor");
  SubstitutionMap subs =
    actorType->getContextSubstitutionMap();
  Type instanceType =
    actorType->getTypeOfMember(sharedInstanceDecl);

  auto metaRepr =
    nominal->isResilient(SGM.SwiftModule, F.getResilienceExpansion())
    ? MetatypeRepresentation::Thick
    : MetatypeRepresentation::Thin;

  CanType actorMetaType = CanMetatypeType::get(actorType, metaRepr);
  ManagedValue actorMetaTypeValue =
      ManagedValue::forObjectRValueWithoutOwnership(B.createMetatype(
          loc, SILType::getPrimitiveObjectType(actorMetaType)));

  RValue actorInstanceRV = emitRValueForStorageLoad(loc, actorMetaTypeValue,
    actorMetaType, /*isSuper*/ false, sharedInstanceDecl, PreparedArguments(),
    subs, AccessSemantics::Ordinary, instanceType, SGFContext());
  ManagedValue actorInstance = std::move(actorInstanceRV).getScalarValue();
  return {actorInstance, instanceType->getCanonicalType()};
}

ManagedValue
SILGenFunction::emitGlobalActorIsolation(SILLocation loc,
                                         CanType globalActorType) {
  // Load the .shared property.  Note that this isn't necessarily a value
  // of the global actor type.
  auto actorAndFormalType = emitLoadOfGlobalActorShared(loc, globalActorType);

  // Since it's just a normal actor instance, we can use the normal path.
  return emitActorInstanceIsolation(loc, actorAndFormalType.first,
                                    actorAndFormalType.second);
}

static ProtocolConformanceRef
getActorConformance(SILGenFunction &SGF, CanType actorType) {
  auto &ctx = SGF.getASTContext();
  auto proto = ctx.getProtocol(KnownProtocolKind::Actor);
  return lookupConformance(actorType, proto);
}

static ProtocolConformanceRef
getDistributedActorConformance(SILGenFunction &SGF, CanType actorType) {
  auto &ctx = SGF.getASTContext();
  auto proto = ctx.getProtocol(KnownProtocolKind::DistributedActor);
  return lookupConformance(actorType, proto);
}

/// Given a value of some non-optional distributed actor type, convert it
/// to the non-optional `any Actor` type.
static ManagedValue
emitDistributedActorIsolation(SILGenFunction &SGF, SILLocation loc,
                              ManagedValue actor, CanType actorType) {
  // First, open the actor type if it's an existential type.
  if (actorType->isExistentialType()) {
    CanType openedType = ExistentialArchetypeType::getAny(actorType)
        ->getCanonicalType();
    SILType loweredOpenedType = SGF.getLoweredType(openedType);

    actor = SGF.emitOpenExistential(loc, actor, loweredOpenedType,
                                    AccessKind::Read);
    actorType = openedType;
  }

  // Build <T: DistributedActor> and its substitutions for actorType.
  // Doing this manually is ill-advised in general, but this is such a
  // simple case that it's okay.
  auto distributedActorConf = getDistributedActorConformance(SGF, actorType);
  auto sig = distributedActorConf.getProtocol()->getGenericSignature();
  auto distributedActorSubs = SubstitutionMap::get(sig, {actorType},
                                                   {distributedActorConf});

  // Use that to build the magical conformance to Actor for the distributed
  // actor type.
  return SGF.emitDistributedActorAsAnyActor(loc, distributedActorSubs, actor);
}

/// Given a value of some non-optional actor type, convert it to
/// non-optional `any Actor` type.
static ManagedValue
emitNonOptionalActorInstanceIsolation(SILGenFunction &SGF, SILLocation loc,
                                      ManagedValue actor, CanType actorType,
                                      SILType anyActorTy) {
  // If we have an `any Actor` already, we're done.
  if (actor.getType() == anyActorTy)
    return actor;

  CanType anyActorType = anyActorTy.getASTType();

  // If the actor is a distributed actor, (1) it had better be local
  // and (2) we need to use the special conformance.
  if (actorType->isDistributedActor()) {
    return emitDistributedActorIsolation(SGF, loc, actor, actorType);
  }

  return SGF.emitTransformExistential(loc, actor, actorType, anyActorType);
}

ManagedValue
SILGenFunction::emitActorInstanceIsolation(SILLocation loc, ManagedValue actor,
                                           CanType actorType) {
  // $Optional<any Actor>
  auto optionalAnyActorTy = SILType::getOpaqueIsolationType(getASTContext());
  // Optional<any Actor> as a formal type (it's invariant to lowering)
  auto optionalAnyActorType = optionalAnyActorTy.getASTType();

  // If we started with an Optional<any Actor>, we're done.
  if (actorType == optionalAnyActorType) {
    return actor;
  }

  // Otherwise, if we have an optional value, we need to transform the payload.
  auto actorObjectType = actorType.getOptionalObjectType();
  if (actorObjectType) {
    return emitOptionalToOptional(loc, actor, optionalAnyActorTy,
        [&](SILGenFunction &SGF, SILLocation loc, ManagedValue actorObject,
            SILType anyActorTy, SGFContext C) {
      return emitNonOptionalActorInstanceIsolation(*this, loc, actorObject,
                                                   actorObjectType, anyActorTy);
    });
  }

  // Otherwise, transform the non-optional value we have, then inject that
  // into Optional.
  SILType anyActorTy = optionalAnyActorTy.getOptionalObjectType();
  ManagedValue anyActor =
    emitNonOptionalActorInstanceIsolation(*this, loc, actor, actorType,
                                          anyActorTy);

  // Inject into `Optional`.
  auto result = B.createOptionalSome(loc, anyActor);
  return result;
}

SILValue SILGenFunction::emitLoadActorExecutor(SILLocation loc,
                                               ManagedValue actor) {
  // FIXME: Checking for whether we're in a formal evaluation scope
  // like this doesn't seem like a good pattern.
  SILValue actorV;
  if (isInFormalEvaluationScope())
    actorV = actor.formalAccessBorrow(*this, loc).getValue();
  else
    actorV = actor.borrow(*this, loc).getValue();

  // For now, we just want to emit a hop_to_executor directly to the
  // actor; LowerHopToActor will add the emission logic necessary later.
  return actorV;
}

/// If we are in an actor initializer that is isolated to self, the
/// current isolation is flow-sensitive: it will be nil before self is
/// initialized, and afterwards it will be the value of self.
/// Call a builtin that the definite initialization pass will rewrite.
ManagedValue
SILGenFunction::emitFlowSensitiveSelfIsolation(SILLocation loc,
                                               ActorIsolation isolation) {
  auto isolatedVar = isolation.getActorInstance();

#ifndef NDEBUG
  {
    auto ctor = cast<ConstructorDecl>(F.getDeclRef().getDecl());
    assert(isolatedVar == ctor->getImplicitSelfDecl());
  }
#endif

  CanType actorType = isolatedVar->getTypeInContext()->getCanonicalType();
  assert(actorType->isAnyActorType());

  ASTContext &ctx = getASTContext();

  Identifier builtinName;
  ProtocolConformanceRef conformance;
  if (isolation.isDistributedActor()) {
    // Create a reference to the asLocalActor getter.  We don't call this
    // immediately, but we need to make sure it's available later when the
    // mandatory passes clean this up.
    auto asLocalActorDecl = getDistributedActorAsLocalActorComputedProperty(
        F.getDeclContext()->getParentModule());
    auto asLocalActorGetter = asLocalActorDecl->getAccessor(AccessorKind::Get);
    SILDeclRef asLocalActorRef = SILDeclRef(
        asLocalActorGetter, SILDeclRef::Kind::Func);
    (void) emitGlobalFunctionRef(loc, asLocalActorRef);

    builtinName = ctx.getIdentifier(
        getBuiltinName(BuiltinValueKind::FlowSensitiveDistributedSelfIsolation));
    conformance = getDistributedActorConformance(*this, actorType);
  } else {
    builtinName = ctx.getIdentifier(
        getBuiltinName(BuiltinValueKind::FlowSensitiveSelfIsolation));
    conformance = getActorConformance(*this, actorType);
  }
  SGM.useConformance(conformance);

  SubstitutionMap subs = SubstitutionMap::getProtocolSubstitutions(
      conformance.getProtocol(), actorType, conformance);
  auto origActor =
    maybeEmitValueOfLocalVarDecl(isolatedVar, AccessKind::Read).getValue();
  SILType resultTy = SILType::getOpaqueIsolationType(ctx);
  auto call = B.createBuiltin(loc, builtinName, resultTy, subs, origActor);
  return ManagedValue::forForwardedRValue(*this, call);
}

SILValue SILGenFunction::emitLoadErasedExecutor(SILLocation loc,
                                                ManagedValue fn) {
  // As with emitLoadActorExecutor, we just emit the actor reference
  // for now and let LowerHopToActor deal with the executor projection.
  return emitLoadErasedIsolation(loc, fn).getUnmanagedValue();
}

ManagedValue
SILGenFunction::emitLoadErasedIsolation(SILLocation loc,
                                        ManagedValue fn) {
  fn = fn.borrow(*this, loc);

  // This expects a borrowed function and returns a borrowed (any Actor)?.
  auto actor = B.createFunctionExtractIsolation(loc, fn.getValue());

  return ManagedValue::forBorrowedObjectRValue(actor);
}

ManagedValue
SILGenFunction::emitFunctionTypeIsolation(SILLocation loc,
                                          FunctionTypeIsolation isolation,
                                          ManagedValue fn) {
  switch (isolation.getKind()) {

  // Parameter-isolated functions don't have a specific actor they're isolated
  // to; they're essentially polymorphic over isolation.
  case FunctionTypeIsolation::Kind::Parameter:
    llvm_unreachable("cannot load isolation from parameter-isoaltion function "
                     "reference");

  // Emit nonisolated by simply emitting Optional.none in the result type.
  case FunctionTypeIsolation::Kind::NonIsolated:
  case FunctionTypeIsolation::Kind::NonIsolatedCaller:
    return emitNonIsolatedIsolation(loc);

  // Emit global actor isolation by loading .shared from the global actor,
  // erasing it into `any Actor`, and injecting that into Optional.
  case FunctionTypeIsolation::Kind::GlobalActor: {
    return emitGlobalActorIsolation(loc,
             isolation.getGlobalActorType()->getCanonicalType());
  }

  // Emit @isolated(any) isolation by loading the actor reference from the
  // function.
  case FunctionTypeIsolation::Kind::Erased: {
    Scope scope(*this, CleanupLocation(loc));
    auto value = emitLoadErasedIsolation(loc, fn).copy(*this, loc);
    return scope.popPreservingValue(value);
  }
  }

  llvm_unreachable("bad kind");
}

static ActorIsolation getClosureIsolationInfo(SILDeclRef constant) {
  if (auto closure = constant.getAbstractClosureExpr()) {
    return closure->getActorIsolation();
  }
  auto func = constant.getAbstractFunctionDecl();
  assert(func && "unexpected closure constant");
  return getActorIsolation(func);
}

static ManagedValue emitLoadOfCaptureIsolation(SILGenFunction &SGF,
                                               SILLocation loc,
                                               VarDecl *isolatedCapture,
                                               SILDeclRef constant,
                                               ArrayRef<ManagedValue> captureArgs) {
  auto &TC = SGF.SGM.Types;
  auto captureInfo = TC.getLoweredLocalCaptures(constant);

  auto isolatedVarType = isolatedCapture->getTypeInContext()->getCanonicalType();

  // Capture arguments are 1-1 with the lowered capture info.
  auto captures = captureInfo.getCaptures();
  for (auto i : indices(captures)) {
    const auto &capture = captures[i];
    if (capture.isDynamicSelfMetadata()) continue;
    auto capturedVar = capture.getDecl();
    if (capturedVar != isolatedCapture) continue;

    // Captured actor references should always be captured as constants.
    assert(TC.getDeclCaptureKind(capture,
                                 TC.getCaptureTypeExpansionContext(constant))
             == CaptureKind::Constant);

    auto value = captureArgs[i].copy(SGF, loc);
    return SGF.emitActorInstanceIsolation(loc, value, isolatedVarType);
  }

  // The capture not being a lowered capture can happen in global code.
  auto value = SGF.emitRValueForDecl(loc, isolatedCapture, isolatedVarType,
                                     AccessSemantics::Ordinary)
                  .getAsSingleValue(SGF, loc);
  return SGF.emitActorInstanceIsolation(loc, value, isolatedVarType);
}

ManagedValue
SILGenFunction::emitClosureIsolation(SILLocation loc, SILDeclRef constant,
                                     ArrayRef<ManagedValue> captures) {
  auto isolation = getClosureIsolationInfo(constant);
  switch (isolation) {
  case ActorIsolation::Unspecified:
  case ActorIsolation::Nonisolated:
  case ActorIsolation::CallerIsolationInheriting:
  case ActorIsolation::NonisolatedUnsafe:
    return emitNonIsolatedIsolation(loc);

  case ActorIsolation::Erased:
    llvm_unreachable("closures cannot directly have erased isolation");

  case ActorIsolation::GlobalActor: {
    auto globalActorType = F.mapTypeIntoContext(isolation.getGlobalActor())
                               ->getCanonicalType();
    return emitGlobalActorIsolation(loc, globalActorType);
  }

  case ActorIsolation::ActorInstance: {
    assert(isolation.isActorInstanceForCapture());
    auto capture = isolation.getActorInstance();
    assert(capture);
    return emitLoadOfCaptureIsolation(*this, loc, capture, constant, captures);
  }
  }
  llvm_unreachable("bad kind");
}

ExecutorBreadcrumb
SILGenFunction::emitHopToTargetActor(SILLocation loc,
                                     std::optional<ActorIsolation> maybeIso,
                                     std::optional<ManagedValue> maybeSelf) {
  if (!maybeIso)
    return ExecutorBreadcrumb();

  if (auto executor = emitExecutor(loc, *maybeIso, maybeSelf)) {
    return emitHopToTargetExecutor(loc, *executor);
  } else {
    return ExecutorBreadcrumb();
  }
}

namespace {

class HopToActorCleanup : public Cleanup {
  SILValue value;

public:
  HopToActorCleanup(SILValue value) : value(value) {}

  void emit(SILGenFunction &SGF, CleanupLocation l,
            ForUnwind_t forUnwind) override {
    SGF.B.createHopToExecutor(l, value, false /*mandatory*/);
  }

  void dump(SILGenFunction &) const override {
#ifndef NDEBUG
    llvm::errs() << "HopToExecutorCleanup\n"
                 << "State:" << getState() << "\n"
                 << "Value:" << value << "\n";
#endif
  }
};
} // end anonymous namespace

CleanupHandle SILGenFunction::emitScopedHopToTargetActor(SILLocation loc,
                                                         SILValue actor) {
  Cleanups.pushCleanup<HopToActorCleanup>(actor);
  return Cleanups.getTopCleanup();
}

ExecutorBreadcrumb SILGenFunction::emitHopToTargetExecutor(
    SILLocation loc, SILValue executor) {
  // Record that we need to hop back to the current executor.
  auto breadcrumb = ExecutorBreadcrumb(true);
  B.createHopToExecutor(RegularLocation::getDebugOnlyLocation(loc, getModule()),
                        executor, /*mandatory*/ false);
  return breadcrumb;
}

std::optional<SILValue>
SILGenFunction::emitExecutor(SILLocation loc, ActorIsolation isolation,
                             std::optional<ManagedValue> maybeSelf) {
  switch (isolation.getKind()) {
  case ActorIsolation::Unspecified:
  case ActorIsolation::Nonisolated:
  case ActorIsolation::CallerIsolationInheriting:
  case ActorIsolation::NonisolatedUnsafe:
    return std::nullopt;

  case ActorIsolation::Erased:
    llvm_unreachable("executor emission for erased isolation is unimplemented");

  case ActorIsolation::ActorInstance: {
    // "self" here means the actor instance's "self" value.
    assert(maybeSelf.has_value() && "actor-instance but no self provided?");
    auto self = maybeSelf.value();
    return emitLoadActorExecutor(loc, self);
  }

  case ActorIsolation::GlobalActor: {
    auto globalActorType = F.mapTypeIntoContext(isolation.getGlobalActor());
    return emitLoadGlobalActorExecutor(globalActorType);
  }
  }
  llvm_unreachable("covered switch");
}

void SILGenFunction::emitHopToActorValue(SILLocation loc, ManagedValue actor) {
  // TODO: can the type system enforce this async requirement?
  if (!F.isAsync()) {
    llvm::report_fatal_error("Builtin.hopToActor must be in an async function");
  }
  auto isolation =
      getActorIsolationOfContext(FunctionDC, [](AbstractClosureExpr *CE) {
        return CE->getActorIsolation();
      });
  if (isolation != ActorIsolation::Nonisolated &&
      isolation != ActorIsolation::NonisolatedUnsafe &&
      isolation != ActorIsolation::Unspecified) {
    // TODO: Explicit hop with no hop-back should only be allowed in nonisolated
    // async functions. But it needs work for any closure passed to
    // Task.detached, which currently has unspecified isolation.
    llvm::report_fatal_error(
      "Builtin.hopToActor must be in an actor-independent function");
  }
  SILValue executor = emitLoadActorExecutor(loc, actor);
  B.createHopToExecutor(RegularLocation::getDebugOnlyLocation(loc, getModule()),
                        executor, /*mandatory*/ true);
}

static bool isCheckExpectedExecutorIntrinsicAvailable(SILGenModule &SGM) {
  auto checkExecutor = SGM.getCheckExpectedExecutor();
  if (!checkExecutor)
    return false;

  // Forego a check if instrinsic is unavailable, this could happen
  // in main-actor context.
  auto &C = checkExecutor->getASTContext();
  if (!C.LangOpts.DisableAvailabilityChecking) {
    auto deploymentAvailability = AvailabilityContext::forDeploymentTarget(C);
    auto declAvailability =
        AvailabilityContext::forDeclSignature(checkExecutor);
    return deploymentAvailability.isContainedIn(declAvailability);
  }

  return true;
}

void SILGenFunction::emitPreconditionCheckExpectedExecutor(
    SILLocation loc, ActorIsolation isolation,
    std::optional<ManagedValue> actorSelf) {
  if (!isCheckExpectedExecutorIntrinsicAvailable(SGM))
    return;

  auto executor = emitExecutor(loc, isolation, actorSelf);
  assert(executor);
  emitPreconditionCheckExpectedExecutor(loc, *executor);
}

void SILGenFunction::emitPreconditionCheckExpectedExecutor(
    SILLocation loc, SILValue executorOrActor) {
  if (!isCheckExpectedExecutorIntrinsicAvailable(SGM))
    return;

  // We don't want the debugger to step into these.
  loc.markAutoGenerated();

  // If the function is isolated to an optional actor reference,
  // check dynamically whether it's non-null.  We don't need to
  // do an assertion if the expected expected is nil.
  SILBasicBlock *noneBB = nullptr;
  bool isOptional = (bool) executorOrActor->getType().getOptionalObjectType();
  if (isOptional) {
    // Start by emiting the .some path.
    noneBB = createBasicBlock();
    auto someBB = createBasicBlockBefore(noneBB);

    executorOrActor =
      B.createSwitchOptional(loc, executorOrActor, someBB, noneBB,
                             executorOrActor->getOwnershipKind());

    B.emitBlock(someBB);
  }

  // Get the executor.
  SILValue executor = B.createExtractExecutor(loc, executorOrActor);

  // Call the library function that performs the checking.
  auto args = emitSourceLocationArgs(loc.getSourceLoc(), loc);

  emitApplyOfLibraryIntrinsic(
      loc, SGM.getCheckExpectedExecutor(), SubstitutionMap(),
      {args.filenameStartPointer, args.filenameLength, args.filenameIsAscii,
       args.line, ManagedValue::forObjectRValueWithoutOwnership(executor)},
      SGFContext());

  // Complete the optional control flow if we had an optional value.
  if (isOptional) {
    assert(noneBB);
    // Finish the .some path by branching to the continuation block.
    auto contBB = createBasicBlockAfter(noneBB);
    B.createBranch(loc, contBB);

    // The .none path is trivial.
    B.emitBlock(noneBB);
    B.createBranch(loc, contBB);

    B.emitBlock(contBB);
  }
}

bool SILGenFunction::unsafelyInheritsExecutor() {
  if (auto fn = dyn_cast<AbstractFunctionDecl>(FunctionDC))
    return fn->getAttrs().hasAttribute<UnsafeInheritExecutorAttr>();
  return false;
}

void ExecutorBreadcrumb::emit(SILGenFunction &SGF, SILLocation loc) {
  if (mustReturnToExecutor) {
    assert(SGF.ExpectedExecutor.isValid());
    if (SGF.ExpectedExecutor.isNecessary()) {
      FullExpr scope(SGF.Cleanups, CleanupLocation(loc));
      auto executor = SGF.emitExpectedExecutor(loc);
      SGF.B.createHopToExecutor(
          RegularLocation::getDebugOnlyLocation(loc, SGF.getModule()),
          executor.getValue(), /*mandatory*/ false);
    }
  }
}

ManagedValue SILGenFunction::emitExpectedExecutor(SILLocation loc) {
  assert(ExpectedExecutor.isNecessary() &&
         "prolog failed to set up expected executor?");

  // Fast (common) path: we have an eagerly-set expected executor.
  if (ExpectedExecutor.isEager()) {
    return ManagedValue::forBorrowedObjectRValue(ExpectedExecutor.getEager());
  }

  // Otherwise, the current function must have lazy, flow-sensitive isolation.
  auto ctor = cast<ConstructorDecl>(F.getDeclRef().getDecl());
  auto isolation = getActorIsolation(ctor);
  return emitFlowSensitiveSelfIsolation(loc, isolation);
}

ManagedValue
SILGenFunction::emitDistributedActorAsAnyActor(SILLocation loc,
                                           SubstitutionMap distributedActorSubs,
                                               ManagedValue actorValue) {
  auto &ctx = SGM.getASTContext();

  auto distributedActorAsActorConformance =
      getDistributedActorAsActorConformance(ctx);
  auto actorProto = ctx.getProtocol(KnownProtocolKind::Actor);
  auto distributedActorType = distributedActorSubs.getReplacementTypes()[0];
  auto ref = ProtocolConformanceRef(ctx.getSpecializedConformance(
                      distributedActorType, distributedActorAsActorConformance,
                      distributedActorSubs));
  ProtocolConformanceRef conformances[1] = {ref};

  // Erase the distributed actor instance into an `any Actor` existential with
  // the special conformance.
  CanType distributedActorCanType = distributedActorType->getCanonicalType();
  auto &distributedActorTL = getTypeLowering(distributedActorCanType);
  auto &anyActorTL = getTypeLowering(actorProto->getDeclaredExistentialType());
  return emitExistentialErasure(
      loc, distributedActorCanType, distributedActorTL, anyActorTL,
      ctx.AllocateCopy(conformances), SGFContext(),
      [actorValue](SGFContext) { return actorValue; });
}
