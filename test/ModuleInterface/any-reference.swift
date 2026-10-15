// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t/Lib.swiftinterface) %s -module-name Lib -enable-experimental-feature AnyReference
// RUN: %target-swift-typecheck-module-from-interface(%t/Lib.swiftinterface) -module-name Lib
// RUN: %FileCheck %s < %t/Lib.swiftinterface

// REQUIRES: swift_feature_AnyReference

// Declarations that use 'AnyReference' are guarded by '$AnyReference' so that
// compilers without the feature skip them.

// CHECK: swift-module-flags:{{.*}} -enable-experimental-feature AnyReference

public protocol P {}

// CHECK:      #if compiler(>=5.3) && $AnyReference
// CHECK-NEXT: public func existential(_: any AnyReference)
// CHECK-NEXT: #endif
public func existential(_: any AnyReference) {}

// CHECK:      #if compiler(>=5.3) && $AnyReference
// CHECK-NEXT: public func composition(_: any Lib::P & Swift::AnyReference)
// CHECK-NEXT: #endif
public func composition(_: any P & AnyReference) {}

// CHECK:      #if compiler(>=5.3) && $AnyReference
// CHECK-NEXT: public func optional(_: (any AnyReference)?)
// CHECK-NEXT: #endif
public func optional(_: (any AnyReference)?) {}

// CHECK:      #if compiler(>=5.3) && $AnyReference
// CHECK-NEXT: public func returnsAnyReference() -> any AnyReference
// CHECK-NEXT: #endif
public func returnsAnyReference() -> any AnyReference { fatalError() }

// Declarations that don't use it are not guarded.
// CHECK-NOT:  $AnyReference
// CHECK:      public func unrelated()
public func unrelated() {}

// Typealiases are printed after the other declarations.
// CHECK-NEXT: #if compiler(>=5.3) && $AnyReference
// CHECK-NEXT: public typealias Alias = Swift::AnyReference
// CHECK-NEXT: #endif
public typealias Alias = AnyReference
