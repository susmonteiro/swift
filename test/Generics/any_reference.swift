// RUN: %target-swift-frontend -typecheck -enable-experimental-feature AnyReference -debug-generic-signatures %s 2>&1 | %FileCheck %s
// RUN: %target-swift-frontend -emit-silgen -enable-experimental-feature AnyReference %s | %FileCheck --check-prefix=SIL %s
// RUN: %target-swift-frontend -emit-ir -enable-experimental-feature AnyReference %s | %FileCheck --check-prefix=IR %s

// REQUIRES: swift_feature_AnyReference

class C {}
protocol ClassP: AnyObject {}

// 'T: AnyReference' is lowered to a layout requirement.
// CHECK-LABEL: .takesAnyReference@
// CHECK-NEXT: Generic signature: <T where T : AnyReference>
func takesAnyReference<T: AnyReference>(_: T) {}

// AnyObject, a superclass or a class-bound protocol makes it redundant.
// CHECK-LABEL: .withAnyObject@
// CHECK-NEXT: Generic signature: <T where T : AnyObject>
func withAnyObject<T: AnyReference>(_: T) where T: AnyObject {}

// CHECK-LABEL: .withAnyObjectFirst@
// CHECK-NEXT: Generic signature: <T where T : AnyObject>
func withAnyObjectFirst<T: AnyObject>(_: T) where T: AnyReference {}

// CHECK-LABEL: .withSuperclass@
// CHECK-NEXT: Generic signature: <T where T : C>
func withSuperclass<T: AnyReference>(_: T) where T: C {}

// CHECK-LABEL: .withClassProtocol@
// CHECK-NEXT: Generic signature: <T where T : ClassP>
func withClassProtocol<T: AnyReference>(_: T) where T: ClassP {}

// A protocol can require it, too.
// CHECK-LABEL: .RefP@
// CHECK-NEXT: Requirement signature: <Self where Self : AnyReference>
protocol RefP: AnyReference {}

// A generic type with an AnyReference requirement. The requirement is erased
// from its runtime metadata.
// CHECK-LABEL: .Box@
// CHECK-NEXT: Generic signature: <T where T : AnyReference>
struct Box<T: AnyReference> {
  var value: T
}

// A concrete same-type requirement to a class makes it redundant.
struct Generic<T> {}
// CHECK-LABEL: ExtensionDecl line={{.*}} base=Generic
// CHECK-NEXT: Generic signature: <T where T == C>
extension Generic where T == C, T: AnyReference {}

// The requirement is part of the symbol name ('RlzA'), but values of type 'T'
// are still passed indirectly: it does not change the representation.
// SIL-LABEL: sil hidden [ossa] @$s{{.*}}takesAnyReference{{.*}}RlzAlF : $@convention(thin) <T where T : AnyReference> (@in_guaranteed T) -> () {

// IRGen emits the nominal type descriptor of 'Box' without the requirement.
// IR: @"$s{{.*}}3BoxVMn" = hidden constant
// IR-LABEL: define hidden swiftcc void @"$s{{.*}}takesAnyReference{{.*}}RlzAlF"(ptr noalias %0, ptr %T)
