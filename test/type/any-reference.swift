// RUN: %target-typecheck-verify-swift

@_specialize(where T: _AnyReference) 
// expected-error@-1 {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}} 
// expected-error@-2 {{empty 'where' clause in '_specialize' attribute}}
func f<T>(_ t: T) {}
