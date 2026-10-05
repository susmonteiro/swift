// RUN: %target-swift-emit-silgen %s -enable-experimental-feature AnyReference -module-name main | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// For Swift classes, `T: AnyReference` and `any AnyReference` are lowered like
// an unconstrained `T` and `Any`; the AnyObject lowering (a single retainable
// reference) is only used when AnyObject is also required.

class C {}
protocol RefP: AnyReference {
  func method()
}
final class D: RefP {
  func method() {}
}

// The witness thunk for D.method is like that of a non-class-constrained
// protocol: `self` is passed indirectly.
// CHECK-LABEL: sil private [transparent] [thunk] [ossa] @$s4main1DCAA4RefPA2aDP6methodyyFTW : $@convention(witness_method: RefP) (@in_guaranteed D) -> () {

// CHECK-LABEL: sil hidden [ossa] @$s4main2idyxxRlzAlF : $@convention(thin) <T where T : AnyReference> (@in_guaranteed T) -> @out T {
func id<T: AnyReference>(_ x: T) -> T { x }

// CHECK-LABEL: sil hidden [ossa] @$s4main6idAnyOyxxRlzClF : $@convention(thin) <T where T : AnyObject> (@guaranteed T) -> @owned T {
func idAnyO<T: AnyObject & AnyReference>(_ x: T) -> T { x }

// CHECK-LABEL: sil hidden [ossa] @$s4main11passesClassyyAA1CCF : $@convention(thin) (@guaranteed C) -> () {
// CHECK:   [[ARG:%.*]] = alloc_stack $C
// CHECK:   function_ref @$s4main2idyxxRlzAlF
// CHECK:   apply {{%.*}}<C>(
// CHECK: } // end sil function '$s4main11passesClassyyAA1CCF'
func passesClass(_ c: C) {
  _ = id(c)
}

// CHECK-LABEL: sil hidden [ossa] @$s4main5eraseyypRlsA_XPAA1CCF : $@convention(thin) (@guaranteed C) -> @out any AnyReference {
// CHECK:   [[ADDR:%.*]] = init_existential_addr %0, $C
// CHECK-NOT: init_existential_ref
// CHECK: } // end sil function '$s4main5eraseyypRlsA_XPAA1CCF'
func erase(_ c: C) -> any AnyReference { c }

// `any AnyObject` to `any AnyReference` opens the class existential and
// rewraps it in an opaque existential.
// CHECK-LABEL: sil hidden [ossa] @$s4main14eraseAnyObjectyypRlsA_XPyXlF : $@convention(thin) (@guaranteed AnyObject) -> @out any AnyReference {
// CHECK:   open_existential_ref
// CHECK:   init_existential_addr
// CHECK: } // end sil function '$s4main14eraseAnyObjectyypRlsA_XPyXlF'
func eraseAnyObject(_ x: AnyObject) -> any AnyReference { x }

// `any AnyReference` to `Any` reuses the opaque existential representation.
// CHECK-LABEL: sil hidden [ossa] @$s4main5toAnyyypypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> @out Any {
// CHECK: } // end sil function '$s4main5toAnyyypypRlsA_XPF'
func toAny(_ x: any AnyReference) -> Any { x }

// A protocol refining AnyReference has an opaque existential.
// CHECK-LABEL: sil hidden [ossa] @$s4main9callsRefPyyAA0C1P_pF : $@convention(thin) (@in_guaranteed any RefP) -> () {
// CHECK:   open_existential_addr immutable_access %0 to $*@opened({{.*}}, any RefP) Self
// CHECK:   witness_method $@opened({{.*}}, any RefP) Self, #RefP.method
// CHECK: } // end sil function '$s4main9callsRefPyyAA0C1P_pF'
func callsRefP(_ x: any RefP) {
  x.method()
}

// A protocol that refines both an AnyReference protocol and AnyObject is
// class-bound: its existential and generic parameters are single references
// (@guaranteed), while the inherited RefP witness still takes `self`
// indirectly.
protocol RefAndClassP: RefP, AnyObject {}

// CHECK-LABEL: sil hidden [ossa] @$s4main16takesRefAndClassyyAA0cdE1P_pF : $@convention(thin) (@guaranteed any RefAndClassP) -> () {
// CHECK:   open_existential_ref %0 to $@opened({{.*}}, any RefAndClassP) Self
// CHECK:   witness_method $@opened({{.*}}, any RefAndClassP) Self, #RefP.method {{.*}} : $@convention(witness_method: RefP) <τ_0_0 where τ_0_0 : RefP> (@in_guaranteed τ_0_0) -> ()
// CHECK: } // end sil function '$s4main16takesRefAndClassyyAA0cdE1P_pF'
func takesRefAndClass(_ x: any RefAndClassP) { x.method() }

// CHECK-LABEL: sil hidden [ossa] @$s4main23takesRefAndClassGenericyyxAA0cdE1PRzlF : $@convention(thin) <T where T : RefAndClassP> (@guaranteed T) -> () {
func takesRefAndClassGeneric<T: RefAndClassP>(_ x: T) {}
