// RUN: %target-typecheck-verify-swift -I %S%{fs-sep}Inputs -cxx-interoperability-mode=default -enable-experimental-feature AnyReference -target %target-swift-5.8-abi-triple

// REQUIRES: swift_feature_AnyReference

// Every imported C++ foreign reference type (FRT) satisfies `AnyReference`,
// as does every type that satisfies `AnyObject`. C++ value types, Optionals,
// pointers, metatypes and `any AnyReference` itself do not.

import AnyReferenceFRTs

class SwiftClass {}
final class SwiftFinalClass {}
struct SwiftStruct {}
enum SwiftEnum { case a }
protocol RefP: AnyReference {}
extension RefCountedType: RefP {}
extension SwiftClass: RefP {}

func takesAR<T: AnyReference>(_: T) {}
// expected-note@-1 * {{where 'T' = }}
func takesOptionalAR<T: AnyReference>(_: T?) {}
func takesARArray<T: AnyReference>(_: [T]) {}
// expected-note@-1 * {{where 'T' = }}
func takesAO<T: AnyObject>(_: T) {}
// expected-note@-1 * {{where 'T' = }}
func takesExistentialAR(_: any AnyReference) {}
func takesBareAR(_: AnyReference) {}
func takesSomeAR(_: some AnyReference) {}

// MARK: - Accepted

func acceptedFRTs(_ mi: MultipleInheritanceRefCounted) {
  // Shared reference types.
  takesAR(RefCountedType(1))
  takesAR(DerivedRefCountedType(1, 2))
  takesAR(RefCountedType(1).getSelf())
  // A shared reference type whose annotated base is not at offset zero.
  takesAR(mi)
  takesAR(mi.asNonPrimaryBase())
  // Immortal reference types, in both spellings.
  takesAR(getImmortal())
  takesAR(getImmortalSharedSpelling())
  // An unsafe reference type (no strict memory safety here).
  takesAR(getUnsafeRef())
  // A class template specialization.
  takesAR(getTemplatedRef())
  // A forward-declared reference type.
  takesAR(getForwardDeclaredRef())
  // A `const T *` is imported as the same class type.
  takesAR(getConstImmortal())
  // An unwrapped Optional.
  takesAR(maybeImmortal(true)!)
  if let r = maybeRefCounted(true) { takesAR(r) }
  // `T?` where `T: AnyReference`.
  takesOptionalAR(maybeImmortal(true))
  takesOptionalAR(maybeRefCounted(false))

  takesSomeAR(getImmortal())
  takesBareAR(getImmortal())

  takesExistentialAR(RefCountedType(1))
  takesExistentialAR(DerivedRefCountedType(1, 2))
  takesExistentialAR(getImmortal())
  takesExistentialAR(getUnsafeRef())
  takesExistentialAR(getTemplatedRef())

  takesARArray([getImmortal(), getImmortal()])
  takesARArray([RefCountedType(1), RefCountedType(2)])
}

func acceptedSwiftTypes(_ ao: AnyObject, _ p: any RefP) {
  takesAR(SwiftClass())
  takesAR(SwiftFinalClass())
  takesAR(ao)
  takesExistentialAR(SwiftClass())
  takesExistentialAR(ao)
  takesExistentialAR(p)
  takesARArray([SwiftClass()])
}

// Heterogeneous collections of `any AnyReference`.
func heterogeneous() -> [any AnyReference] {
  let refs: [any AnyReference] = [
    RefCountedType(1), getImmortal(), getUnsafeRef(), getTemplatedRef(),
    SwiftClass(),
  ]
  let _: [AnyReference] = refs
  let _: (any AnyReference)? = getImmortal()
  let _: (any AnyReference)? = nil
  // `any AnyReference` can be upcast to `Any`.
  let _: Any = refs[0]
  let _: [Any] = refs
  return refs
}

// Generic code forwarding its constraints.
func forwardAO<T: AnyObject>(_ x: T) { takesAR(x); takesExistentialAR(x) }
func forwardAR<T: AnyReference>(_ x: T) { takesAR(x); takesExistentialAR(x) }
func forwardClass<T: SwiftClass>(_ x: T) { takesAR(x) }
func forwardRefP<T: RefP>(_ x: T) { takesAR(x); takesExistentialAR(x) }
func forwardFRTSuperclass<T: RefCountedType>(_ x: T) { takesAR(x) }
func forwardArray<T: AnyReference>(_ xs: [T]) { takesARArray(xs) }

