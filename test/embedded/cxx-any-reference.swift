// RUN: %target-swift-emit-ir %s -I %S%{fs-sep}..%{fs-sep}Interop%{fs-sep}Cxx%{fs-sep}foreign-reference%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature Embedded -wmo -parse-as-library -module-name main -O | %FileCheck %s

// REQUIRES: swift_feature_Embedded

// Embedded Swift gets ObjectIdentifier and the identity operators for foreign
// reference types, and they compare pointers without retaining or releasing.

import AnyReferenceFRTs

public class SwiftClass {}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$e4main15classIdentifierySOAA10SwiftClassCF"(ptr {{.*}}%0)
// CHECK-NEXT: entry:
// CHECK-NEXT: ret ptr %0
public func classIdentifier(_ c: SwiftClass) -> ObjectIdentifier {
  ObjectIdentifier(c)
}

// CHECK-LABEL: define {{.*}}swiftcc ptr @"$e4main19referenceIdentifierySOSo14RefCountedTypeVF"(ptr {{.*}}%0)
// CHECK-NEXT: entry:
// CHECK-NEXT: ret ptr %0
public func referenceIdentifier(_ r: RefCountedType) -> ObjectIdentifier {
  ObjectIdentifier(r)
}

// CHECK-LABEL: define {{.*}}swiftcc i1 @"$e4main18referenceIdenticalySbSo14RefCountedTypeV_ADSgtF"(ptr {{.*}}%0, ptr {{.*}}%1)
// CHECK-NEXT: entry:
// CHECK-NEXT: %2 = icmp eq ptr %0, %1
// CHECK-NEXT: ret i1 %2
public func referenceIdentical(_ a: RefCountedType,
                               _ b: RefCountedType?) -> Bool {
  a === b
}

// CHECK-LABEL: define {{.*}}swiftcc i1 @"$e4main20immortalNotIdenticalySbSo15ImmortalRefTypeV_ADtF"(ptr {{.*}}%0, ptr {{.*}}%1)
// CHECK-NEXT: entry:
// CHECK-NEXT: %2 = icmp ne ptr %0, %1
// CHECK-NEXT: ret i1 %2
public func immortalNotIdentical(_ a: ImmortalRefType,
                                 _ b: ImmortalRefType) -> Bool {
  a !== b
}
