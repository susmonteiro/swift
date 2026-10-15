// RUN: %target-swift-frontend -emit-ir -g %s -enable-experimental-feature AnyReference | %FileCheck %s

// REQUIRES: swift_feature_AnyReference

// Debug info round-trips each type through the mangler and the AST demangler,
// which must agree on the AnyReference bit.

public protocol P {}
public protocol RefP: AnyReference {}
public typealias PP = P
public typealias AR = AnyReference
public typealias AO = AnyObject

// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$sypRlsA_XPD"
public func bare(_ x: any AnyReference) {}

// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$s4main1P_pRlsA_XPD"
public func composition(_ x: any P & AnyReference) {}

// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$s4main4RefP_pRlsA_XPD"
public func refProtocol(_ x: any RefP & AnyReference) {}

// AnyObject makes AnyReference redundant.
// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$syXlD"
public func withAnyObject(_ x: any AnyObject & AnyReference) {}

// Sugared members.
public func sugaredProtocol(_ x: any PP & AnyReference) {}
public func sugaredAnyReference(_ x: any P & AR) {}
public func sugaredAnyObject(_ x: any AO & AnyReference) {}
public func alias(_ x: AR) {}

// Structural positions.
public func optional(_ x: (any AnyReference)?) {}
// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$sSay4main1P_pRlsA_XPGD"
public func array(_ x: [any P & AnyReference]) {}
// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$s4main1P_pRlsA_XPIgn_D"
public func closure(_ x: (any P & AnyReference) -> Void) {}
public func metatype(_ x: any AnyReference.Type) {}
// CHECK-DAG: !DICompositeType(tag: DW_TAG_structure_type, name: "$s4main1P_pRlsA_XPXMtD"
public func compositionMetatype(_ x: (any P & AnyReference).Type) {}
