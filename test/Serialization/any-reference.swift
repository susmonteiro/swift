// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %target-swift-frontend -emit-module -enable-experimental-feature AnyReference -module-name Lib -o %t/Lib.swiftmodule %t/Lib.swift
// RUN: %target-swift-ide-test -print-module -module-to-print=Lib -source-filename=x -I %t -enable-experimental-feature AnyReference | %FileCheck %s

// A client that doesn't enable the feature can still use the module, and sees
// the same types (and therefore the same mangled names).
// RUN: %target-swift-frontend -emit-silgen -I %t %t/Client.swift | %FileCheck --check-prefix=CLIENT %s
// RUN: %target-swift-frontend -emit-silgen -I %t %t/Client.swift -enable-experimental-feature AnyReference | %FileCheck --check-prefix=CLIENT %s

// Same, for a module that spells the Builtin type directly, like the standard
// library does.
// RUN: %target-swift-frontend -emit-module -parse-stdlib -enable-experimental-feature AnyReference -module-name BuiltinLib -o %t/BuiltinLib.swiftmodule %t/BuiltinLib.swift
// RUN: %target-swift-frontend -typecheck -parse-stdlib -I %t %t/BuiltinClient.swift

// REQUIRES: swift_feature_AnyReference

//--- Lib.swift
public protocol P {}
public protocol ClassP: AnyObject {}

public typealias LibAnyReference = AnyReference

public func takesExistentialAnyReference(_ x: any AnyReference) {}
public func takesPAndAnyReference(_ x: any P & AnyReference) {}
public func takesAnyObjectAndAnyReference<T: AnyObject & AnyReference>(_ x: T) {}
public func takesClassPAndAnyReference(_ x: any ClassP & AnyReference) {}
public func takesOptional(_ x: (any AnyReference)?) {}
public func takesArray(_ x: [any P & AnyReference]) {}
public func takesClosure(_ x: (any P & AnyReference) -> Void) {}
public func takesMetatype(_ x: any AnyReference.Type) {}
public func takesAlias(_ x: LibAnyReference) {}
public func returnsAnyReference() -> any AnyReference { fatalError() }

// CHECK-DAG: typealias LibAnyReference = AnyReference
// CHECK-DAG: func takesExistentialAnyReference(_ x: any AnyReference)
// CHECK-DAG: func takesPAndAnyReference(_ x: any P & AnyReference)
// CHECK-DAG: func takesAnyObjectAndAnyReference<T>(_ x: T) where T : AnyObject
// CHECK-DAG: func takesClassPAndAnyReference(_ x: any ClassP & AnyReference)
// CHECK-DAG: func takesOptional(_ x: (any AnyReference)?)
// CHECK-DAG: func takesArray(_ x: [any P & AnyReference])
// CHECK-DAG: func takesClosure(_ x: (any P & AnyReference) -> Void)
// CHECK-DAG: func takesMetatype(_ x: any AnyReference.Type)
// CHECK-DAG: func takesAlias(_ x: any LibAnyReference)
// CHECK-DAG: func returnsAnyReference() -> any AnyReference

//--- Client.swift
import Lib

// Only uses types from 'Lib'; never spells 'Swift.AnyReference'.
public func forward(_ x: LibAnyReference) {
  takesExistentialAnyReference(x)
  takesAlias(x)
  takesOptional(x)
}

public func references() {
  _ = takesPAndAnyReference
  _ = takesArray
  _ = takesClosure
  _ = returnsAnyReference()
  _ = takesClassPAndAnyReference
}

// CLIENT-LABEL: sil [ossa] @$s6Client7forwardyyypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> () {
// CLIENT: function_ref @$s3Lib28takesExistentialAnyReferenceyyypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> ()
// CLIENT: function_ref @$s3Lib10takesAliasyyypRlsA_XPF : $@convention(thin) (@in_guaranteed any AnyReference) -> ()
// CLIENT: function_ref @$s3Lib13takesOptionalyyypRlsA_XPSgF : $@convention(thin) (@in_guaranteed Optional<any AnyReference>) -> ()
// CLIENT-LABEL: sil [ossa] @$s6Client10referencesyyF : $@convention(thin) () -> () {
// CLIENT: function_ref @$s3Lib21takesPAndAnyReferenceyyAA1P_pRlsA_XPF : $@convention(thin) (@in_guaranteed any P & AnyReference) -> ()
// CLIENT: function_ref @$s3Lib10takesArrayyySayAA1P_pRlsA_XPGF : $@convention(thin) (@guaranteed Array<any P & AnyReference>) -> ()
// CLIENT: function_ref @$s3Lib12takesClosureyyyAA1P_pRlsA_XPXEF : $@convention(thin) (@guaranteed @noescape @callee_guaranteed (@in_guaranteed any P & AnyReference) -> ()) -> ()
// CLIENT: function_ref @$s3Lib19returnsAnyReferenceypRlsA_XPyF : $@convention(thin) () -> @out any AnyReference
// A class-constrained protocol makes AnyReference redundant: the canonical
// type is a class existential.
// CLIENT: function_ref @$s3Lib26takesClassPAndAnyReferenceyyAA0C1P_pF : $@convention(thin) (@guaranteed any ClassP) -> ()

//--- BuiltinLib.swift
public typealias BuiltinAnyReference = Builtin.AnyReference
public protocol Q {}
public func takesBuiltin(_ x: BuiltinAnyReference) {}
public func takesQAndBuiltin(_ x: any Q & BuiltinAnyReference) {}

//--- BuiltinClient.swift
import BuiltinLib

func forward(_ x: BuiltinAnyReference) { takesBuiltin(x) }
let _ = takesQAndBuiltin
