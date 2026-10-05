// RUN: %target-run-simple-swift(-enable-experimental-feature AnyReference)
// RUN: %target-run-simple-swift(-enable-experimental-feature AnyReference -O)
// REQUIRES: executable_test
// REQUIRES: swift_feature_AnyReference
// REQUIRES: concurrency

// Tests the standard library's AnyReference APIs (`ObjectIdentifier.init`,
// `===`, `!==`) with Swift classes. Every class conforms to AnyReference,
// and the results through generic AnyReference code must match the results
// of the AnyObject overloads. C++ foreign reference types are tested in
// test/Interop/Cxx/foreign-reference/.

import StdlibUnittest

class Base {
  var value: Int
  init(_ value: Int) { self.value = value }
}
final class Derived: Base {}
final class Unrelated {}
actor A {}

@inline(never)
func identifier<T: AnyReference>(_ x: T) -> ObjectIdentifier {
  return ObjectIdentifier(x)
}

@inline(never)
func identical<T: AnyReference>(_ a: T?, _ b: T?) -> Bool {
  return a === b
}

@inline(never)
func notIdentical<T: AnyReference>(_ a: T?, _ b: T?) -> Bool {
  return a !== b
}

@inline(never)
func identicalMixed<T: AnyReference, U: AnyReference>(_ a: T?, _ b: U?)
    -> Bool {
  return a === b
}

@inline(never)
func notIdenticalMixed<T: AnyReference, U: AnyReference>(_ a: T?, _ b: U?)
    -> Bool {
  return a !== b
}

@inline(never)
func compareToNil<T: AnyReference>(_ a: T) -> (Bool, Bool, Bool, Bool) {
  let o: T? = a
  return (o === nil, nil === o, o !== nil, nil !== o)
}

let suite = TestSuite("AnyReference")

suite.test("ObjectIdentifier matches AnyObject") {
  let x = Base(1)
  let y = x
  let z = Base(1)
  expectEqual(identifier(x), ObjectIdentifier(x))
  expectEqual(identifier(x), ObjectIdentifier(x as AnyObject))
  expectEqual(identifier(x), identifier(y))
  expectNotEqual(identifier(x), identifier(z))
  let a = A()
  expectEqual(identifier(a), ObjectIdentifier(a))

  let d = Derived(2)
  expectEqual(identifier(d), identifier(d as Base))
  expectEqual(identifier(d), ObjectIdentifier(d))
}

suite.test("Bit pattern matches AnyObject") {
  let x = Base(1)
  expectEqual(UInt(bitPattern: identifier(x)),
              UInt(bitPattern: ObjectIdentifier(x)))
  expectEqual(Int(bitPattern: identifier(x)),
              Int(bitPattern: ObjectIdentifier(x)))
}

suite.test("Same-type === and !==") {
  let x = Base(1)
  let y = x
  let z = Base(1)
  expectTrue(identical(x, y))
  expectFalse(identical(x, z))
  expectEqual(identical(x, y), x === y)
  expectEqual(identical(x, z), x === z)
  expectFalse(notIdentical(x, y))
  expectTrue(notIdentical(x, z))
  expectEqual(notIdentical(x, z), x !== z)

  expectTrue(identical(nil as Base?, nil))
  expectFalse(identical(x, nil))
  expectFalse(identical(nil, x))
  expectTrue(notIdentical(x, nil))
  expectFalse(notIdentical(nil as Base?, nil))

  let d = Derived(2)
  expectTrue(identical(d as Base, d))
  expectFalse(identical(d as Base, x))
}

suite.test("Comparing to nil") {
  let (a, b, c, d) = compareToNil(Base(1))
  expectFalse(a)
  expectFalse(b)
  expectTrue(c)
  expectTrue(d)
}

suite.test("Two-parameter === and !==") {
  let x = Base(1)
  let d = Derived(2)
  let u = Unrelated()
  expectFalse(identicalMixed(x, u))
  expectTrue(notIdenticalMixed(x, u))
  expectEqual(identicalMixed(x, u), x === u)
  expectTrue(identicalMixed(d, d as Base))
  expectFalse(notIdenticalMixed(d, d as Base))
  expectTrue(identicalMixed(nil as Base?, nil as Unrelated?))
  expectFalse(identicalMixed(x, nil as Unrelated?))
}

suite.test("AnyObject existential satisfies AnyReference") {
  let x = Base(1)
  let ex: AnyObject = x
  expectEqual(identifier(ex), ObjectIdentifier(x))
  expectTrue(identical(ex, x as AnyObject))
}

suite.test("Opened any AnyReference existentials") {
  let x = Base(1)
  let d = Derived(2)
  let e: any AnyReference = x
  let e2: any AnyReference = x
  let ed: any AnyReference = d
  let eo: any AnyReference = x as AnyObject

  // ObjectIdentifier(_:) opens the existential and identifies the
  // underlying instance.
  expectEqual(ObjectIdentifier(e), ObjectIdentifier(x))
  expectEqual(ObjectIdentifier(ed), ObjectIdentifier(d))
  expectEqual(ObjectIdentifier(eo), ObjectIdentifier(x))
  expectEqual(identifier(e), ObjectIdentifier(x))

  // Two separately opened existentials use the two-parameter overloads.
  expectTrue(e === e2)
  expectFalse(e === ed)
  expectTrue(e !== ed)
  expectFalse(e !== e2)

  let all: [any AnyReference] = [x, d, Unrelated()]
  let ids = Set(all.map { ObjectIdentifier($0) })
  expectEqual(ids.count, 3)
  expectTrue(ids.contains(ObjectIdentifier(x)))
  expectTrue(ids.contains(ObjectIdentifier(d)))
}

suite.test("Hashable and Set<ObjectIdentifier>") {
  let objects = (0..<10).map { Base($0) }
  var ids = Set<ObjectIdentifier>()
  for o in objects {
    ids.insert(identifier(o))
  }
  expectEqual(ids.count, objects.count)
  for o in objects {
    expectTrue(ids.contains(ObjectIdentifier(o)))
    expectFalse(ids.insert(identifier(o)).inserted)
  }
  expectEqual(identifier(objects[0]).hashValue,
              ObjectIdentifier(objects[0]).hashValue)
}

suite.test("Metatypes are unaffected") {
  expectEqual(ObjectIdentifier(Base.self), ObjectIdentifier(Base.self))
  expectEqual(ObjectIdentifier(Base.self),
              ObjectIdentifier(Base.self as Any.Type))
  expectNotEqual(ObjectIdentifier(Base.self), ObjectIdentifier(Derived.self))
  expectEqual(ObjectIdentifier(Int.self), ObjectIdentifier(Int.self))
}

suite.test("No retain leak") {
  let x = Base(1)
  weak var w = x
  do {
    let local = Base(2)
    w = local
    _ = identifier(local)
    _ = identical(local, local)
    _ = identicalMixed(local, x)
  }
  expectNil(w)
  _ = x
}

runAllTests()
