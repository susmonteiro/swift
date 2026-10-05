// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference

// AnyReference constraints are erased at runtime, so a conditional
// conformance to a non-marker protocol must not depend on them, not even
// through an existential type in a same-type or superclass requirement.

protocol Q {}
protocol P2 {}
protocol RefP: AnyReference {}
class C {}

struct W<T> {}

extension W: Q where T == any AnyReference {}
// expected-error@-1 {{conditional conformance to non-marker protocol 'Q' cannot depend on a requirement on 'T' involving 'AnyReference'}}

extension Array: Q where Element == any P2 & AnyReference {}
// expected-error@-1 {{conditional conformance to non-marker protocol 'Q' cannot depend on a requirement on 'Element' involving 'AnyReference'}}

struct V<T> {}
extension V: Q where T: AnyReference {}
// expected-error@-1 {{conditional conformance to non-marker protocol 'Q' cannot depend on 'T' being 'AnyReference'}}

struct X<T> {}
extension X: Q where T == [any AnyReference] {}
// expected-error@-1 {{conditional conformance to non-marker protocol 'Q' cannot depend on a requirement on 'T' involving 'AnyReference'}}

// Conformance requirements to protocols refining AnyReference are checked at
// runtime, so they're fine.
struct Y<T> {}
extension Y: Q where T: RefP {}

// So are AnyObject requirements.
struct Z<T> {}
extension Z: Q where T: AnyObject {}
extension Z: P2 where T == C {}
