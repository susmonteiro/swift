// RUN: %target-run-simple-swift(-I %S/Inputs -cxx-interoperability-mode=default -Xfrontend -disable-availability-checking -enable-experimental-feature AnyReference)
// REQUIRES: executable_test

import AnyReferenceFRTs
import StdlibUnittest

var AnyReferenceTests = TestSuite("AnyReference")

func identity<T: AnyReference>(_ t: T) -> T {
  return t
}

AnyReferenceTests.test("Call identity") {
  let rft = identity(RefCountedType(5))
  expectEqual(rft.getValue(), 5)
  // let v = identity(ValueType(5))
  // expectEqual(v.value, 5)
}

AnyReferenceTests.test("ObjectIdentity") {
  let o1 = RefCountedType(5)
  let o2 = RefCountedType(5)
  expectTrue(ObjectIdentifier(o1) == ObjectIdentifier(o1))
  expectFalse(ObjectIdentifier(o1) == ObjectIdentifier(o2))
  let o3 = o1
  expectTrue(ObjectIdentifier(o1) == ObjectIdentifier(o3))

  expectTrue(o1 === o3)
  expectTrue(o1 === o1)
  expectFalse(o1 === o2)

  expectFalse(o1 !== o3)
  expectFalse(o1 !== o1)
  expectTrue(o1 !== o2)
}

struct Box<T: AnyReference> {
  let value: T
}

AnyReferenceTests.test("Box") {
  let o1 = RefCountedType(5)
  let box = Box(value: o1)
  let _ = identity(box.value)
}

runAllTests()
