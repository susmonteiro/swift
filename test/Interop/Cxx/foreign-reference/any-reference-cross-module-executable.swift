// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-build-swift-dylib(%t/%target-library-name(ARLib)) %t/ARLib.swift -module-name ARLib -emit-module -emit-module-path %t/ARLib.swiftmodule -enable-library-evolution -enable-experimental-feature AnyReference
// RUN: %target-codesign %t/%target-library-name(ARLib)
// RUN: %target-build-swift %t/main.swift -I %t -L %t -lARLib -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple %target-rpath(%t) -o %t/main
// RUN: %target-codesign %t/main
// RUN: %target-run %t/main %t/%target-library-name(ARLib)

// REQUIRES: executable_test
// REQUIRES: swift_feature_AnyReference

// C++ foreign reference types passed across a resilient module boundary
// through `T: AnyReference` generics, `any AnyReference` existentials, a
// generic struct and a protocol refining AnyReference. The library knows
// nothing about C++.

//--- ARLib.swift
public func libIdentifier<T: AnyReference>(_ x: T) -> ObjectIdentifier {
  ObjectIdentifier(x)
}

@inlinable
public func libIdenticalInlinable<T: AnyReference, U: AnyReference>(
  _ x: T, _ y: U
) -> Bool {
  x === y
}

public func libIdentical(_ x: any AnyReference, _ y: any AnyReference) -> Bool {
  x === y
}

public func libStore<T: AnyReference>(_ x: T) -> [any AnyReference] {
  [x, x]
}

public struct Box<T: AnyReference> {
  public var x: T
  public init(_ x: T) { self.x = x }
  public func identifier() -> ObjectIdentifier { ObjectIdentifier(x) }
}

public protocol RP: AnyReference {}

public func libRP(_ p: any RP) -> ObjectIdentifier {
  ObjectIdentifier(p)
}

//--- main.swift
import AnyReferenceFRTs
import ARLib
import StdlibUnittest

extension RefCountedType: RP {}

class SwiftClass {}

var CrossModuleTestSuite = TestSuite("AnyReferenceCrossModule")

CrossModuleTestSuite.test("identity across a resilient module") {
  let liveBefore = getLiveObjects()
  do {
    let a = RefCountedType(1)
    let b = RefCountedType(2)
    let c = SwiftClass()

    expectEqual(ObjectIdentifier(a), libIdentifier(a))
    expectEqual(ObjectIdentifier(c), libIdentifier(c))
    expectEqual(ObjectIdentifier(getImmortal()), libIdentifier(getImmortal()))

    expectTrue(libIdenticalInlinable(a, a.getSelf()))
    expectFalse(libIdenticalInlinable(a, b))
    expectFalse(libIdenticalInlinable(a, c))

    expectTrue(libIdentical(a, a.getSelf()))
    expectFalse(libIdentical(a, b))
    expectTrue(libIdentical(c, c))

    let stored = libStore(a)
    expectEqual(2, stored.count)
    expectTrue(libIdentical(stored[0], stored[1]))
    expectEqual(ObjectIdentifier(stored[0]), ObjectIdentifier(a))

    let box = Box(a)
    let boxCopy = box
    expectEqual(ObjectIdentifier(a), box.identifier())
    expectTrue(boxCopy.x === a)

    expectEqual(ObjectIdentifier(a), libRP(a))
  }
  expectEqual(liveBefore, getLiveObjects(), "objects were leaked or over-released")
}

runAllTests()
