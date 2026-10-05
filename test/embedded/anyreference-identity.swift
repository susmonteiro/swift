// RUN: %target-run-simple-swift(-enable-experimental-feature Embedded -enable-experimental-feature AnyReference -parse-as-library -wmo %target-embedded-posix-shim) | %FileCheck %s
// RUN: %target-run-simple-swift(-enable-experimental-feature Embedded -enable-experimental-feature AnyReference -parse-as-library -wmo -O %target-embedded-posix-shim) | %FileCheck %s
// RUN: %target-run-simple-swift(-enable-experimental-feature Embedded -enable-experimental-feature AnyReference -parse-as-library -wmo -Osize %target-embedded-posix-shim) | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: optimized_stdlib
// REQUIRES: swift_feature_Embedded
// REQUIRES: swift_feature_AnyReference

// The AnyReference overloads of ObjectIdentifier.init, ===, and !== are
// available in Embedded Swift and agree with the AnyObject overloads.

class C {}
final class D: C {}
final class U {}

func identifier<T: AnyReference>(_ x: T) -> ObjectIdentifier {
  return ObjectIdentifier(x)
}

func identical<T: AnyReference>(_ a: T?, _ b: T?) -> Bool {
  return a === b
}

func identicalMixed<T: AnyReference, V: AnyReference>(_ a: T?, _ b: V?)
    -> Bool {
  return a === b
}

func notIdentical<T: AnyReference>(_ a: T?, _ b: T?) -> Bool {
  return a !== b
}

@main
struct Main {
  static func main() {
    let c1 = C()
    let c2 = c1
    let c3 = C()
    let d = D()
    let u = U()

    print(identifier(c1) == ObjectIdentifier(c1)) // CHECK: true
    print(identifier(c1) == identifier(c2))       // CHECK-NEXT: true
    print(identifier(c1) == identifier(c3))       // CHECK-NEXT: false
    print(identical(c1, c2))                      // CHECK-NEXT: true
    print(identical(c1, c3))                      // CHECK-NEXT: false
    print(identical(c1, nil))                     // CHECK-NEXT: false
    print(identical(nil as C?, nil))              // CHECK-NEXT: true
    print(notIdentical(c1, c3))                   // CHECK-NEXT: true
    print(identical(d as C, d))                   // CHECK-NEXT: true
    print(identicalMixed(c1, u))                  // CHECK-NEXT: false
    print(identicalMixed(d, d as C))              // CHECK-NEXT: true
    print(c1 === c2)                              // CHECK-NEXT: true
    print(c1 !== c3)                              // CHECK-NEXT: true
  }
}
