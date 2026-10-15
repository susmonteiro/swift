// RUN: %target-typecheck-verify-swift -verify-additional-prefix no-feature-
// RUN: %target-swift-frontend -typecheck -enable-experimental-feature AnyReference %s

// REQUIRES: swift_feature_AnyReference

@_specialize(where T: _AnyReference) 
// expected-no-feature-error@-1 {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}} 
// expected-no-feature-error@-2 {{empty 'where' clause in '_specialize' attribute}}
func f<T>(_ t: T) {}

func spelled<T: AnyReference>(_: T) {} // expected-no-feature-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
typealias Alias = AnyReference // expected-no-feature-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
