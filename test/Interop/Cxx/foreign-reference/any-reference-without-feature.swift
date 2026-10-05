// RUN: %target-typecheck-verify-swift -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -target %target-swift-5.8-abi-triple

// Without `-enable-experimental-feature AnyReference`, `AnyReference` cannot
// be spelled in user code. The stdlib APIs built on top of it, however, can be
// used with C++ foreign reference types without the feature.

import AnyReferenceFRTs

class SwiftClass {}

func spelled<T: AnyReference>(_: T) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}
func spelledExistential(_: any AnyReference) {} // expected-error {{'AnyReference' is experimental; enable it with '-enable-experimental-feature AnyReference'}}

func identityWithoutFeature(_ a: RefCountedType, _ b: RefCountedType,
                            _ d: DerivedRefCountedType,
                            _ mi: MultipleInheritanceRefCounted,
                            _ c: SwiftClass) {
  let imm = getImmortal()

  _ = ObjectIdentifier(a)
  _ = ObjectIdentifier(d)
  _ = ObjectIdentifier(imm)
  _ = ObjectIdentifier(getUnsafeRef())
  _ = ObjectIdentifier(getTemplatedRef())
  _ = ObjectIdentifier(a) == ObjectIdentifier(b)

  _ = a === b
  _ = a !== b
  _ = a === a.getSelf()
  _ = imm === getOtherImmortal()
  _ = maybeImmortal(true) === imm
  _ = maybeRefCounted(false) !== nil

  // Derived and base: the same-type overload (via upcast) or the two-parameter
  // overload apply.
  _ = d === d.asBase()
  // Unrelated types use the two-parameter overload.
  _ = a === imm
  _ = mi === mi.asNonPrimaryBase()
  _ = a === c

  // Swift classes are unaffected.
  _ = ObjectIdentifier(c)
  _ = c === c
  _ = c !== SwiftClass()
}

// Value types are still rejected.
func valueTypesStillRejected(_ v: ValueType) {
  _ = ObjectIdentifier(v) // expected-error {{argument type 'ValueType' expected to be an instance of a class or class-constrained type}}
  _ = v === v // expected-error 2 {{argument type 'ValueType' expected to be an instance of a class or class-constrained type}}
}
