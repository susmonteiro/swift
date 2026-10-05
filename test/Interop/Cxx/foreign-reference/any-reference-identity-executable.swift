// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple -Onone)
// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple -O -D OPTIMIZED)
// RUN: %target-run-simple-swift(-I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple -Osize -D OPTIMIZED)

// REQUIRES: executable_test
// REQUIRES: swift_feature_AnyReference

// Identity (`ObjectIdentifier`, `===`, `!==`) of C++ foreign reference types,
// directly, through generics constrained to `AnyReference`, and through
// `any AnyReference` existentials. Every test also checks that no object is
// leaked or over-released.
//
// No `use_os_stdlib` / back-deployment exclusions are needed: the stdlib APIs
// used here (`ObjectIdentifier.init<T: AnyReference>`, `===`, `!==`) are
// `@export(implementation)`, so they are emitted into this client and do not
// require new symbols from the runtime's stdlib; AnyReference itself is erased
// at runtime.

import AnyReferenceFRTs
import StdlibUnittest

class SwiftClass {}

@inline(never)
func identifier<T: AnyReference>(_ x: T) -> ObjectIdentifier {
  ObjectIdentifier(x)
}

@inline(never)
func identical<T: AnyReference, U: AnyReference>(_ x: T, _ y: U) -> Bool {
  x === y
}

@inline(never)
func notIdentical<T: AnyReference>(_ x: T, _ y: T) -> Bool {
  x !== y
}

@inline(never)
func existentialIdentifier(_ x: any AnyReference) -> ObjectIdentifier {
  ObjectIdentifier(x)
}

@inline(never)
func existentialsIdentical(_ x: any AnyReference, _ y: any AnyReference) -> Bool {
  x === y
}

@inline(never)
func uniqueCount<T: AnyReference>(_ xs: [T]) -> Int {
  Set(xs.map { ObjectIdentifier($0) }).count
}

@inline(never)
func copies<T: AnyReference>(_ x: T) -> [T] {
  [x, x, x]
}

/// Runs `body` and checks that it does not leak or over-release objects.
func expectBalanced(_ body: () -> Void,
                    file: String = #file, line: UInt = #line) {
  let liveBefore = getLiveObjects()
  body()
  expectEqual(liveBefore, getLiveObjects(),
              "objects were leaked or over-released",
              file: file, line: line)
}

var AnyReferenceIdentityTestSuite = TestSuite("AnyReferenceIdentity")

AnyReferenceIdentityTestSuite.test("same object") {
  expectBalanced {
    let a = RefCountedType(1)
    let same = a.getSelf()
    expectTrue(a === same)
    expectFalse(a !== same)
    expectEqual(ObjectIdentifier(a), ObjectIdentifier(same))
    expectEqual(identifier(a), identifier(same))
    expectTrue(identical(a, same))
    expectFalse(notIdentical(a, same))
    expectEqual(existentialIdentifier(a), ObjectIdentifier(a))
    expectTrue(existentialsIdentical(a, same))
  }
}

AnyReferenceIdentityTestSuite.test("different objects") {
  expectBalanced {
    let a = RefCountedType(1)
    let b = RefCountedType(1)
    expectFalse(a === b)
    expectTrue(a !== b)
    expectNotEqual(ObjectIdentifier(a), ObjectIdentifier(b))
    expectNotEqual(identifier(a), identifier(b))
    expectFalse(identical(a, b))
    expectTrue(notIdentical(a, b))
    expectNotEqual(existentialIdentifier(a), existentialIdentifier(b))
    expectFalse(existentialsIdentical(a, b))
    expectEqual(1, a.getRefCount())
    expectEqual(1, b.getRefCount())
  }
}

AnyReferenceIdentityTestSuite.test("ObjectIdentifier matches the C++ address") {
  expectBalanced {
    let a = RefCountedType(1)
    expectEqual(UInt(bitPattern: ObjectIdentifier(a)),
                UInt(bitPattern: addressOf(a)))
    let d = DerivedRefCountedType(1, 2)
    expectEqual(UInt(bitPattern: ObjectIdentifier(d)),
                UInt(bitPattern: addressOf(d)))
    let mi = MultipleInheritanceRefCounted()
    expectEqual(UInt(bitPattern: ObjectIdentifier(mi.asNonPrimaryBase())),
                UInt(bitPattern: addressOf(mi.asNonPrimaryBase())))
  }
}

