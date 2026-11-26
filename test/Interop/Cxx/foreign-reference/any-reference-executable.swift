// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -target %target-swift-5.8-abi-triple -enable-experimental-feature AnyReference)
// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -target %target-swift-5.8-abi-triple -enable-experimental-feature AnyReference -O)
// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -target %target-swift-5.8-abi-triple)

// REQUIRES: executable_test
// REQUIRES: swift_feature_AnyReference

// The last RUN line checks that clients that don't enable AnyReference can
// still use ObjectIdentifier and the identity operators with foreign reference
// types.

import AnyReferenceFRTs
import StdlibUnittest

var AnyReferenceTests = TestSuite("AnyReference")

let manager = ObjectManager.get()

class SwiftClass {}

#if $AnyReference
func identityFunc<T: _AnyReference>(_ t: T) -> T {
  return t
}

func anyFunc(_ t: any _AnyReference) -> any _AnyReference {
  return t
}

// Unspecialized generic code doesn't know which kind of reference counting
// its argument uses.
@inline(never)
@_semantics("optimize.sil.specialize.generic.never")
func genericIdentifier<T: _AnyReference>(_ t: T) -> ObjectIdentifier {
  return ObjectIdentifier(t)
}

@inline(never)
@_semantics("optimize.sil.specialize.generic.never")
func genericIdentical<T: _AnyReference>(_ a: T, _ b: T) -> Bool {
  return a === b && !(a !== b)
}

@inline(never)
@_semantics("optimize.sil.specialize.generic.never")
func genericIdentical<T: _AnyReference>(_ a: T?, _ b: T?) -> Bool {
  return a === b && !(a !== b)
}

AnyReferenceTests.test("Pass to generic and existential parameters") {
  // The object is created at +1 and destroyed at the end of its scope, so
  // every copy must be balanced: exactly one more release than retains.
  manager.reset()
  do {
    let rft = RefCountedType(5)
    expectTrue(identityFunc(rft) === rft)
    expectEqual(ObjectIdentifier(identityFunc(rft)), ObjectIdentifier(rft))
    _ = anyFunc(rft)
  }
  expectEqual(manager.getTotalRetains() + 1, manager.getTotalReleases())
}

AnyReferenceTests.test("Unspecialized generic code") {
  let a = RefCountedType(1)
  let b = RefCountedType(1)
  let c = SwiftClass()
  let d = SwiftClass()
  let none: RefCountedType? = nil

  withExtendedLifetime((a, b, c, d)) {
    manager.reset()

    expectEqual(genericIdentifier(a), ObjectIdentifier(a))
    expectNotEqual(genericIdentifier(a), genericIdentifier(b))
    expectEqual(genericIdentifier(getImmortal()),
                ObjectIdentifier(getImmortal()))
    expectEqual(genericIdentifier(c), ObjectIdentifier(c))

    expectTrue(genericIdentical(a, a))
    expectFalse(genericIdentical(a, b))
    expectTrue(genericIdentical(getImmortal(), getImmortal()))
    expectFalse(genericIdentical(getImmortal(), getOtherImmortal()))
    expectTrue(genericIdentical(c, c))
    expectFalse(genericIdentical(c, d))

    expectTrue(genericIdentical(Optional(a), Optional(a)))
    expectFalse(genericIdentical(Optional(a), Optional(b)))
    expectFalse(genericIdentical(a, none))
    expectTrue(genericIdentical(none, none))
    expectTrue(genericIdentical(Optional(c), Optional(c)))

    expectEqual(manager.getTotalRetains(), manager.getTotalReleases())
  }
}
#endif

AnyReferenceTests.test("ObjectIdentifier") {
  let a = RefCountedType(1)
  let b = RefCountedType(1)
  let aSelf = a.getSelf()
  let derived = DerivedRefCountedType(2)
  let derivedBase = derived.asBase()

  withExtendedLifetime((a, b, aSelf, derived, derivedBase)) {
    manager.reset()

    expectEqual(ObjectIdentifier(a), ObjectIdentifier(aSelf))
    expectNotEqual(ObjectIdentifier(a), ObjectIdentifier(b))
    expectEqual(ObjectIdentifier(derived), ObjectIdentifier(derivedBase))
    expectEqual(ObjectIdentifier(getImmortal()),
                ObjectIdentifier(getImmortal()))
    expectNotEqual(ObjectIdentifier(getImmortal()),
                   ObjectIdentifier(getOtherImmortal()))
    expectEqual(2, Set([ObjectIdentifier(a), ObjectIdentifier(aSelf),
                        ObjectIdentifier(b)]).count)

    // The identifier is the address of the C++ object.
    expectEqual(UInt(bitPattern: ObjectIdentifier(a)),
                UInt(bitPattern: addressOf(a)))

    // Creating an identifier neither retains nor releases the object.
    expectEqual(0, manager.getTotalRetains())
    expectEqual(0, manager.getTotalReleases())
  }
}

AnyReferenceTests.test("Identity operators") {
  let a = RefCountedType(1)
  let b = RefCountedType(1)
  let aSelf = a.getSelf()
  let derived = DerivedRefCountedType(2)
  let derivedBase = derived.asBase()
  let none: RefCountedType? = nil

  withExtendedLifetime((a, b, aSelf, derived, derivedBase)) {
    manager.reset()

    expectTrue(a === aSelf)
    expectFalse(a === b)
    expectFalse(a !== aSelf)
    expectTrue(a !== b)
    expectTrue(derived === derivedBase)
    expectTrue(getImmortal() === getImmortal())
    expectTrue(getImmortal() !== getOtherImmortal())

    expectTrue(none === nil)
    expectFalse(none !== nil)
    expectFalse(a === none)
    expectTrue(a !== none)
    expectTrue(Optional(a) === aSelf)
    expectFalse(Optional(a) !== aSelf)
    expectTrue(Optional(a) === Optional(aSelf))
    expectFalse(Optional(a) === Optional(b))

    // Any retain needed to wrap an argument in an Optional is balanced.
    expectEqual(manager.getTotalRetains(), manager.getTotalReleases())
  }
}

runAllTests()
