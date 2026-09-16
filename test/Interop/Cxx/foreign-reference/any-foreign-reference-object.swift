// RUN: %target-typecheck-verify-swift -I %S/Inputs -cxx-interoperability-mode=default

// Imported C++ foreign reference types should implicitly conform to the
// standard library's 'AnyForeignReferenceObject' protocol, so that generic
// code can be constrained to foreign reference types. C++ value types should
// not conform.

import AnyForeignReferenceObject

func takesFRT<T: AnyForeignReferenceObject>(_ x: T) {
    // let value = ObjectIdentifier(x)
}
// note@-1 {{where 'T' = 'ValueType'}}

func takesAnyObject<T: AnyObject>(_ x: T) {
    let value = ObjectIdentifier(x)
}

func takesExistentialFRT(_: any AnyForeignReferenceObject) {}

// MARK: Foreign reference types conform

struct MySwiftStruct: AnyForeignReferenceObject { var number: Int }
class MySwiftClass: AnyForeignReferenceObject { 
    var number: Int
    init(number: Int) { self.number = number }
}

// let s1 = MySwiftStruct(number: 10)
let c1 = MySwiftClass(number: 10)
// takesFRT(s1)
// takesFRT(c1)
// takesAnyObject(s1)
takesAnyObject(c1)

// takesFRT(RefCountedType(1))
// takesFRT(DerivedRefCountedType(1, 2))
// takesFRT(getImmortalRefCountedType())

// takesExistentialFRT(RefCountedType(1))
// takesExistentialFRT(DerivedRefCountedType(1, 2))
// takesExistentialFRT(getImmortalRefCountedType())

// let frts: [any AnyForeignReferenceObject] = [
//   RefCountedType(1),
//   DerivedRefCountedType(1, 2),
//   getImmortalRefCountedType(),
// ]

// MARK: C++ value types do not conform

// takesFRT(ValueType(1))
// error@-1 {{global function 'takesFRT' requires that 'ValueType' conform to 'AnyForeignReferenceObject'}}

// takesExistentialFRT(ValueType(1))
// error@-1 {{argument type 'ValueType' does not conform to expected type 'AnyForeignReferenceObject'}}

// expected-warning* {{was never used}}
