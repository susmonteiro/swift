// RUN: %target-swift-emit-ir %s -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple | %FileCheck %s
// RUN: %target-swift-emit-ir %s -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple -O | %FileCheck %s --check-prefix=CHECK-OPT

// REQUIRES: swift_feature_AnyReference

// C++ foreign reference types flowing through `T: AnyReference` generics and
// `any AnyReference` existentials are copied with their own retain/release
// operations (through value witnesses), never with Swift's.

import AnyReferenceFRTs

// `T: AnyReference` has the same calling convention as an unconstrained `T`:
// indirect result, indirect argument, and the type metadata, with no extra
// requirement arguments.
// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main7takesARyxxRlzAlF"(ptr noalias sret(%swift.opaque) %0, ptr noalias %1, ptr %T)
// CHECK-NOT: swift_retain
// CHECK-NOT: swift_unknownObjectRetain
// CHECK: ret void
@inline(never)
public func takesAR<T: AnyReference>(_ x: T) -> T { x }

// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main9takesNoneyxxlF"(ptr noalias sret(%swift.opaque) %0, ptr noalias %1, ptr %T)
@inline(never)
public func takesNone<T>(_ x: T) -> T { x }

// `any AnyReference` is passed indirectly, like `Any`.
// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main18takesExistentialARyyypRlsA_XPF"(ptr noalias {{.*}}dereferenceable({{[0-9]+}}) %0)
@inline(never)
public func takesExistentialAR(_ x: any AnyReference) {}

// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main11passFRTToARyyF"()
// CHECK-NOT: call {{.*}} @swift_retain
// CHECK-NOT: call {{.*}} @swift_release
// CHECK-NOT: call {{.*}} @swift_unknownObjectRetain
// CHECK-NOT: call {{.*}} @swift_unknownObjectRelease
// CHECK: call swiftcc void @"$s4main7takesARyxxRlzAlF"
// CHECK-NOT: call {{.*}} @swift_retain
// CHECK-NOT: call {{.*}} @swift_release
// CHECK-NOT: call {{.*}} @swift_unknownObjectRetain
// CHECK-NOT: call {{.*}} @swift_unknownObjectRelease
// CHECK: call void @{{.*}}releaseRefCounted{{.*}}(
// CHECK: }
public func passFRTToAR() {
  let frt = RefCountedType(1)
  _ = takesAR(frt)
}

// CHECK-LABEL: define {{.*}}swiftcc void @"$s4main21eraseFRTToExistentialyyF"()
// CHECK-NOT: call {{.*}} @swift_retain
// CHECK-NOT: call {{.*}} @swift_unknownObjectRetain
// CHECK: call swiftcc void @"$s4main18takesExistentialARyyypRlsA_XPF"
// CHECK-NOT: call {{.*}} @swift_release
// CHECK-NOT: call {{.*}} @swift_unknownObjectRelease
// CHECK: }
public func eraseFRTToExistential() {
  takesExistentialAR(RefCountedType(1))
}

// At runtime, `any AnyReference` is `Any`.
// CHECK-LABEL: define {{.*}}swiftcc ptr @"$s4main15existentialTypeypXpyF"()
// CHECK: ret ptr {{.*}}@"$sypN"
public func existentialType() -> Any.Type {
  (any AnyReference).self
}

// With optimizations (and generic specialization for the FRT), the FRT is
// still never retained or released with Swift's runtime functions.
// CHECK-OPT-LABEL: define {{.*}}swiftcc void @"$s4main11passFRTToARyyF"()
// CHECK-OPT-NOT: swift_retain
// CHECK-OPT-NOT: swift_release
// CHECK-OPT-NOT: swift_unknownObjectRetain
// CHECK-OPT-NOT: swift_unknownObjectRelease
// CHECK-OPT: {{^}}}

// CHECK-OPT-LABEL: define {{.*}}swiftcc void @"$s4main21eraseFRTToExistentialyyF"()
// CHECK-OPT-NOT: swift_retain
// CHECK-OPT-NOT: swift_release
// CHECK-OPT-NOT: swift_unknownObjectRetain
// CHECK-OPT-NOT: swift_unknownObjectRelease
// CHECK-OPT: {{^}}}
