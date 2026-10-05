// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t/Lib.swiftinterface) %s -module-name Lib -enable-experimental-feature AnyReference
// RUN: %target-swift-typecheck-module-from-interface(%t/Lib.swiftinterface) -module-name Lib -enable-experimental-feature AnyReference
// RUN: %FileCheck %s --input-file %t/Lib.swiftinterface

// REQUIRES: swift_feature_AnyReference

// Declarations that don't spell AnyReference but refer to declarations that
// are guarded by `$BuiltinAnyReference` must be guarded as well, otherwise
// older compilers fail to find the referenced declaration.

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public protocol RefP : AnyReference {
public protocol RefP: AnyReference {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: extension Lib::RefP {
extension RefP {
  public func ident() -> ObjectIdentifier { ObjectIdentifier(self) }
}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func takeP(_ x: any Lib::RefP) -> Swift::ObjectIdentifier
// CHECK-NEXT: #endif
public func takeP(_ x: any RefP) -> ObjectIdentifier { x.ident() }

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public protocol RefP2 : Lib::RefP {
public protocol RefP2: RefP {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public struct Box<T> where T : AnyReference {
public struct Box<T: AnyReference> { public var t: T }

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func takeBox(_ b: Lib::Box<{{.*}}AnyObject>)
// CHECK-NEXT: #endif
public func takeBox(_ b: Box<AnyObject>) {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func someRef<T>(_ t: T) -> some AnyReference where T : AnyReference
// The opaque result type declaration must not get its own (empty) guard.
// CHECK-NOT: #if
// CHECK: #endif
public func someRef<T: AnyReference>(_ t: T) -> some AnyReference { t }

// A class conforming to a protocol that refines AnyReference is guarded, and
// so is everything that refers to it, including inlinable functions.
// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public class C : Lib::RefP {
public class C: RefP { public init() {} }

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: @inlinable public func plain(_ a: Lib::C, _ b: Lib::C) -> Swift::Bool
@inlinable public func plain(_ a: C, _ b: C) -> Bool { a === b }

// Redundant AnyReference is dropped from the canonical type, but still
// printed, so it needs a guard too.
public protocol CP: AnyObject {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func z(_ x: Swift::AnyObject & Swift::AnyReference)
// CHECK-NEXT: #endif
public func z(_ x: AnyObject & AnyReference) {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public typealias Y = Swift::AnyObject & Swift::AnyReference
// CHECK-NEXT: #endif
public typealias Y = AnyObject & AnyReference

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public typealias Y2 = Lib::CP & Swift::AnyReference
// CHECK-NEXT: #endif
public typealias Y2 = CP & AnyReference

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func v(_ x: any Lib::CP & Swift::AnyReference)
// CHECK-NEXT: #endif
public func v(_ x: any CP & AnyReference) {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func useY(_ x: Lib::Y)
// CHECK-NEXT: #endif
public func useY(_ x: Y) {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public var gv: (Swift::AnyObject & Swift::AnyReference)?
public var gv: (AnyObject & AnyReference)? = nil

// Declarations unrelated to AnyReference are not guarded.
// CHECK-NOT: #if
// CHECK: public func unrelated()
// CHECK-NOT: #if
public func unrelated() {}