AnyReferenceIdentityTestSuite.test("immortal") {
  let imm = getImmortal()
  expectTrue(imm === getImmortal())
  expectTrue(imm === getConstImmortal())
  expectFalse(imm === getOtherImmortal())
  expectEqual(ObjectIdentifier(imm), ObjectIdentifier(getImmortal()))
  expectNotEqual(ObjectIdentifier(imm), ObjectIdentifier(getOtherImmortal()))
  expectEqual(identifier(imm), existentialIdentifier(getImmortal()))
  expectTrue(identical(getUnsafeRef(), getUnsafeRef()))
  expectTrue(identical(getTemplatedRef(), getTemplatedRef()))
  expectTrue(getImmortalSharedSpelling() === getImmortalSharedSpelling())
}

AnyReferenceIdentityTestSuite.test("derived to base") {
  expectBalanced {
    let d = DerivedRefCountedType(1, 2)
    let base: RefCountedType = d
    expectTrue(d === base)
    expectTrue(d === d.asBase())
    expectEqual(ObjectIdentifier(d), ObjectIdentifier(base))
    expectEqual(ObjectIdentifier(d), ObjectIdentifier(d.asBase()))
    expectEqual(identifier(d), identifier(base))
    expectTrue(identical(d, d.asBase()))
    expectTrue(existentialsIdentical(d, base))
    expectFalse(d === RefCountedType(1))
  }
}

// C++ multiple inheritance: the RefCountedType subobject is not at offset zero.
// Identity compares addresses, so the derived object and its non-primary base
// subobject are NOT identical (unlike pointer comparison in C++, which adjusts
// the pointer first).
AnyReferenceIdentityTestSuite.test("multiple inheritance (non-primary base)") {
  expectBalanced {
    let mi = MultipleInheritanceRefCounted()
    let base = mi.asNonPrimaryBase()
    expectTrue(mi === mi)
    expectTrue(base === base.getSelf())
    expectFalse(mi === base)
    expectTrue(mi !== base)
    expectNotEqual(ObjectIdentifier(mi), ObjectIdentifier(base))
    expectFalse(identical(mi, base))
    expectFalse(existentialsIdentical(mi, base))
  }
}

AnyReferenceIdentityTestSuite.test("nil and Optional") {
  expectBalanced {
    let none = maybeRefCounted(false)
    let some = maybeRefCounted(true)
    expectTrue(none === nil)
    expectFalse(none !== nil)
    expectFalse(some === nil)
    expectTrue(some !== nil)
    expectFalse(some === none)
    expectTrue(some === some!.getSelf())
    expectTrue(maybeImmortal(true) === getImmortal())
    expectTrue(maybeImmortal(false) === nil)
  }
}

AnyReferenceIdentityTestSuite.test("FRT versus Swift class") {
  expectBalanced {
    let a = RefCountedType(1)
    let c = SwiftClass()
    expectFalse(a === c)
    expectTrue(a !== c)
    expectFalse(identical(a, c))
    expectFalse(existentialsIdentical(a, c))
    expectNotEqual(ObjectIdentifier(a), ObjectIdentifier(c))
    expectNotEqual(existentialIdentifier(a), existentialIdentifier(c))
    // Swift classes through the new generic APIs.
    expectTrue(identical(c, c))
    expectEqual(identifier(c), ObjectIdentifier(c))
    expectEqual(existentialIdentifier(c), ObjectIdentifier(c))
  }
}

AnyReferenceIdentityTestSuite.test("generic containers") {
  expectBalanced {
    let a = RefCountedType(1)
    let b = RefCountedType(2)
    expectEqual(2, uniqueCount([a, b, a, a.getSelf(), b]))
    let xs = copies(a)
    expectEqual(3, xs.count)
    expectEqual(1, uniqueCount(xs))
    expectTrue(xs[0] === xs[2])
  }
}

AnyReferenceIdentityTestSuite.test("Set<ObjectIdentifier> of mixed references") {
  expectBalanced {
    let a = RefCountedType(1)
    let d = DerivedRefCountedType(1, 2)
    let c = SwiftClass()
    let refs: [any AnyReference] = [a, a.getSelf(), d, d.asBase(),
                                     getImmortal(), getImmortal(), c, c]
    var seen = Set<ObjectIdentifier>()
    for r in refs {
      seen.insert(ObjectIdentifier(r))
    }
    expectEqual(4, seen.count)
    expectTrue(seen.contains(ObjectIdentifier(a)))
    expectTrue(seen.contains(ObjectIdentifier(d)))
    expectTrue(seen.contains(ObjectIdentifier(getImmortal())))
    expectTrue(seen.contains(ObjectIdentifier(c)))
  }
}

