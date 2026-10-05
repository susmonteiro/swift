// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// Classes and foreign reference types are always Copyable and Escapable, so
// AnyReference can't be combined with inverses, mirroring AnyObject.
func ao<T: AnyObject>(_ x: T) where T: ~Escapable {}
// expected-error@-1 {{'T' required to be 'Escapable' but is marked with '~Escapable'}}

func esc<T: AnyReference>(_ x: T) where T: ~Escapable {}
// expected-error@-1 {{'T' required to be 'Escapable' but is marked with '~Escapable'}}

func copy<T: AnyReference>(_ x: borrowing T) where T: ~Copyable {}
// expected-error@-1 {{'T' required to be 'Copyable' but is marked with '~Copyable'}}

func comp(_ x: borrowing any AnyReference & ~Copyable) {}
// expected-error@-1 {{composition involving 'AnyReference' cannot contain '~Copyable'}}

protocol P {
  func f() where Self: AnyReference
  // expected-error@-1 {{instance method requirement 'f()' cannot add constraint 'Self: AnyReference' on 'Self'}}
}

func opaqueNever() -> some AnyReference { fatalError() }
// expected-note@-1 {{opaque return type declared here}}
// expected-error@-2 {{return type of global function 'opaqueNever()' requires that 'Never' be a class or foreign reference type}}

func opaqueInt() -> some AnyReference { 1 }
// expected-note@-1 {{opaque return type declared here}}
// expected-error@-2 {{return type of global function 'opaqueInt()' requires that 'Int' be a class or foreign reference type}}

// An optional existential is not opened; suggest unwrapping it. Other
// containers (e.g. arrays) don't get the note.
func takesAR<T: AnyReference>(_ x: T?) {} // expected-note {{where 'T' = 'any AnyReference'}}
func takesARArray<T: AnyReference>(_ xs: [T]) {} // expected-note {{where 'T' = 'any AnyReference'}}

func optionalExistential(_ x: (any AnyReference)?) {
  takesAR(x)
  // expected-error@-1 {{global function 'takesAR' requires that 'any AnyReference' be a class or foreign reference type}}
  // expected-note@-2 {{a value of type 'any AnyReference' is only opened into a reference when passed directly; unwrap the optional first}}
}

func arrayExistential(_ xs: [any AnyReference]) {
  takesARArray(xs)
  // expected-error@-1 {{global function 'takesARArray' requires that 'any AnyReference' be a class or foreign reference type}}
}
