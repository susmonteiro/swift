// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference
// RUN: not %target-swift-frontend -typecheck -enable-experimental-feature AnyReference -debug-generic-signatures -diagnostic-style llvm %s 2>&1 | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// Minimization of the `AnyReference` layout requirement. `AnyObject` (or a
// superclass requirement) always wins over `AnyReference`.

class C {}
struct S {}

// CHECK-LABEL: .justAR@
// CHECK-NEXT: Generic signature: <T where T : AnyReference>
func justAR<T: AnyReference>(_: T) {}

// CHECK-LABEL: .composition@
// CHECK-NEXT: Generic signature: <T where T : AnyObject>
func composition<T: AnyObject & AnyReference>(_: T) {}

// CHECK-LABEL: .whereClause@
// CHECK-NEXT: Generic signature: <T where T : AnyObject>
func whereClause<T>(_: T) where T: AnyReference, T: AnyObject {}

// CHECK-LABEL: .superclass@
// CHECK-NEXT: Generic signature: <T where T : C>
func superclass<T: C>(_: T) where T: AnyReference {}

// CHECK-LABEL: .superclassComposition@
// CHECK-NEXT: Generic signature: <T where T : C>
func superclassComposition<T: C & AnyReference>(_: T) {}

// CHECK-LABEL: .ARProto@
// CHECK-NEXT: Requirement signature: <Self where Self : AnyReference>
protocol ARProto: AnyReference {}

// CHECK-LABEL: .AOAndARProto@
// CHECK-NEXT: Requirement signature: <Self where Self : AnyObject>
protocol AOAndARProto: AnyObject, AnyReference {}

// CHECK-LABEL: .RefinesARProto@
// CHECK-NEXT: Requirement signature: <Self where Self : ARProto>
protocol RefinesARProto: ARProto, AnyReference {}

// CHECK-LABEL: .ARAssocType@
// CHECK-NEXT: Requirement signature: <Self where Self.[ARAssocType]A : AnyReference>
protocol ARAssocType {
  associatedtype A: AnyReference
}

// The requirement implied by a protocol is not restated.
// CHECK-LABEL: .viaProtocol@
// CHECK-NEXT: Generic signature: <T where T : ARProto>
func viaProtocol<T: ARProto>(_: T) where T: AnyReference {}

// CHECK-LABEL: .viaProtocolAndAnyObject@
// CHECK-NEXT: Generic signature: <T where T : AnyObject, T : ARProto>
func viaProtocolAndAnyObject<T: ARProto & AnyObject>(_: T) {}

struct G<T: AnyReference> {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=G
// CHECK-NEXT: Generic signature: <T where T == C>
extension G where T == C {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=G
// CHECK-NEXT: Generic signature: <T where T : AnyObject>
extension G where T: AnyObject {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=G
// CHECK-NEXT: Generic signature: <T where T : C>
extension G where T: C {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=G
// CHECK-NEXT: Generic signature: <T where T : AnyReference, T == S>
extension G where T == S {}
// expected-error@-1 {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == S'}}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=G
// CHECK-NEXT: Generic signature: <T where T : AnyReference, T == Int>
extension G where T == Int {}
// expected-error@-1 {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == Int'}}

struct H<U> {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=H
// CHECK-NEXT: Generic signature: <U where U == C>
extension H where U == C, U: AnyReference {}

// CHECK-LABEL: ExtensionDecl line={{.*}} base=H
// CHECK-NEXT: Generic signature: <U where U : AnyReference, U == S>
extension H where U == S, U: AnyReference {}
// expected-error@-1 {{no type for 'U' can satisfy both 'U : AnyReference' and 'U == S'}}

// A same-type requirement to an existential does not satisfy AnyReference:
// `any AnyReference` itself is not a single reference.
// CHECK-LABEL: ExtensionDecl line={{.*}} base=H
// CHECK-NEXT: Generic signature: <U where U : AnyReference, U == any AnyReference>
extension H where U == any AnyReference, U: AnyReference {}
// expected-error@-1 {{no type for 'U' can satisfy both 'U : AnyReference' and 'U == any AnyReference'}}

// `any AnyObject` does satisfy it, like it satisfies AnyObject.
// CHECK-LABEL: ExtensionDecl line={{.*}} base=H
// CHECK-NEXT: Generic signature: <U where U == AnyObject>
extension H where U == AnyObject, U: AnyReference {}

// Metatypes are not references.
// CHECK-LABEL: ExtensionDecl line={{.*}} base=H
// CHECK-NEXT: Generic signature: <U where U : AnyReference, U == C.Type>
extension H where U == C.Type, U: AnyReference {}
// expected-error@-1 {{no type for 'U' can satisfy both 'U : AnyReference' and 'U == C.Type'}}
