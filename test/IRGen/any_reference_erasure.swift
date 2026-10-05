// RUN: %target-swift-frontend -emit-ir %s -enable-experimental-feature AnyReference -module-name main -parse-as-library -target %target-swift-5.9-abi-triple > %t.ll
// RUN: %FileCheck %s < %t.ll
// RUN: %FileCheck %s --check-prefix=NOAR < %t.ll

// Debug info keeps AnyReference in its (DWARF) manglings; this checks that
// they can be reconstructed (asserts builds abort otherwise).
// Note: the round-trip check and the "conflicting types for one UID" check in
// IRGenDebugInfo only fire in compilers built with assertions; in a
// no-asserts build this RUN line only checks that -g compilation succeeds.
// RUN: %target-swift-frontend -emit-ir -g %s -enable-experimental-feature AnyReference -module-name main -parse-as-library -target %target-swift-5.9-abi-triple -o /dev/null

// REQUIRES: swift_feature_AnyReference

// `AnyReference` is erased at runtime, like marker protocols. This test pins
// that no runtime mangled name, metadata cache, generic environment or
// extended existential shape records it. (See also any_reference.swift.)

// No runtime type reference string ever contains an AnyReference layout
// requirement, and metadata caches are shared with the erased types.
// NOAR-NOT: symbolic {{[^"]*}}Rl{{[sz]}}A
// NOAR-NOT: c"{{[^"]*}}Rl{{[sz]}}A
// NOAR-NOT: @"$s{{[^"]*}}RlsA_XP{{[^"]*}}MD"
// Outlined value operations are shared with the erased types too.
// NOAR-NOT: @"$s{{[^"]*}}RlsA_XP{{[^"]*}}WO

public protocol P {}
public class C {}

public struct S<T: AnyReference> {
  public var x: T
}

// The generic environment of a key path in a context with `T: AnyReference`
// records no requirements: flags = 1 generic parameter level, 0 requirements.
// CHECK-DAG: @"generic environment RlzAl" = linkonce_odr hidden constant <{ i32, i16, i8, [1 x i8] }> <{ i32 1, i16 1, i8 -128, [1 x i8] zeroinitializer }>
public func genericKeyPath<T: AnyReference>(_: T.Type) -> AnyKeyPath {
  \S<T>.x
}

// Opaque type descriptors: the generic context of `o` (in `MXX`) records no
// requirement for `T: AnyReference` (1 param, 0 requirements, 1 key argument),
// and the opaque type descriptor only records the `some P` conformance.
// CHECK-DAG: @"$s4main1oyQrxRlzAlFMXX" = linkonce_odr hidden constant {{.*}} i16 1, i16 0, i16 1, i16 0, i8 -128,
// CHECK-DAG: @"$s4main1oyQrxRlzAlFQOMQ" = constant {{.*}} i16 2, i16 1, i16 3, i16 0, i8 -128, i8 -128,
public struct PS: P {}
public func o<T: AnyReference>(_: T) -> some P { PS() }

// Protocol requirement signatures: `associatedtype A: AnyReference` adds no
// requirement to the signature (NumRequirementsInSignature = 0), only the
// associated type requirement itself (NumRequirements = 1).
// CHECK-DAG: @"$s4main2PAMp" = constant {{.*}} i32 0, i32 1, i32 {{.*}}%swift.protocol_requirement
public protocol PA { associatedtype A: AnyReference }

// Capture descriptors: the generic signature of a capture box is `l` (no
// requirement), not `RlzAl`.
// CHECK-DAG: c"xz_x_lXX"
// NOAR-NOT: c"{{[^"]*}}RlzA{{[^"]*}}XX"
public func capg<T: AnyReference>(_ t: T) -> () -> Void {
  var u = t
  return { u = t }
}

// Existential metadata is that of the erased existential.
// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main10pAndARMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr [[P_CACHE:@"\$s4main1P_pMD"]])
public func pAndARMeta() -> Any.Type {
  (any P & AnyReference).self
}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main5pMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr [[P_CACHE]])
public func pMeta() -> Any.Type {
  (any P).self
}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main11arrayARMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr @"$sSayypGMD")
public func arrayARMeta() -> Any.Type {
  [any AnyReference].self
}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main21existentialMetaARMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr @"$sypXpMD")
public func existentialMetaARMeta() -> Any.Type {
  (any AnyReference.Type).self
}

// A parameterized existential with AnyReference uses the same extended
// existential shape as the one without it.
// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main9seqARMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr [[SEQ_CACHE:@"\$sST_pSi7ElementSTRts_XPMD"]])
public func seqARMeta() -> Any.Type {
  (any Sequence<Int> & AnyReference).self
}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main7seqMetaypXpyF"()
// CHECK: call ptr @__swift_instantiateConcreteTypeFromMangledName(ptr [[SEQ_CACHE]])
public func seqMeta() -> Any.Type {
  (any Sequence<Int>).self
}

// Symbol manglings keep AnyReference.
// CHECK-DAG: define {{.*}}swiftcc void @"$s4main6takesEyyypRlsA_XPXpF"(ptr %0)
public func takesE(_: any AnyReference.Type) {}

// CHECK-DAG: define {{.*}}swiftcc void @"$s4main8takesSeqyyST_pRlsA_Si7ElementSTRtsXPF"(ptr noalias {{.*}}%0)
public func takesSeq(_: any Sequence<Int> & AnyReference) {}

// CHECK-DAG: define {{.*}}swiftcc void @"$s4main10takesArrayyySayypRlsA_XPGF"(ptr %0)
public func takesArray(_: [any AnyReference]) {}

// Debug info for a sugared composition (`any P & AnyReference`, where
// `AnyReference` is a typealias member) must round-trip.
public func sugared(_ x: any P & AnyReference, _ c: C) -> any AnyReference {
  let local: any P & AnyReference = x
  _ = local
  return c
}

// Outlined copies of `any AnyReference` / `any P & AnyReference` values are
// the ones of `Any` / `any P`.
// CHECK-DAG: define {{.*}}@"$sypWOc"(
// CHECK-DAG: define {{.*}}@"$s4main1P_pWOc"(
public func copyAR(_ x: any AnyReference) -> (any AnyReference, any AnyReference) {
  (x, x)
}

// Debug info for sugared compositions that canonicalization folds away
// (AnyObject wins over AnyReference; duplicate AnyReference members) must not
// emit conflicting types for one mangled name (covered by the -g RUN line).
// CHECK-DAG: define {{.*}}swiftcc void @"$s4main10aoAndARDupyyyXlF"(ptr %0)
public func aoAndARDup(_ x: AnyObject & AnyReference) {}
// CHECK-DAG: define {{.*}}swiftcc void @"$s4main10arAndAODupyyyXlF"(ptr %0)
public func arAndAODup(_ x: AnyReference & AnyObject) {}
// CHECK-DAG: define {{.*}}swiftcc void @"$s4main10arAndARDupyyypRlsA_XPF"(ptr noalias {{.*}}%0)
public func arAndARDup(_ x: AnyReference & AnyReference) {}
public func cAndAR(_ x: C & AnyReference) {}
public protocol Q {}
public func qAndARDup(_ x: any Q & AnyReference & AnyReference) {}