AnyReferenceIdentityTestSuite.test("existential copies retain and release") {
  expectBalanced {
    let a = RefCountedType(1)
    do {
      let e: any AnyReference = a
      let copy = e
      expectTrue(existentialsIdentical(e, copy))
      expectEqual(existentialIdentifier(copy), ObjectIdentifier(a))
    }
    expectEqual(1, a.getRefCount())
  }
}

AnyReferenceIdentityTestSuite.test("stress") {
  expectBalanced {
    let a = RefCountedType(1)
    for _ in 0..<1000 {
      let b = RefCountedType(2)
      expectTrue(identical(a, a.getSelf()))
      expectFalse(existentialsIdentical(a, b))
      expectNotEqual(identifier(a), existentialIdentifier(b))
    }
    expectEqual(1, a.getRefCount())
  }
}

// Retains and releases performed by identity operations are balanced; with
// optimizations they perform none at all.
func expectRefCountNeutral(_ body: () -> Void,
                           file: String = #file, line: UInt = #line) {
  resetRefCountStats()
  body()
  expectEqual(getRetainCount(), getReleaseCount(), file: file, line: line)
#if OPTIMIZED
  expectEqual(0, getRetainCount(), file: file, line: line)
#endif
}

AnyReferenceIdentityTestSuite.test("identity operations do not retain") {
  expectBalanced {
    let a = RefCountedType(1)
    let b = RefCountedType(2)
    expectRefCountNeutral { _ = ObjectIdentifier(a) }
    expectRefCountNeutral { _ = identifier(a) }
    expectRefCountNeutral { _ = a === b }
    expectRefCountNeutral { _ = a !== b }
    expectRefCountNeutral { _ = identical(a, b) }
    expectRefCountNeutral { _ = ObjectIdentifier(a) == ObjectIdentifier(b) }
  }
}

// MARK: - Runtime erasure of AnyReference

protocol RefP: AnyReference {
  associatedtype A: AnyReference
  func a() -> A
}

extension RefCountedType: RefP {
  func a() -> ImmortalRefType { getImmortal() }
}

@inline(never)
func useRefP<X: RefP>(_ x: X) -> Bool {
  ObjectIdentifier(x.a()) == ObjectIdentifier(getImmortal())
}

protocol HasRef {
  associatedtype B: AnyReference
  func b() -> B
}

struct Pair<T: AnyReference, U> {
  var t: T
}

// A conditional conformance that does not depend on AnyReference is allowed,
// even if the type itself has an AnyReference-constrained parameter.
extension Pair: HasRef where U: Equatable {
  func b() -> T { t }
}

AnyReferenceIdentityTestSuite.test("dynamic casts to protocols refining AnyReference") {
  expectBalanced {
    let a = RefCountedType(1)
    let boxed: Any = a
    if let p = boxed as? any RefP {
      expectTrue(useRefP(p))
      expectEqual(ObjectIdentifier(p), ObjectIdentifier(a))
    } else {
      expectUnreachable("RefCountedType conforms to RefP")
    }
    expectFalse((getImmortal() as Any) is any RefP)
    expectFalse((ValueType(1) as Any) is any RefP)
  }
}

AnyReferenceIdentityTestSuite.test("conditional conformance of a type with an AnyReference parameter") {
  expectBalanced {
    let a = RefCountedType(1)
    let g: Any = Pair<RefCountedType, Int>(t: a)
    if let q = g as? any HasRef {
      expectEqual(ObjectIdentifier(q.b()), ObjectIdentifier(a))
    } else {
      expectUnreachable("Pair<_, Int> conforms to HasRef")
    }
    let g2: Any = Pair<RefCountedType, () -> ()>(t: a)
    expectFalse(g2 is any HasRef)
  }
}

// The runtime mangled name of a type whose generic signature has an
// AnyReference requirement carries no such requirement, so the runtime can
// demangle and instantiate it.
//
// NOTE: This uses a Swift class argument: `_typeByName` does not currently
// find C++ foreign reference types at all (independently of AnyReference;
// e.g. `_typeByName(_mangledTypeName(RefCountedType.self)!)` is nil).
AnyReferenceIdentityTestSuite.test("mangled type names round-trip") {
  let name = _mangledTypeName(Pair<SwiftClass, Int>.self)
  expectNotNil(name)
  expectNotNil(_mangledTypeName(Pair<RefCountedType, Int>.self))
  if let name = name, let type = _typeByName(name) {
    expectTrue(type == Pair<SwiftClass, Int>.self)
  } else {
    expectUnreachable("could not round-trip the mangled name")
  }
  // At runtime, `any AnyReference` is `Any`.
  expectTrue((any AnyReference).self == Any.self)
  expectTrue([any AnyReference].self == [Any].self)
}

runAllTests()
