// RUN: %target-typecheck-verify-swift -enable-experimental-feature AnyReference

// REQUIRES: swift_feature_AnyReference
// REQUIRES: objc_interop

// Objective-C classes, @objc protocol existentials and CF types satisfy
// `AnyReference` because they satisfy `AnyObject`.

import Foundation

@objc protocol ObjCProto {}
class SwiftObjCSubclass: NSObject, ObjCProto {}

// An @objc protocol may refine AnyReference (it is class-bound anyway).
@objc protocol ObjCRefProto: AnyReference {}
class ObjCRefImpl: NSObject, ObjCRefProto {}

func takesAR<T: AnyReference>(_: T) {}
// expected-note@-1 {{where 'T' = 'AnyClass' (aka 'any AnyObject.Type')}}
func takesExistentialAR(_: any AnyReference) {}

func objc(_ obj: NSObject, _ str: NSString, _ p: any ObjCProto,
          _ nsp: any NSObjectProtocol, _ cf: CFString,
          _ sub: SwiftObjCSubclass, _ cls: AnyClass) {
  takesAR(obj)
  takesAR(str)
  takesAR(p)
  takesAR(nsp)
  takesAR(cf)
  takesAR(sub)
  takesAR(ObjCRefImpl())
  takesAR(ObjCRefImpl() as any ObjCRefProto)

  // Metatypes, including class metatypes, are not references.
  takesAR(cls) // expected-error {{global function 'takesAR' requires that 'AnyClass' (aka 'any AnyObject.Type') be a class or foreign reference type}}

  takesExistentialAR(obj)
  takesExistentialAR(p)
  takesExistentialAR(nsp)
  takesExistentialAR(cf)

  _ = ObjectIdentifier(obj) == ObjectIdentifier(sub)
  _ = obj === sub
  _ = p === nsp
}
