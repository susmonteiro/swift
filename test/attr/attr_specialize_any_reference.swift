// RUN: %target-typecheck-verify-swift -verify-additional-prefix noflag-
// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// AnyReference prespecializations are not supported, with or without the
// experimental feature (spelling 'AnyReference' in source is gated by the
// feature; @_specialize where-clauses are not).

@_specialize(exported: true, where T: AnyReference)
// expected-error@-1 {{'AnyReference' requirements are not supported by '_specialize' attribute}}
public func s<T>(_ x: T) {}

@_specialize(where T: AnyReference)
// expected-error@-1 {{'AnyReference' requirements are not supported by '_specialize' attribute}}
func s2<T>(_ x: T) {}

// Mixing AnyReference with the internal reference-counted layouts is a
// conflict (not a crash). Without the feature, spelling 'AnyReference' is
// also diagnosed.
protocol PR: AnyReference {} // expected-noflag-error {{'AnyReference' is experimental}}

@_specialize(where T: _RefCountedObject) // expected-error {{no type for 'T' can satisfy both}} expected-error {{too few generic parameters are specified in '_specialize' attribute (got 0, but expected 1)}} expected-note {{missing constraint for 'T' in '_specialize' attribute}}
func e<T: PR>(_ t: T) {}

@_specialize(where T: _RefCountedObject) // expected-error {{no type for 'T' can satisfy both}} expected-error {{too few generic parameters are specified in '_specialize' attribute (got 0, but expected 1)}} expected-note {{missing constraint for 'T' in '_specialize' attribute}}
func g<T>(_ t: T) where T: AnyReference {} // expected-noflag-error {{'AnyReference' is experimental}}

@_specialize(where T: _NativeRefCountedObject) // expected-error {{no type for 'T' can satisfy both}} expected-error {{too few generic parameters are specified in '_specialize' attribute (got 0, but expected 1)}} expected-note {{missing constraint for 'T' in '_specialize' attribute}}
func h<T>(_ t: T) where T: AnyReference {} // expected-noflag-error {{'AnyReference' is experimental}}

struct Box<T: AnyReference> { // expected-noflag-error {{'AnyReference' is experimental}}
  @_specialize(where T: _RefCountedObject) // expected-error {{no type for 'T' can satisfy both}} expected-error {{too few generic parameters are specified in '_specialize' attribute (got 0, but expected 1)}} expected-note {{missing constraint for 'T' in '_specialize' attribute}}
  func m(_ t: T) {}
}
