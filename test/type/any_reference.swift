// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// `AnyReference` as a type: like `AnyObject`, it is a class-constraint empty
// protocol composition, but it is satisfied by every reference type (Swift
// classes and C++ foreign reference types), and `any AnyReference` is an
// opaque existential.

class C {}
final class D: C {}
struct S {}
enum E { case a }
protocol P {}
protocol ClassP: AnyObject {}
protocol RefP: AnyReference {}

// Spellings.
func bare(_: AnyReference) {}
func explicitAny(_: any AnyReference) {}
func opaqueParam(_: some AnyReference) {}
func optional(_: (any AnyReference)?) {}
func metatype(_: (any AnyReference).Type) {}
func composition(_: any P & AnyReference) {}
func compositionWithAnyObject(_: any AnyObject & AnyReference) {}
func generic<T: AnyReference>(_: T) {}
func genericWhere<T>(_: T) where T: AnyReference {}
typealias MyAnyReference = AnyReference

// `AnyObject & AnyReference` is `AnyObject`.
func sameType(_ x: any AnyObject & AnyReference) -> AnyObject { x }
func sameType2(_ x: AnyObject) -> any AnyObject & AnyReference { x }

// Swift classes, class-bound existentials and class-constrained archetypes
// convert to `any AnyReference`.
func conversions<T: AnyObject, U: C, V: RefP>(
  _ c: C, _ d: D, _ ao: AnyObject, _ cp: any ClassP, _ rp: any RefP,
  _ t: T, _ u: U, _ v: V
) {
  let _: any AnyReference = c
  let _: any AnyReference = d
  let _: any AnyReference = ao
  let _: any AnyReference = cp
  let _: any AnyReference = rp
  let _: any AnyReference = t
  let _: any AnyReference = u
  let _: any AnyReference = v
  let _: (any AnyReference)? = c
  let _: [any AnyReference] = [c, d, ao, cp, rp, t, u, v]
}

// `any AnyReference` converts to `Any`, but not to `AnyObject`.
func fromExistential(_ x: any AnyReference) {
  let _: Any = x
  let _: Any? = x
  let _: AnyObject = x // expected-error {{value of type 'any AnyReference' expected to be instance of class or class-constrained type}}
  let _: any ClassP = x // expected-error {{value of type 'any AnyReference' does not conform to specified type 'ClassP'}}
}

// Value types and metatypes do not convert.
func rejectedConversions() {
  let _: any AnyReference = S() // expected-error {{cannot convert value of type 'S' to specified type 'any AnyReference'}}
  let _: any AnyReference = E.a // expected-error {{cannot convert value of type 'E' to specified type 'any AnyReference'}}
  let _: any AnyReference = 1 // expected-error {{cannot convert value of type 'Int' to specified type 'any AnyReference'}}
  let _: any AnyReference = C.self // expected-error {{cannot convert value of type 'C.Type' to specified type 'any AnyReference'}}
  let _: any AnyReference = { } // expected-error {{cannot convert value of type '() -> ()' to specified type 'any AnyReference'}}
  let _: any AnyReference = (C(), C()) // expected-error {{cannot convert value of type '(C, C)' to specified type 'any AnyReference'}}
}

func takesAR<T: AnyReference>(_: T) {}
// expected-note@-1 * {{where 'T' = }}

func rejectedGenericArguments(_ p: any P, _ any: Any) {
  takesAR(S()) // expected-error {{global function 'takesAR' requires that 'S' be a class or foreign reference type}}
  takesAR(1) // expected-error {{global function 'takesAR' requires that 'Int' be a class or foreign reference type}}
  takesAR(C.self) // expected-error {{global function 'takesAR' requires that 'C.Type' be a class or foreign reference type}}
  takesAR(p) // expected-error {{global function 'takesAR' requires that 'any P' be a class or foreign reference type}}
  takesAR(any) // expected-error {{global function 'takesAR' requires that 'Any' be a class or foreign reference type}}
}

// SE-0352 implicit opening.
func opened(_ x: any AnyReference, _ y: any RefP) {
  takesAR(x)
  takesAR(y)
}

// `T: AnyReference` does not imply `T: AnyObject`.
func takesAO<T: AnyObject>(_: T) {}
func notAnyObject<T: AnyReference>(_ x: T) {
  takesAO(x) // expected-error {{global function 'takesAO' requires that 'T' be a class type}}
  // expected-note@-3 {{where 'T' = 'T'}}
}

// Declarations.
class ClassAR: AnyReference {}
struct StructAR: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
enum EnumAR: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
extension AnyReference {} // expected-error {{non-nominal type 'AnyReference' cannot be extended}}
extension C: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}

final class ConformsToRefP: RefP {}
struct StructConformsToRefP: RefP {}
// expected-error@-1 {{type 'StructConformsToRefP' does not conform to protocol 'RefP'}}
// expected-error@-2 {{'RefP' requires that 'StructConformsToRefP' be a class or foreign reference type}}
// expected-note@-3 {{requirement specified as 'Self' : 'AnyReference' [with Self = StructConformsToRefP]}}

// Casts *to* an existential containing AnyReference cannot be checked at
// runtime.
func casts(_ x: Any, _ y: any AnyReference) {
  _ = x is any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as? any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as! any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as? any P & AnyReference // expected-error {{cannot dynamically cast to 'any P & AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as? (any AnyReference)? // expected-error {{cannot dynamically cast to '(any AnyReference)?'; 'AnyReference' constraints are not checked at runtime}}
  // Casts *from* `any AnyReference` are fine.
  _ = y as? C
  _ = y is D
  _ = y as! C
  _ = y as? any P
  _ = y as Any
}
