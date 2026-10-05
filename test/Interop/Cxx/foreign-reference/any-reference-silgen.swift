// RUN: %target-swift-emit-silgen %s -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// A `T: AnyReference` archetype is lowered exactly like an unconstrained `T`
// (address-only), and `any AnyReference` is an opaque existential, like `Any`.
// Neither uses Swift reference counting for C++ foreign reference types.

import AnyReferenceFRTs

// CHECK-LABEL: sil hidden [ossa] @$s4main7takesARyxxRlzAlF : $@convention(thin) <T where T : AnyReference> (@in_guaranteed T) -> @out T {
// CHECK: bb0(%0 : $*T, %1 : $*T):
// CHECK:   copy_addr %1 to [init] %0
// CHECK: } // end sil function '$s4main7takesARyxxRlzAlF'
func takesAR<T: AnyReference>(_ x: T) -> T { x }

// CHECK-LABEL: sil hidden [ossa] @$s4main9takesNoneyxxlF : $@convention(thin) <T> (@in_guaranteed T) -> @out T {
func takesNone<T>(_ x: T) -> T { x }

// CHECK-LABEL: sil hidden [ossa] @$s4main18takesExistentialARyyypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> () {
func takesExistentialAR(_ x: any AnyReference) {}

// Passing an FRT to a `T: AnyReference` parameter is identical to passing it
// to an unconstrained `T`: through memory, with no Swift retain.
// CHECK-LABEL: sil hidden [ossa] @$s4main11passFRTToARyyF : $@convention(thin) () -> () {
// CHECK:   apply {{%.*}}({{%.*}}) : $@convention(c) (Int32) -> @owned RefCountedType
// CHECK:   [[RESULT:%.*]] = alloc_stack $RefCountedType
// CHECK:   [[ARG:%.*]] = alloc_stack $RefCountedType
// CHECK:   [[BORROWED:%.*]] = store_borrow {{%.*}} to [[ARG]]
// CHECK:   [[FN:%.*]] = function_ref @$s4main7takesARyxxRlzAlF : $@convention(thin) <τ_0_0 where τ_0_0 : AnyReference> (@in_guaranteed τ_0_0) -> @out τ_0_0
// CHECK:   apply [[FN]]<RefCountedType>([[RESULT]], [[BORROWED]])
// CHECK-NOT: strong_retain
// CHECK-NOT: unmanaged_retain_value
// CHECK: } // end sil function '$s4main11passFRTToARyyF'
func passFRTToAR() {
  let frt = RefCountedType(1)
  _ = takesAR(frt)
}

// CHECK-LABEL: sil hidden [ossa] @$s4main21eraseFRTToExistentialyyF : $@convention(thin) () -> () {
// CHECK:   [[EXIST:%.*]] = alloc_stack $any AnyReference
// CHECK:   [[ADDR:%.*]] = init_existential_addr [[EXIST]], $RefCountedType
// CHECK:   store {{%.*}} to [init] [[ADDR]]
// CHECK:   function_ref @$s4main18takesExistentialARyyypRlsA_XPF
// CHECK:   destroy_addr [[EXIST]]
// CHECK-NOT: init_existential_ref
// CHECK: } // end sil function '$s4main21eraseFRTToExistentialyyF'
func eraseFRTToExistential() {
  takesExistentialAR(RefCountedType(1))
}

// CHECK-LABEL: sil hidden [ossa] @$s4main26eraseImmortalToExistentialyyF : $@convention(thin) () -> () {
// CHECK:   init_existential_addr {{%.*}}, $ImmortalRefType
// CHECK: } // end sil function '$s4main26eraseImmortalToExistentialyyF'
func eraseImmortalToExistential() {
  takesExistentialAR(getImmortal())
}

// Opening an `any AnyReference` to pass it to a generic (SE-0352).
// CHECK-LABEL: sil hidden [ossa] @$s4main15openExistentialyyypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> () {
// CHECK:   open_existential_addr immutable_access %0 to $*@opened({{.*}}, any AnyReference) Self
// CHECK:   function_ref @$s4main7takesARyxxRlzAlF
// CHECK: } // end sil function '$s4main15openExistentialyyypRlsA_XPF'
func openExistential(_ x: any AnyReference) {
  _ = takesAR(x)
}

// Erasing a Swift class to `any AnyReference` also uses an opaque existential.
class SwiftClass {}

// CHECK-LABEL: sil hidden [ossa] @$s4main23eraseClassToExistentialyyF : $@convention(thin) () -> () {
// CHECK:   init_existential_addr {{%.*}}, $SwiftClass
// CHECK-NOT: init_existential_ref
// CHECK: } // end sil function '$s4main23eraseClassToExistentialyyF'
func eraseClassToExistential() {
  takesExistentialAR(SwiftClass())
}

// `T: AnyObject & AnyReference` is just `T: AnyObject`, with the usual
// single-reference lowering.
// CHECK-LABEL: sil hidden [ossa] @$s4main4bothyxxRlzClF : $@convention(thin) <T where T : AnyObject> (@guaranteed T) -> @owned T {
func both<T: AnyObject & AnyReference>(_ x: T) -> T { x }

// FIXME: (follow-up) Pre-existing FRT-superclass hole, out of scope for the
// AnyReference change (see plan.md, "Explicitly out of scope"). A generic
// parameter bounded by an FRT superclass gets a NativeClass layout, so
// `ObjectIdentifier(x)` currently resolves to the `AnyObject` overload and
// wraps the C++ object in a Swift class existential. The follow-up that fixes
// FRT-bounded archetypes should flip this to the `T: AnyReference` overload
// (no `init_existential_ref`).
// CHECK-LABEL: sil hidden [ossa] @$s4main20forwardFRTSuperclassySOxSo14RefCountedTypeVRbzlF : $@convention(thin) <T where T : RefCountedType> (@guaranteed T) -> ObjectIdentifier {
// CHECK:   init_existential_ref {{%.*}} : $T : $T, $AnyObject
// CHECK:   function_ref @$sSOySOyXlcfC : $@convention(method) (@owned AnyObject, @thin ObjectIdentifier.Type) -> ObjectIdentifier
// CHECK: } // end sil function '$s4main20forwardFRTSuperclassySOxSo14RefCountedTypeVRbzlF'
func forwardFRTSuperclass<T: RefCountedType>(_ x: T) -> ObjectIdentifier {
  ObjectIdentifier(x)
}
