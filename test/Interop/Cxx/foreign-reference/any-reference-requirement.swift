// RUN: %target-typecheck-verify-swift -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -target %target-swift-5.8-abi-triple -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

import AnyReferenceFRTs

class SwiftClass {}
struct SwiftStruct {}

struct Box<T: AnyReference> {} // expected-note 3 {{requirement specified as 'T' : 'AnyReference'}}

// Swift classes and C++ foreign reference types satisfy 'AnyReference'.
let _: Box<SwiftClass>
let _: Box<RefCountedType>
let _: Box<DerivedRefCountedType>
let _: Box<ImmortalRefType>

// Value types don't.
let _: Box<SwiftStruct> // expected-error {{'Box' requires that 'SwiftStruct' be a class or foreign reference type}}
let _: Box<ValueType> // expected-error {{'Box' requires that 'ValueType' be a class or foreign reference type}}
let _: Box<Int> // expected-error {{'Box' requires that 'Int' be a class or foreign reference type}}

// An archetype constrained to AnyObject or AnyReference satisfies it.
func fromAnyObject<T: AnyObject>(_: T) { let _: Box<T> }
func fromAnyReference<T: AnyReference>(_: T) { let _: Box<T> }

// An AnyReference archetype doesn't satisfy AnyObject: it may be a foreign
// reference type.
struct ClassBox<T: AnyObject> {} // expected-note {{requirement specified as 'T' : 'AnyObject' [with T = T]}}
func toAnyObject<T: AnyReference>(_: T) { let _: ClassBox<T> } // expected-error {{'ClassBox' requires that 'T' be a class type}}

struct Generic<T> {}
extension Generic where T == ImmortalRefType, T: AnyReference {}
extension Generic where T == RefCountedType, T: AnyReference {}
extension Generic where T == SwiftClass, T: AnyReference {}
extension Generic where T == ValueType, T: AnyReference {} // expected-error {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == ValueType'}}
extension Generic where T == Int, T: AnyReference {} // expected-error {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == Int'}}


// The constraint solver checks the requirement at call sites.
func takes<T: AnyReference>(_: T) {} // expected-note 3 {{where 'T' = }}

func calls(c: SwiftClass, r: RefCountedType, d: DerivedRefCountedType,
           i: ImmortalRefType, s: SwiftStruct, v: ValueType) {
  takes(c)
  takes(r)
  takes(d)
  takes(i)
  takes(s) // expected-error {{global function 'takes' requires that 'SwiftStruct' be a class or a foreign reference type}}
  takes(v) // expected-error {{global function 'takes' requires that 'ValueType' be a class or a foreign reference type}}
  takes(1) // expected-error {{global function 'takes' requires that 'Int' be a class or a foreign reference type}}
}

func forwards<T: AnyObject, U: AnyReference>(_ t: T, _ u: U) {
  takes(t)
  takes(u)
}

// A composition with AnyReference is lowered to both requirements.
protocol P {}
extension SwiftClass: P {}
extension RefCountedType: P {}
extension ValueType: P {}

func takesP<T: P & AnyReference>(_: T) {} // expected-note {{where 'T' = 'ValueType'}}

func callsP(c: SwiftClass, r: RefCountedType, v: ValueType) {
  takesP(c)
  takesP(r)
  takesP(v) // expected-error {{global function 'takesP' requires that 'ValueType' be a class or a foreign reference type}}
}
