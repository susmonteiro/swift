// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference
// RUN: %target-swift-frontend -typecheck -enable-experimental-feature AnyReference -debug-generic-signatures %s 2>&1 | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// FIXME: Requirement lowering doesn't turn an 'AnyReference' composition into
// a layout requirement yet, so 'T: AnyReference' is dropped from generic and
// requirement signatures, and existential upper bounds lose the bit. Remove
// the XFAIL once that's implemented.
// XFAIL: *

protocol P {}
protocol Q: P {}
protocol R: P {}

// Generic and requirement signatures keep the layout requirement.

// CHECK-LABEL: .generic@
// CHECK: Generic signature: <T where T : AnyReference>
func generic<T: AnyReference>(_: T) {}

// CHECK-LABEL: .whereClause@
// CHECK: Generic signature: <T where T : AnyReference>
func whereClause<T>(_: T) where T: AnyReference {}

// CHECK-LABEL: .InheritsAnyReference@
// CHECK: Requirement signature: <Self where Self : AnyReference>
protocol InheritsAnyReference: AnyReference {}

// CHECK-LABEL: .AssociatedType@
// CHECK: Requirement signature: <Self where Self.[AssociatedType]A : AnyReference>
protocol AssociatedType { associatedtype A: AnyReference }

// 'any P & AnyReference' is a different type from 'any P'.
func notARedeclaration(_: any P) {}
func notARedeclaration(_: any P & AnyReference) {}

// A protocol that inherits from AnyReference doesn't make the bit redundant.
func notARedeclarationRefProtocol(_: any InheritsAnyReference) {}
func notARedeclarationRefProtocol(_: any InheritsAnyReference & AnyReference) {}

// An arbitrary existential isn't known to be a reference.
func downcast(_ x: any P) {
  let _: any P & AnyReference = x // expected-error {{cannot convert value of type 'any P' to specified type 'any P & AnyReference'}}
}

// The join of two AnyReference existentials keeps the bit.
func join(_ c: Bool, x: any Q & AnyReference, y: any R & AnyReference) {
  let z = c ? x : y
  let _: Int = z // expected-error {{cannot convert value of type 'any P & AnyReference' to specified type 'Int'}}
}
