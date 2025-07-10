// RUN: %target-typecheck-verify-swift -verify-ignore-unknown -I %S/Inputs -cxx-interoperability-mode=upcoming-swift
// RUN: %target-typecheck-verify-swift -verify-ignore-unknown -I %S/Inputs -cxx-interoperability-mode=swift-5.9
// RUN: %target-typecheck-verify-swift -verify-ignore-unknown -I %S/Inputs -cxx-interoperability-mode=swift-6

import MemberInheritance

@available(SwiftStdlib 5.8, *)
func takesImmortalBase(_ i: ImmortalBase) {
  let _ = i.get42()
  let _ = i.getOverridden42()
  let _ = i.getIntValue()
}

@available(SwiftStdlib 5.8, *)
func takesImmortal(_ i: Immortal) {
  let _ = i.get42()
  let _ = i.getOverridden42()
  let _ = i.getIntValue()
  i.setIntValue(1)
}

@available(SwiftStdlib 5.8, *)
func takesDerivedFromImmortal(_ i: DerivedFromImmortal) {
  let _ = i.get42()
  let _ = i.getOverridden42()
  let _ = i.getIntValue()
  i.setIntValue(1)
}

@available(SwiftStdlib 5.8, *)
func callsRenamedVirtualMethodsInFRT(_ i: Immortal2) {
  i.virtualRename()  // expected-error {{value of type 'Immortal2' has no member 'virtualRename'}}
  i.swiftVirtualRename()
}

@available(SwiftStdlib 5.8, *)
func callsOverridesOfRenamedVirtualMethods(_ a1: A1, _ a2: A2, _ b1: B1, _ c1: C1, _ c2: C2, _ d1: D1, _ d2: D2) {
  a1.virtualMethod()
  a1.fooRename() // expected-error {{value of type 'A1' has no member 'fooRename'}}
  a1.swiftFooRename()
  a1.swiftParamsRename(a1: 42)

  b1.swiftVirtualMethod() // expected-error {{value of type 'B1' has no member 'swiftVirtualMethod'}}
  b1.fooRename() // expected-error {{value of type 'B1' has no member 'fooRename'}}
  b1.swiftFooRename()
  b1.barRename() // expected-error {{value of type 'B1' has no member 'barRename'}}
  b1.swiftBarRename()

  b1.virtualMethod()
  b1.swiftVirtualMethod() // expected-error {{'swiftVirtualMethod()' is unavailable: ignoring swift_name 'swiftVirtualMethod()' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  b1.fooRename() // expected-error {{value of type 'B1' has no member 'fooRename'}}
  b1.swiftFooRename()
  b1.barRename() // expected-error {{value of type 'B1' has no member 'barRename'}}
  b1.swiftBarRename()
  b1.B1BarRename() // expected-error {{'B1BarRename()' is unavailable: ignoring swift_name 'B1BarRename()' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  b1.swiftParamsRename(a1: 42)
  b1.swiftParamsRename(b1: 42) // expected-error {{'swiftParamsRename(b1:)' is unavailable: ignoring swift_name 'swiftParamsRename(b1:)' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  
  // c1.virtualMethod() --> TODO
  c1.swiftVirtualMethod() // expected-error {{'swiftVirtualMethod()' is unavailable: ignoring swift_name 'swiftVirtualMethod()' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  c1.fooRename() // expected-error {{value of type 'C1' has no member 'fooRename'}}
  c1.swiftFooRename()
  c1.barRename() // expected-error {{value of type 'C1' has no member 'barRename'}}
  c1.swiftBarRename() 
  c1.B1BarRename() // expected-error {{'B1BarRename()' is unavailable: ignoring swift_name 'B1BarRename()' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  c1.paramsRename(42) // expected-error {{value of type 'C1' has no member 'paramsRename'}}
  c1.swiftParamsRename(42) // expected-error {{missing argument label 'a1:' in call}}
  c1.swiftParamsRename(a1: 42)
  
  // c2.virtualMethod() --> TODO
  c2.swiftVirtualMethod() // expected-error {{'swiftVirtualMethod()' is unavailable: ignoring swift_name 'swiftVirtualMethod()' in 'B1'; swift_name attributes have no effect in virtual methods overrides}}
  c2.fooRename() // expected-error {{value of type 'C2' has no member 'fooRename'}}
  c2.swiftFooRename()
  c2.C2FooRename() // expected-error {{'C2FooRename()' is unavailable: ignoring swift_name 'C2FooRename()' in 'C2'; swift_name attributes have no effect in virtual methods overrides}}
  c2.barRename() // expected-error {{value of type 'C2' has no member 'barRename'}}
  c2.swiftBarRename() 
  c2.B1BarRename() // expected-error {{value of type 'C2' has no member 'B1BarRename'}}
  c2.paramsRename(42) // expected-error {{value of type 'C2' has no member 'paramsRename'}}
  c2.swiftParamsRename(a1: 42) 
  c2.swiftParamsRename(b1: 42) // expected-error {{incorrect argument label in call (have 'b1:', expected 'a1:'}}

  // TODO expected warning?
  // TODO params

  d1.virtualMethod() // TODO
  d1.swiftVirtualMethod() // TODO
  d1.fooRename() // expected-error {{value of type 'D1' has no member 'fooRename'}}
  d1.swiftFooRename() // expected-error {{ambiguous use of 'swiftFooRename()'}}
  d1.barRename() // expected-error {{value of type 'D1' has no member 'barRename'}}
  d1.swiftBarRename() // TODO
  d1.A2BarRename() // TODO
  d1.swiftParamsRename(a1: 42) // TODO
  d1.swiftParamsRename(a2: 42) // TODO

  d2.virtualMethod() // TODO
  d2.swiftVirtualMethod() // TODO
  d2.fooRename() // expected-error {{value of type 'D2' has no member 'fooRename'}}
  d2.swiftFooRename() // expected-error {{ambiguous use of 'swiftFooRename()'}}
  d2.barRename() // expected-error {{value of type 'D2' has no member 'barRename'}}
  d2.swiftBarRename() // TODO
  d2.A2BarRename() // TODO
  d2.swiftParamsRename(a1: 42)
  d2.swiftParamsRename(a2: 42)
  d2.swiftParamsRename(b1: 42) // expected-error {{no exact matches in call to instance method 'swiftParamsRename'}}
}