// SE-0352: an `any AnyReference` existential is opened when passed to a
// generic parameter constrained to `AnyReference`.
func openExistential(_ x: any AnyReference, _ p: any RefP) {
  takesAR(x)
  takesAR(p)
  takesSomeAR(x)
}

// A protocol refining AnyReference can be adopted by FRTs and Swift classes.
func usesRefP() {
  let _: any RefP = RefCountedType(1)
  let _: any RefP = SwiftClass()
  let _: any RefP & AnyReference = RefCountedType(1)
}

// A class may redundantly state `AnyReference`, like `AnyObject`.
class ClassWithRedundantAR: AnyReference {}

// Casting *from* `any AnyReference` to a concrete type is allowed.
func castsFrom(_ x: any AnyReference) {
  _ = x as? SwiftClass
  _ = x is SwiftClass
  _ = x as? RefCountedType
}

// MARK: - Rejected

func rejectedTypes(_ frtPtr: RefCountedTypePtr) {
  // Optional FRTs are not reference types.
  takesAR(maybeImmortal(true))
  // expected-error@-1 {{value of optional type 'ImmortalRefType?' must be unwrapped to a value of type 'ImmortalRefType'}}
  // expected-note@-2 {{coalesce using '??'}}
  // expected-note@-3 {{force-unwrap using '!'}}

  // C++ value types.
  takesAR(ValueType(1))
  // expected-error@-1 {{global function 'takesAR' requires that 'ValueType' be a class or foreign reference type}}

  // A pointer to a C++ value type.
  takesAR(getValueTypePointer())
  // expected-error@-1 {{global function 'takesAR' requires that 'UnsafeMutablePointer<ValueType>' be a class or foreign reference type}}

  // A SWIFT_REFCOUNTED_PTR smart pointer is a C++ value type.
  takesAR(frtPtr)
  // expected-error@-1 {{global function 'takesAR' requires that 'RefCountedTypePtr' (aka 'RefPtr<RefCountedType>') be a class or foreign reference type}}

  // Swift value types.
  takesAR(SwiftStruct())
  // expected-error@-1 {{global function 'takesAR' requires that 'SwiftStruct' be a class or foreign reference type}}
  takesAR(SwiftEnum.a)
  // expected-error@-1 {{global function 'takesAR' requires that 'SwiftEnum' be a class or foreign reference type}}
  takesAR(1)
  // expected-error@-1 {{global function 'takesAR' requires that 'Int' be a class or foreign reference type}}

  // Metatypes.
  takesAR(SwiftClass.self)
  // expected-error@-1 {{global function 'takesAR' requires that 'SwiftClass.Type' be a class or foreign reference type}}
  takesAR(RefCountedType.self)
  // expected-error@-1 {{global function 'takesAR' requires that 'RefCountedType.Type' be a class or foreign reference type}}
}

func rejectedExistentialConversions() {
  let _: any AnyReference = ValueType(1)
  // expected-error@-1 {{cannot convert value of type 'ValueType' to specified type 'any AnyReference'}}
  let _: any AnyReference = SwiftStruct()
  // expected-error@-1 {{cannot convert value of type 'SwiftStruct' to specified type 'any AnyReference'}}
  let _: any AnyReference = 1
  // expected-error@-1 {{cannot convert value of type 'Int' to specified type 'any AnyReference'}}
  let _: any AnyReference = SwiftClass.self
  // expected-error@-1 {{cannot convert value of type 'SwiftClass.Type' to specified type 'any AnyReference'}}
  let _: any AnyReference = getValueTypePointer()
  // expected-error@-1 {{cannot convert value of type 'UnsafeMutablePointer<ValueType>' to specified type 'any AnyReference'}}
}

// `[any AnyReference]` does not satisfy `[T]` with `T: AnyReference`:
// `any AnyReference` itself is not a single reference.
func existentialArrayDoesNotSelfConform(_ xs: [any AnyReference]) {
  takesARArray(xs)
  // expected-error@-1 {{global function 'takesARArray' requires that 'any AnyReference' be a class or foreign reference type}}
}

