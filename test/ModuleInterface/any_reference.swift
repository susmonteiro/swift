// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t/AnyRef.swiftinterface) %s -module-name AnyRef -enable-experimental-feature AnyReference
// RUN: %target-swift-typecheck-module-from-interface(%t/AnyRef.swiftinterface) -module-name AnyRef -enable-experimental-feature AnyReference
// RUN: %FileCheck %s --input-file %t/AnyRef.swiftinterface

// Build a client against the module built from the interface.
// RUN: %target-swift-frontend -compile-module-from-interface %t/AnyRef.swiftinterface -module-name AnyRef -o %t/AnyRef.swiftmodule -enable-experimental-feature AnyReference
// RUN: %target-swift-frontend -typecheck -I %t %S/Inputs/any_reference_client.swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// Declarations that use AnyReference are guarded by `$BuiltinAnyReference`,
// so older compilers skip them.

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func takesAR<T>(_ x: T) -> T where T : AnyReference
// CHECK-NEXT: #endif
public func takesAR<T: AnyReference>(_ x: T) -> T { x }

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public func takesExistentialAR(_ x: any AnyReference)
// CHECK-NEXT: #endif
public func takesExistentialAR(_ x: any AnyReference) {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public protocol RefP : AnyReference {
// CHECK-NEXT: }
// CHECK-NEXT: #endif
public protocol RefP: AnyReference {}

// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: public struct G<T> where T : AnyReference {
public struct G<T: AnyReference> {
  public var x: T
  public init(_ x: T) { self.x = x }
}

// `AnyObject & AnyReference` is `AnyObject`, so no guard is needed.
// CHECK-NOT: $BuiltinAnyReference
// CHECK: public func takesAOAndAR<T>(_ x: T) where T : AnyObject
public func takesAOAndAR<T: AnyObject & AnyReference>(_ x: T) {}

// A declaration that does not mention AnyReference is not guarded.
// CHECK-NOT: $BuiltinAnyReference
// CHECK: public func unrelated()
public func unrelated() {}

// An inlinable body that uses AnyReference.
// CHECK: #if compiler(>=5.3) && $BuiltinAnyReference
// CHECK-NEXT: @inlinable public func inlinableUse<T>(_ x: T) -> any AnyReference where T : AnyReference {
// CHECK-NEXT:   x
// CHECK-NEXT: }
// CHECK-NEXT: #endif
@inlinable
public func inlinableUse<T: AnyReference>(_ x: T) -> any AnyReference {
  x
}
