// RUN: %target-typecheck-verify-swift -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -verify-additional-prefix missing-flag-
// RUN: %target-typecheck-verify-swift -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

import AnyReferenceFRT

class SwiftClass {}

func spelled<T: AnyReference>(_: T) {} // expected-missing-flag-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func spelledExistential(_: any AnyReference) {} // expected-missing-flag-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
