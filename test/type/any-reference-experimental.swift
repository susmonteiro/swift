// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-swift-frontend -typecheck -verify %t/Gated.swift
// RUN: %target-swift-frontend -typecheck -verify %t/Shadowed.swift
// RUN: %target-swift-frontend -typecheck -verify -parse-stdlib %t/UsesBuiltin.swift

// Spelling 'AnyReference' requires '-enable-experimental-feature AnyReference'.

//--- Gated.swift
protocol P {}

func parameter(_: AnyReference) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func existential(_: any AnyReference) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func qualified(_: any Swift.AnyReference) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func composition(_: any P & AnyReference) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func optional(_: (any AnyReference)?) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
// FIXME: This is diagnosed twice.
func opaque(_: some AnyReference) {} // expected-error 2 {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func generic<T: AnyReference>(_: T) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func whereClause<T>(_: T) where T: AnyReference {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}

protocol Inherits: AnyReference {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
protocol AssociatedType {
  associatedtype A: AnyReference // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
}
typealias Alias = AnyReference // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}

func expression() {
  let _ = AnyReference.self // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
}

// The layout constraint spelling is gated too.
@_specialize(where T: _AnyReference) // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func specialized<T>(_: T) {}

// 'AnyObject' is unaffected.
func anyObject(_: AnyObject) {}
func anyObjectGeneric<T: AnyObject>(_: T) {}

//--- Shadowed.swift
// A declaration named 'AnyReference' outside the standard library is not
// diagnosed.
struct AnyReference {}

func parameter(_: AnyReference) {}
let _ = AnyReference()

//--- UsesBuiltin.swift
// The standard library defines 'AnyReference' in terms of the Builtin type and
// is built without the experimental feature.
typealias AnyReference = Builtin.AnyReference

func builtin(_: Builtin.AnyReference) {}
