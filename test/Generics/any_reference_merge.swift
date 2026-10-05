// RUN: %target-swift-frontend -typecheck -enable-experimental-feature AnyReference -debug-generic-signatures %s 2>&1 | %FileCheck %s --check-prefix=SIG
// RUN: %target-swift-emit-silgen -enable-experimental-feature AnyReference %s | %FileCheck %s --check-prefix=SIL

// REQUIRES: swift_feature_AnyReference

// When AnyReference is combined with a stronger layout (AnyObject, or a
// superclass), the stronger one must win regardless of the order in which
// the requirements are seen. Otherwise the minimized signature (which is
// mangled and used by clients) and the archetype's layout (which determines
// how the body lowers the parameter) disagree.

public protocol P: AnyReference {}
open class C { public var x = 42; public init() {} }

// SIG-LABEL: any_reference_merge.(file).arAO@
// SIG: Generic signature: <T where T : AnyObject>
// SIL-LABEL: sil [ossa] @{{.*}}4arAO{{.*}} : $@convention(thin) <T where T : AnyObject> (@guaranteed T) -> @owned T
public func arAO<T: AnyReference & AnyObject>(_ t: T) -> T { t }

// SIG-LABEL: any_reference_merge.(file).aoAR@
// SIG: Generic signature: <T where T : AnyObject>
// SIL-LABEL: sil [ossa] @{{.*}}4aoAR{{.*}} : $@convention(thin) <T where T : AnyObject> (@guaranteed T) -> @owned T
public func aoAR<T: AnyObject & AnyReference>(_ t: T) -> T { t }

// SIG-LABEL: any_reference_merge.(file).whereAO@
// SIG: Generic signature: <T where T : AnyObject>
// SIL-LABEL: sil [ossa] @{{.*}}7whereAO{{.*}} : $@convention(thin) <T where T : AnyObject> (@guaranteed T) -> @owned T
public func whereAO<T: AnyReference>(_ t: T) -> T where T: AnyObject { t }

// SIG-LABEL: any_reference_merge.(file).protoAndClass@
// SIG: Generic signature: <T where T : C, T : P>
// SIL-LABEL: sil [ossa] @{{.*}}13protoAndClass{{.*}} : $@convention(thin) <T where {{.*}}> (@guaranteed T) -> Int
public func protoAndClass<T: P>(_ t: T) -> Int where T: C { t.x }

// Class-only operations are available once AnyObject wins.
public func classOps<T: AnyReference & AnyObject>(_ t: T) {
  _ = t as AnyObject
  _ = Unmanaged.passUnretained(t)
  weak var w = t
  _ = w
}

public func uniquelyReferenced<T: AnyReference & AnyObject>(_ t: inout T) -> Bool {
  isKnownUniquelyReferenced(&t)
}
