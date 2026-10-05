// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference
// RUN: %target-swift-emit-silgen -enable-experimental-feature AnyReference -module-name main -DSILGEN %s | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// The standard library's `AnyReference` overloads of `===`, `!==`, and
// `ObjectIdentifier.init` are disfavored generics. They must never be chosen
// over the `AnyObject` overloads for Swift classes, and they must not change
// the existing diagnostics for `===`.
//
// Generic AnyReference overloads mangle their layout requirement as `RlzA`,
// so their absence is checked with `CHECK-NOT: RlzA`.

class C {}
class Sub: C {}
class Unrelated {}

// MARK: Existing diagnostics are unchanged

#if !SILGEN
func existingDiagnostics(i: Int?, o: AnyObject, closures: [() -> ()],
                         tc: @escaping () -> ()) {
  _ = (i === nil) // expected-error {{value of type 'Int?' cannot be compared by reference; did you mean to compare by value?}}
  _ = (o === nil) // expected-warning {{comparing non-optional value of type 'AnyObject' to 'nil' always returns false}}
  _ = (o !== nil) // expected-warning {{comparing non-optional value of type 'AnyObject' to 'nil' always returns true}}
  _ = closures.firstIndex { $0 === tc } // expected-error {{cannot check reference equality of functions; operands here have types '() -> ()' and '() -> ()'}}
  _ = 1 === 1
  // expected-error@-1 2 {{argument type 'Int' expected to be an instance of a class or class-constrained type}}
}
#endif

// MARK: Swift classes use the AnyObject overloads

// CHECK-LABEL: // classOperands(_:_:_:)
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3eeeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3neeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}classOperands{{.*}}'
func classOperands(_ a: C, _ b: C?, _ u: Unrelated) -> Bool {
  let r1 = a === b
  let r2 = a !== u
  let r3 = a === Sub()
  let r4 = b === nil
  let r5 = nil === b
  return r1 && r2 && r3 && r4 && r5
}

// CHECK-LABEL: // existentialOperand(_:_:)
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3eeeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}existentialOperand{{.*}}'
func existentialOperand(_ o: AnyObject, _ c: C) -> Bool {
  return o === c
}

// `nil === nil` keeps resolving to the AnyObject overload.
// CHECK-LABEL: // nilAndNil()
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3eeeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}nilAndNil{{.*}}'
func nilAndNil() -> Bool {
  return nil === nil
}

// Class metatypes are not AnyReference; they keep resolving to the AnyObject
// overload.
// CHECK-LABEL: // metatypes()
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3eeeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}metatypes{{.*}}'
func metatypes() -> Bool {
  return C.self === C.self
}

// CHECK-LABEL: // objectIdentifiers(_:_:)
// CHECK-NOT: RlzA
// CHECK: function_ref @$sSOySOyXlcfC
// CHECK-NOT: RlzA
// CHECK: function_ref @$sSOySOyXlcfC
// CHECK-NOT: RlzA
// CHECK: function_ref @$sSOySOypXpcfC
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}objectIdentifiers{{.*}}'
func objectIdentifiers(_ c: C, _ o: AnyObject)
    -> (ObjectIdentifier, ObjectIdentifier, ObjectIdentifier) {
  return (ObjectIdentifier(c), ObjectIdentifier(o), ObjectIdentifier(C.self))
}

// A class-constrained generic context also keeps using AnyObject.
// CHECK-LABEL: // anyObjectGeneric<A>(_:_:)
// CHECK-NOT: RlzA
// CHECK: function_ref @$ss3eeeoiySbyXlSg_ABtF
// CHECK-NOT: RlzA
// CHECK: } // end sil function '{{.*}}anyObjectGeneric{{.*}}'
func anyObjectGeneric<T: AnyObject>(_ a: T, _ b: T) -> Bool {
  return a === b
}

// MARK: AnyReference-constrained generic contexts use the new overloads

// CHECK-LABEL: // anyReferenceGeneric<A, B>(_:_:_:)
// Same-type overload (one generic parameter):
// CHECK: function_ref @$ss3eeeoiySbxSg_ABtRlzAlF :
// CHECK: function_ref @$ss3eeeoiySbxSg_ABtRlzAlF :
// Two-parameter overload:
// CHECK: function_ref @$ss3neeoiySbxSg_q_SgtRlzARl_Ar0_lF :
// CHECK: function_ref @$sSOySOxcRlzAlufC :
// CHECK: } // end sil function '{{.*}}anyReferenceGeneric{{.*}}'
func anyReferenceGeneric<T: AnyReference, U: AnyReference>(
    _ t: T, _ t2: T?, _ u: U) -> Bool {
  let r1 = t === t2      // same-type overload
  let r2 = nil === t2    // same-type overload; needs the single generic param
  let r3 = t !== u       // two-parameter overload
  _ = ObjectIdentifier(t)
  return r1 && r2 && r3
}

#if !SILGEN
func anyReferenceDiagnostics<T: AnyReference>(_ t: T) {
  _ = (t === nil) // expected-warning {{comparing non-optional value of type 'T' to 'nil' always returns false}}
}
#endif
