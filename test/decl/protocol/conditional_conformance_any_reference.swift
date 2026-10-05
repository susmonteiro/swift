// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// `AnyReference` is erased at runtime, so a conditional conformance to a
// non-marker protocol cannot depend on it: a dynamic cast such as
// `[1] as Any as? any P` could not check it, and would succeed.

protocol P {
  func f()
}

struct Box<T> {}

extension Box: P where T: AnyReference { // expected-error {{conditional conformance to non-marker protocol 'P' cannot depend on 'T' being 'AnyReference'}}
  func f() {}
}

struct Box2<T> {}

// A conditional conformance to a marker protocol may depend on AnyReference.
extension Box2: Sendable where T: AnyReference {}

struct Box3<T> {}

// Depending on AnyObject is unaffected.
extension Box3: P where T: AnyObject {
  func f() {}
}

struct Box4<T> {}

// A conditional requirement that implies AnyReference through a superclass
// requirement is fine: the superclass requirement is checked at runtime.
class C {}
extension Box4: P where T: C {
  func f() {}
}

// An unconditional conformance of a type with an AnyReference-constrained
// parameter is fine: the requirement is enforced statically wherever the type
// is formed.
struct ConstrainedBox<T: AnyReference>: P {
  func f() {}
}
