// RUN: %target-typecheck-verify-swift -verify-additional-prefix no-feature-
// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

func foo<T: _AnyReference>(_: T) {}
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}}

typealias Alias = _AnyReference
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}} 

class C : _AnyReference {}
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}} 

class D<T> where T : _AnyReference {} 
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}} 

protocol P {}

func foo<T: _AnyReference & P>(_: T) {} 
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}} 

// expected-no-feature-error@+1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}}
@_specialize(where T: _AnyReference)
func specializedType<T>(_: T) {}

// Only references satisfy an '_AnyReference' requirement.
func takesReference<T: _AnyReference>(_: T) {}
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}}
// expected-note@-2 {{where 'T' = 'S'}}
// expected-note@-3 {{where 'T' = 'E'}}
// expected-note@-4 {{where 'T' = 'Int'}}
// expected-note@-5 {{where 'T' = '() -> Void'}}
// expected-note@-6 {{where 'T' = 'T'}}

struct S {}
enum E { case e }
func passToReference(c: C, s: S, e: E, i: Int, f: @escaping () -> Void) {
  takesReference(c)
  takesReference(s) // expected-error {{global function 'takesReference' requires that 'S' be a class type}}
  takesReference(e) // expected-error {{global function 'takesReference' requires that 'E' be a class type}}
  takesReference(i) // expected-error {{global function 'takesReference' requires that 'Int' be a class type}}
  takesReference(f) // expected-error {{global function 'takesReference' requires that '() -> Void' be a class type}}
}

func forwardReference<T: _AnyReference>(_ t: T) { takesReference(t) }
// expected-no-feature-error@-1 {{using '_AnyReference' requires an experimental feature; use '-enable-experimental-feature AnyReference'}}
func forwardClass<T: AnyObject>(_ t: T) { takesReference(t) }
func forwardUnconstrained<T>(_ t: T) { takesReference(t) } // expected-error {{global function 'takesReference' requires that 'T' be a class type}}

// The identity operators' overloads for '_AnyReference' don't change the
// diagnostics for values that aren't references.
func compare(s: S, os: S?, f: @escaping () -> Void) {
  _ = s === s // expected-error 2 {{argument type 'S' expected to be an instance of a class or class-constrained type}}
  _ = s === os
  // expected-error@-1 {{argument type 'S' expected to be an instance of a class or class-constrained type}}
  // expected-error@-2 {{argument type 'S?' expected to be an instance of a class or class-constrained type}}
  _ = s !== s // expected-error 2 {{argument type 'S' expected to be an instance of a class or class-constrained type}}
  _ = f === f // expected-error {{cannot check reference equality of functions; operands here have types '() -> Void' and '() -> Void'}}
  _ = s === nil // expected-error {{type 'S' is not optional, value can never be nil}}
  _ = ObjectIdentifier(s) // expected-error {{argument type 'S' expected to be an instance of a class or class-constrained type}}
}
