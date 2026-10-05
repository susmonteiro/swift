// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-swift-frontend -emit-module -enable-experimental-feature AnyReference -module-name Lib -o %t/Lib.swiftmodule %t/Lib.swift
// RUN: %target-swift-frontend -typecheck -verify -verify-ignore-unrelated -enable-experimental-feature AnyReference -I %t %t/Client.swift
// RUN: %target-swift-ide-test -print-module -module-to-print=Lib -source-filename=x -I %t -enable-experimental-feature AnyReference | %FileCheck %s
// RUN: %target-swift-frontend -emit-sil -enable-experimental-feature AnyReference -I %t %t/Client.swift -module-name Client -o /dev/null -D NO_ERRORS

// REQUIRES: swift_feature_AnyReference

// The AnyReference layout requirement and `any AnyReference` survive a
// round trip through a serialized module.

//--- Lib.swift
public protocol RefP: AnyReference {}
public protocol P {}

public func takesAR<T: AnyReference>(_ x: T) -> T { x }
public func takesExistentialAR(_ x: any AnyReference) {}
public func takesPAndAR(_ x: any P & AnyReference) {}
public func takesAOAndAR<T: AnyObject & AnyReference>(_ x: T) {}
public func makeExistential<T: AnyReference>(_ x: T) -> any AnyReference { x }

public struct G<T: AnyReference> {
  public var x: T
  public init(_ x: T) { self.x = x }
}

extension G where T: AnyObject {
  public func onlyForAnyObject() {}
}

public protocol HasARAssoc {
  associatedtype A: AnyReference
}

public typealias MyAR = AnyReference

// swift-ide-test prints declarations sorted by name, so don't depend on order.
// CHECK-DAG: protocol RefP : AnyReference {
// CHECK-DAG: func takesAR<T>(_ x: T) -> T where T : AnyReference
// CHECK-DAG: func takesExistentialAR(_ x: any AnyReference)
// CHECK-DAG: func takesPAndAR(_ x: any P & AnyReference)
// CHECK-DAG: func takesAOAndAR<T>(_ x: T) where T : AnyObject
// CHECK-DAG: func makeExistential<T>(_ x: T) -> any AnyReference where T : AnyReference
// CHECK-DAG: struct G<T> where T : AnyReference {
// CHECK-DAG: extension G where T : AnyObject {
// CHECK-DAG: associatedtype A : AnyReference
// CHECK-DAG: typealias MyAR = AnyReference

//--- Client.swift
import Lib

class C: RefP {}
final class D: P {}
struct S {}

func test(_ c: C, _ d: D, _ e: any AnyReference) {
  _ = takesAR(c)
  takesExistentialAR(c)
  takesExistentialAR(e)
  takesPAndAR(d)
  takesAOAndAR(c)
  _ = makeExistential(c)
  _ = G(c)
  G(c).onlyForAnyObject()
  _ = takesAR(e)
  let _: MyAR = c
}

struct ConformsToHasARAssoc: HasARAssoc {
  typealias A = C
}

#if !NO_ERRORS
func errors(_ e: any AnyReference) {
  _ = takesAR(S()) // expected-error {{global function 'takesAR' requires that 'S' be a class or foreign reference type}}
  takesExistentialAR(S()) // expected-error {{argument type 'S' does not conform to expected type 'any AnyReference'}}
  _ = G(S()) // expected-error 2 {{generic struct 'G' requires that 'S' be a class or foreign reference type}}
  takesAOAndAR(e) // expected-error {{global function 'takesAOAndAR' requires that 'any AnyReference' be a class type}}
}

struct BadHasARAssoc: HasARAssoc {
  // expected-error@-1 {{type 'BadHasARAssoc' does not conform to protocol 'HasARAssoc'}}
  // expected-note@-2 {{add stubs for conformance}}
  typealias A = S // expected-note {{possibly intended match 'BadHasARAssoc.A' (aka 'S') does not conform to 'any AnyReference'}}
}

struct BadRefP: RefP {}
// expected-error@-1 {{type 'BadRefP' does not conform to protocol 'RefP'}}
// expected-error@-2 {{'RefP' requires that 'BadRefP' be a class or foreign reference type}}
// expected-note@-3 {{requirement specified as 'Self' : 'AnyReference' [with Self = BadRefP]}}
#endif
