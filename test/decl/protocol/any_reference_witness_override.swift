// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// A witness or override must not require more than the requirement or the
// overridden declaration: 'T: AnyObject' is stronger than 'T: AnyReference'.

protocol R {
  func f<T: AnyReference>(_ x: T) // expected-note {{protocol requires function 'f' with type '<T> (T) -> ()'}}
}

protocol R2 {
  func g<T: AnyObject>(_ x: T)
}

struct W1: R { func f<T: AnyReference>(_ x: T) {} }

struct W2: R { // expected-error {{type 'W2' does not conform to protocol 'R'}}
  // expected-note@-1 {{add stubs for conformance}}
  func f<T: AnyObject>(_ x: T) {} // expected-note {{candidate has non-matching type}}
}

// The weaker requirement is fine.
struct W3: R2 { func g<T: AnyReference>(_ x: T) {} }

class B {
  func h<T: AnyReference>(_ x: T) {}
  func k<T: AnyObject>(_ x: T) {}
}

class D1: B {
  override func h<T: AnyObject>(_ x: T) {}
  // expected-error@-1 {{method does not override any method from its superclass}}
}

class D2: B {
  override func k<T: AnyReference>(_ x: T) {}
}
