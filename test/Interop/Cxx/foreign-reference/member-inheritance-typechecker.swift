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
func callsOverridesOfRenamedVirtualMethods(_ a1: A1, _ b1: B1, _ c1: C1, _ d1: D1) {
  a1.virtualMethod()
  a1.virtualRename() // expected-error {{value of type 'A1' has no member 'virtualRename'}}
  a1.swiftVirtualRename()

  b1.virtualMethod()
  b1.swiftVirtualMethod() // expected-error {{value of type 'B1' has no member 'swiftVirtualMethod'}}
  b1.virtualRename() // expected-error {{value of type 'B1' has no member 'virtualRename'}}
  b1.swiftVirtualRename()
  b1.virtualRenameDifferently() // expected-error {{value of type 'B1' has no member 'virtualRenameDifferently'}}
  b1.swiftVirtualRenameDifferently() 
  b1.incorrectVirtualRenameDifferently() // expected-error {{value of type 'B1' has no member 'incorrectVirtualRenameDifferently'}}

  c1.virtualMethod()
  c1.swiftVirtualMethod() // expected-error {{value of type 'C1' has no member 'swiftVirtualMethod'}}
  c1.virtualRename() // expected-error {{value of type 'C1' has no member 'virtualRename'}}
  c1.swiftVirtualRename()
  c1.virtualRenameDifferently() // expected-error {{value of type 'C1' has no member 'virtualRenameDifferently'}}
  c1.swiftVirtualRenameDifferently() 
  c1.incorrectVirtualRenameDifferently() // expected-error {{value of type 'C1' has no member 'incorrectVirtualRenameDifferently'}}

  // TODO fix example with multiple inheritance
  // TODO diamond inheritance -> should be fine right?
  // c1.virtualMethod()
  // c1.virtualRename()
  // c1.swiftVirtualRename()
  // c1.virtualRenameDifferently()

  d1.virtualMethod()
  d1.swiftVirtualMethod() // TODO
  d1.virtualRename() // expected-error {{value of type 'D1' has no member 'virtualRename'}}
  // d1.swiftVirtualRename() // TODO ambiguous use
  d1.virtualRenameDifferently() // expected-error {{value of type 'D1' has no member 'virtualRenameDifferently'}}
  d1.swiftVirtualRenameDifferently()
  d1.incorrectVirtualRename()
}