// `any AnyReference` cannot be converted to `AnyObject`.
func existentialToAnyObject(_ x: any AnyReference) {
  let _: AnyObject = x // expected-error {{value of type 'any AnyReference' expected to be instance of class or class-constrained type}}
  let _: any AnyObject = x // expected-error {{value of type 'any AnyReference' expected to be instance of class or class-constrained type}}
}

// FRTs still do not satisfy `AnyObject`.
func frtsAreNotAnyObject() {
  takesAO(getImmortal())
  // expected-error@-1 {{global function 'takesAO' requires that 'ImmortalRefType' be a class type}}
  takesAO(RefCountedType(1))
  // expected-error@-1 {{global function 'takesAO' requires that 'RefCountedType' be a class type}}
  let _: AnyObject = getImmortal()
  // expected-error@-1 {{value of type 'ImmortalRefType' expected to be instance of class or class-constrained type}}
}

// `T: AnyReference` does not imply `T: AnyObject`.
func arDoesNotImplyAO<T: AnyReference>(_ x: T) {
  takesAO(x)
  // expected-error@-1 {{global function 'takesAO' requires that 'T' be a class type}}
}

// Dynamic casts *to* an existential containing AnyReference are rejected:
// AnyReference is erased at runtime, so they could not be checked.
func castsTo(_ x: Any, _ frt: RefCountedType) {
  _ = x is any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as? any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as! any AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x is AnyReference // expected-error {{cannot dynamically cast to 'any AnyReference'; 'AnyReference' constraints are not checked at runtime}}
  _ = x as? any RefP & AnyReference // expected-error {{cannot dynamically cast to 'any RefP & AnyReference'; 'AnyReference' constraints are not checked at runtime}}
}

// MARK: - Joins

// Joins of an FRT and a Swift class do not infer `any AnyReference` (like
// two unrelated Swift classes do not infer `AnyObject`); an explicit type
// annotation is needed.
func joins(_ b: Bool, _ frt: RefCountedType, _ cls: SwiftClass) {
  _ = b ? frt : cls
  // expected-error@-1 {{result values in '? :' expression have mismatching types 'RefCountedType' and 'SwiftClass'}}
  let heterogeneous = [frt, cls]
  // expected-error@-1 {{heterogeneous collection literal could only be inferred to '[Any]'; add explicit type annotation if this is intentional}}
  let _: any AnyReference = b ? frt : cls
  let _: [any AnyReference] = [frt, cls]
  _ = heterogeneous
}

// MARK: - Same-type requirements

struct Holder<T: AnyReference> {}
// expected-note@-1 * {{requirement specified as 'T' : 'AnyReference'}}
extension Holder where T == RefCountedType {}
extension Holder where T == DerivedRefCountedType {}
extension Holder where T == ImmortalRefType {}
extension Holder where T == TemplatedRefTypeInt {}
extension Holder where T == ValueType {}
// expected-error@-1 {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == ValueType'}}
extension Holder where T == RefCountedType? {}
// expected-error@-1 {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == Optional<RefCountedType>'}}
extension Holder where T == UnsafeMutablePointer<ValueType> {}
// expected-error@-1 {{no type for 'T' can satisfy both 'T : AnyReference' and 'T == UnsafeMutablePointer<ValueType>'}}

func formHolders() {
  let _ = Holder<RefCountedType>()
  let _ = Holder<ImmortalRefType>()
  let _ = Holder<UnsafeRefType>()
  let _ = Holder<SwiftClass>()
  let _ = Holder<ValueType>()
  // expected-error@-1 {{'Holder' requires that 'ValueType' be a class or foreign reference type}}
}

// MARK: - Declarations

struct StructInheritsAR: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}
enum EnumInheritsAR: AnyReference {} // expected-error {{only protocols can inherit from 'AnyReference'}}

extension AnyReference {} // expected-error {{non-nominal type 'AnyReference' cannot be extended}}

struct StructConformsToRefP: RefP {}
// expected-error@-1 {{type 'StructConformsToRefP' does not conform to protocol 'RefP'}}
// expected-error@-2 {{'RefP' requires that 'StructConformsToRefP' be a class or foreign reference type}}
// expected-note@-3 {{requirement specified as 'Self' : 'AnyReference' [with Self = StructConformsToRefP]}}
