// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// `AnyReference` as a type: like `AnyObject`, it is an empty
// protocol composition with a layout constraint, but it is satisfied by every reference type (Swift
// classes and C++ foreign reference types), and `any AnyReference` is an
// opaque existential.

class C {}
final class D : C {}
struct S {}
enum E { case a }
protocol P {}
protocol ClassP : AnyObject {}
protocol RefP : AnyReference {}

func bare(_: AnyReference) {}
func explicitAny(_: any AnyReference) {}
func explicitSome(_: some AnyReference) {}
func optional(_: (any AnyReference)?) {}
func metatype(_: (any AnyReference).Type) {}
func composition(_: any P & AnyReference) {}
func compositionWithAnyObject(_: any AnyReference & AnyObject) {}
func generic<T: AnyReference>(_: T) {}
func genericWhere<T>(_: T) where T: AnyReference {}

class ClassAnyReference: AnyReference {}
struct StructAnyReference: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
enum EnumAnyReference: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
extension AnyReference {} // expected-error {{non-nominal type 'AnyReference' cannot be extended}}
extension C: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}

// Inheritance clauses that only mention `AnyReference` through a composition
// or a typealias are diagnosed the same way.
typealias PAndAnyReference = P & AnyReference
struct StructPAndAnyReference: P & AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
struct StructAliasAnyReference: PAndAnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
actor ActorAnyReference: AnyReference {}
class SubclassAnyReference: C, AnyReference {}
class ClassPAndAnyReference: P & AnyReference {}

// `AnyObject` is still diagnosed with its own name.
struct StructAnyObject: AnyObject {} // expected-error {{only protocols can inherit from 'AnyObject'}}

// The layout constraint can be spelled in '@_specialize'.
@_specialize(where T: _AnyReference)
func specialized<T>(_: T) {}

// Canonicalization: AnyObject, a superclass, or a class-constrained protocol
// make AnyReference redundant, so these are the same type.
func redundantWithAnyObject(_: any AnyObject & AnyReference) {} // expected-note {{'redundantWithAnyObject' previously declared here}}
func redundantWithAnyObject(_: AnyObject) {} // expected-error {{invalid redeclaration of 'redundantWithAnyObject'}}

func redundantWithSuperclass(_: C & AnyReference) {} // expected-note {{'redundantWithSuperclass' previously declared here}}
func redundantWithSuperclass(_: C) {} // expected-error {{invalid redeclaration of 'redundantWithSuperclass'}}

func redundantWithClassProtocol(_: any ClassP & AnyReference) {} // expected-note {{'redundantWithClassProtocol' previously declared here}}
func redundantWithClassProtocol(_: any ClassP) {} // expected-error {{invalid redeclaration of 'redundantWithClassProtocol'}}

func duplicated(_: any AnyReference & AnyReference) {} // expected-note {{'duplicated' previously declared here}}
func duplicated(_: any AnyReference) {} // expected-error {{invalid redeclaration of 'duplicated'}}

func reordered(_: any P & AnyReference) {} // expected-note {{'reordered' previously declared here}}
func reordered(_: any AnyReference & P) {} // expected-error {{invalid redeclaration of 'reordered'}}

func throughTypealias(_: any PAndAnyReference) {} // expected-note {{'throughTypealias' previously declared here}}
func throughTypealias(_: any P & AnyReference) {} // expected-error {{invalid redeclaration of 'throughTypealias'}}

// Witness matching compares the AnyReference bit.
protocol Requirement {
  func take(_: any P & AnyReference)
}
struct Witness: Requirement {
  func take(_: any P & AnyReference) {}
}

// Override matching compares the AnyReference bit.
class Base {
  func take(_: any P & AnyReference) {} // expected-note {{potential overridden instance method 'take' here}}
}
class Override: Base {
  override func take(_: any P & AnyReference) {}
}
class DroppedAnyReference: Base {
  override func take(_: any P) {} // expected-error {{method does not override any method from its superclass}}
}

// The standard library typealias isn't printed with an 'aka'.
func printing(anyReference: any AnyReference, anyObject: AnyObject,
              composition: any P & AnyReference) {
  let _: Int = anyReference // expected-error {{cannot convert value of type 'any AnyReference' to specified type 'Int'}}
  let _: Int = anyObject // expected-error {{cannot convert value of type 'AnyObject' to specified type 'Int'}}
  let _: Int = composition // expected-error {{cannot convert value of type 'any P & AnyReference' to specified type 'Int'}}
}
