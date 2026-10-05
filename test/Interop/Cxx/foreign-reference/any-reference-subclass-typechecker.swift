// RUN: %target-typecheck-verify-swift -cxx-interoperability-mode=default -enable-experimental-feature ForeignReferenceTypeSubclassing -enable-experimental-feature AnyReference -I %S%{fs-sep}Inputs -target %target-swift-5.8-abi-triple

// REQUIRES: swift_feature_ForeignReferenceTypeSubclassing
// REQUIRES: swift_feature_AnyReference

// A Swift subclass of a C++ foreign reference type satisfies AnyReference.
//
// NOTE: It currently also satisfies AnyObject, because it has no Clang node
// and therefore is not itself considered a foreign reference type. Whether it
// should be AnyObject is a separate follow-up; this test only pins that it is
// an AnyReference either way.

import InheritFRTSubclassing

final class SwiftSub: SubclassableShared {}
final class SwiftSubOfDerived: DerivedSubclassableShared {}

func takesAR<T: AnyReference>(_: T) {}
func takesExistentialAR(_: any AnyReference) {}

func test(_ sub: SwiftSub, _ subOfDerived: SwiftSubOfDerived,
          _ base: SubclassableShared) {
  takesAR(sub)
  takesAR(subOfDerived)
  takesAR(base)
  takesExistentialAR(sub)
  takesExistentialAR(base)

  _ = ObjectIdentifier(sub)
  _ = ObjectIdentifier(base)
  _ = sub === sub
  _ = sub === base
  _ = subOfDerived !== base
}
