// RUN: %target-swift-emit-silgen -I %S%{fs-sep}Inputs -target %target-swift-5.8-abi-triple -cxx-interoperability-mode=default %s | %FileCheck %s

// Clients that don't enable AnyReference can use ObjectIdentifier and the
// identity operators with foreign reference types, while Swift classes keep
// using the AnyObject overloads.

import AnyReferenceFRTs

class SwiftClass {}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}classIdentifier
// CHECK: function_ref ObjectIdentifier.init(_:)
// CHECK-NEXT: function_ref @$sSOySOyXlcfC : $@convention(method) (@owned AnyObject, @thin ObjectIdentifier.Type) -> ObjectIdentifier
func classIdentifier(_ c: SwiftClass) -> ObjectIdentifier {
  ObjectIdentifier(c)
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}referenceIdentifier
// CHECK: function_ref ObjectIdentifier.init<A>(_:)
// CHECK-NEXT: function_ref @$sSOySOxhcRlzORi_zRi1_zlufC : $@convention(method) <τ_0_0 where τ_0_0 : _AnyReference, τ_0_0 : ~Copyable, τ_0_0 : ~Deinitable> (@in_guaranteed τ_0_0, @thin ObjectIdentifier.Type) -> ObjectIdentifier
func referenceIdentifier(_ r: RefCountedType) -> ObjectIdentifier {
  ObjectIdentifier(r)
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}classIdentical
// CHECK: function_ref === infix(_:_:)
// CHECK-NEXT: function_ref @$ss3eeeoiySbyXlSg_ABtF : $@convention(thin) (@guaranteed Optional<AnyObject>, @guaranteed Optional<AnyObject>) -> Bool
func classIdentical(_ a: SwiftClass, _ b: SwiftClass) -> Bool {
  a === b
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}genericClassIdentical
// CHECK: function_ref === infix(_:_:)
// CHECK-NEXT: function_ref @$ss3eeeoiySbyXlSg_ABtF : $@convention(thin) (@guaranteed Optional<AnyObject>, @guaranteed Optional<AnyObject>) -> Bool
func genericClassIdentical<T: AnyObject>(_ a: T, _ b: T) -> Bool {
  a === b
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}referenceIdentical
// CHECK: function_ref === infix<A>(_:_:)
// CHECK-NEXT: function_ref @$ss3eeeoiySbxSg_ABtRlzORi_zlF : $@convention(thin) <τ_0_0 where τ_0_0 : _AnyReference, τ_0_0 : ~Copyable> (@in_guaranteed Optional<τ_0_0>, @in_guaranteed Optional<τ_0_0>) -> Bool
func referenceIdentical(_ a: RefCountedType, _ b: RefCountedType) -> Bool {
  a === b
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}optionalReferenceIdentical
// CHECK: function_ref === infix<A>(_:_:)
// CHECK-NEXT: function_ref @$ss3eeeoiySbxSg_ABtRlzORi_zlF : $@convention(thin) <τ_0_0 where τ_0_0 : _AnyReference, τ_0_0 : ~Copyable> (@in_guaranteed Optional<τ_0_0>, @in_guaranteed Optional<τ_0_0>) -> Bool
func optionalReferenceIdentical(_ a: RefCountedType, _ b: RefCountedType?) -> Bool {
  a === b
}

// CHECK-LABEL: sil hidden [ossa] @{{.*}}referenceNotIdentical
// CHECK: function_ref !== infix<A>(_:_:)
// CHECK-NEXT: function_ref @$ss3neeoiySbxSg_ABtRlzORi_zlF : $@convention(thin) <τ_0_0 where τ_0_0 : _AnyReference, τ_0_0 : ~Copyable> (@in_guaranteed Optional<τ_0_0>, @in_guaranteed Optional<τ_0_0>) -> Bool
func referenceNotIdentical(_ a: RefCountedType, _ b: RefCountedType) -> Bool {
  a !== b
}
