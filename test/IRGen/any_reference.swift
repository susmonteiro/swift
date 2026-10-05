// RUN: %target-swift-frontend -emit-ir %s -enable-experimental-feature AnyReference -module-name main -parse-as-library > %t.ll
// RUN: %FileCheck %s < %t.ll
// RUN: %FileCheck %s --check-prefix=GLOBALS < %t.ll
// RUN: %FileCheck %s --check-prefix=NOCACHE < %t.ll

// REQUIRES: swift_feature_AnyReference

// `AnyReference` is a compile-time-only constraint: it is kept in symbol
// mangling, but erased from runtime metadata (generic requirements, protocol
// requirement signatures, existential type metadata, and reflection names).

public protocol P {}
public protocol PlainP {}
public protocol RefP: AnyReference {}
public class C {}

// Symbol mangling keeps AnyReference: layout letter `A`.
// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main7takesARyyxRlzAlF"(ptr {{.*}}%0, ptr %T)
public func takesAR<T: AnyReference>(_: T) {}

// Reference points: the sizes of `Any` and `any P` existential containers.
// CHECK: define {{.*}}swiftcc void @"$s4main8takesAnyyyypF"(ptr noalias {{.*}}dereferenceable([[ANY_SIZE:[0-9]+]]) %0)
public func takesAny(_: Any) {}

// CHECK: define {{.*}}swiftcc void @"$s4main6takesPyyAA1P_pF"(ptr noalias {{.*}}dereferenceable([[P_SIZE:[0-9]+]]) %0)
public func takesP(_: any P) {}

// `any AnyReference` mangles as a constrained existential, and is passed
// indirectly in a container of the same size as `Any`.
// CHECK: define {{.*}}swiftcc void @"$s4main18takesExistentialARyyypRlsA_XPF"(ptr noalias {{.*}}dereferenceable([[ANY_SIZE]]) %0)
public func takesExistentialAR(_: any AnyReference) {}

// `any P & AnyReference` has the same layout as `any P`.
// CHECK: define {{.*}}swiftcc void @"$s4main11takesPAndARyyAA1P_pRlsA_XPF"(ptr noalias {{.*}}dereferenceable([[P_SIZE]]) %0)
public func takesPAndAR(_: any P & AnyReference) {}

// `AnyObject & AnyReference` is just `AnyObject`.
// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main7takesAOyyxRlzClF"(ptr %0, ptr %T)
public func takesAO<T: AnyObject & AnyReference>(_: T) {}

// The generic context descriptor of `G` has no requirements, exactly like
// that of the unconstrained `U` (NumParams = 1, NumRequirements = 0,
// NumKeyArguments = 1).
// GLOBALS-DAG: @"$s4main1GVMn" = constant <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i16, i16, i8, i8, i8, i8 }> <{ {{.*}}, i16 1, i16 0, i16 1, i16 0, i8 -128, i8 0, i8 0, i8 0 }>
// GLOBALS-DAG: @"$s4main1UVMn" = constant <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i16, i16, i8, i8, i8, i8 }> <{ {{.*}}, i16 1, i16 0, i16 1, i16 0, i8 -128, i8 0, i8 0, i8 0 }>
public struct G<T: AnyReference> {
  public var x: T
  public var y: any AnyReference
}

public struct U<T> {
  public var x: T
  public var y: Any
}

// `RefP` has an empty requirement signature, and it is not class-constrained
// at runtime: the same descriptor as `PlainP`.
// GLOBALS-DAG: @"$s4main4RefPMp" = constant <{ i32, i32, i32, i32, i32, i32 }> <{ i32 65603, {{.*}}, i32 0, i32 0, i32 0 }>
// GLOBALS-DAG: @"$s4main6PlainPMp" = constant <{ i32, i32, i32, i32, i32, i32 }> <{ i32 65603, {{.*}}, i32 0, i32 0, i32 0 }>

// The runtime (reflection) name of `any AnyReference` is `Any`'s: `yp`, and
// there is no separate metadata cache for it.
// NOCACHE-NOT: @"$sypRlsA_XPMD"
// GLOBALS-DAG: @"$s4main1GVMF" = internal constant {{.*}} @"symbolic yp"
// GLOBALS-DAG: @"symbolic yp" = linkonce_odr hidden constant <{ [2 x i8], i8 }> <{ [2 x i8] c"yp", i8 0 }>

// At runtime, `any AnyReference` is `Any`.
// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main15existentialTypeypXpyF"()
// CHECK: ret ptr {{.*}}@"$sypN"
public func existentialType() -> Any.Type {
  (any AnyReference).self
}

// `G<C>` is instantiated like an unconstrained generic type: its mangled name
// for runtime instantiation carries no requirement.
// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main14genericOfClassypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr @"$s4main1GVyAA1CCGMD")
public func genericOfClass() -> Any.Type {
  G<C>.self
}
