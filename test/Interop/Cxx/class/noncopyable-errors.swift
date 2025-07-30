// RUN: rm -rf %t
// RUN: split-file %s %t
// RUN: not %target-swift-frontend -typecheck -I %t/Inputs  %t/test.swift  -enable-experimental-cxx-interop -diagnostic-style llvm 2>&1 | %FileCheck %s

//--- Inputs/module.modulemap
module Test {
    header "noncopyable.h"
    requires cplusplus
}

//--- Inputs/noncopyable.h
// #include <vector>

// struct Copyable() {
//     Copyable() = default;
//     Copyable(int i) : element(i) {}

//     int element = 1;
// };

// TODO check the tests I wrote for a type with no copy and no move constructors

struct NonCopyable {
  NonCopyable() = default;
  NonCopyable(int i) : element(i) {}

  NonCopyable(const NonCopyable &) = delete;
  NonCopyable &operator=(const NonCopyable &) = delete;

//   NonCopyable(NonCopyable &&) = default;
//   NonCopyable &operator=(NonCopyable &&) = default;

//   ~NonCopyable() {}

  int element = 2;
};

// struct TrivialNonCopyable {
//   NonCopyable() = default;
//   NonCopyable(int i) : element(i) {}

//   NonCopyable(const NonCopyable &) = delete;
//   NonCopyable &operator=(const NonCopyable &) = delete;

//   NonCopyable(NonCopyable &&) = default;
//   NonCopyable &operator=(NonCopyable &&) = default;

//   int element = 3;
// };

// struct ViewOfNonCopyable {
//     View() : element() {}
//     View(NonCopyable *nCop) : element(nCop) {}
//     View(const View&) = default;

//     NonCopyable *element;
// };

// struct NonCopyableView {
//     View() : element() {}
//     View(Copyable *cop) : element(cop) {}

//     View(const View &) = delete;

//     Copyable *element;
// };

// template<typename T>
// struct CopyableIf {
//     T element;
// };

// template<typename T>
// struct Outer {
//     struct NonTemplated {
//         template <typename S>
//         struct Inner {
//             T t;
//             S s;
//         };
//     };
// };

// using CopyableOfCopyable = CopyableIf<Copyable>;
// using NonCopyableOfNonCopyable = CopyableIf<NonCopyable>;

//--- test.swift
import Test

public func f() {
    let c = 2
    c = 3 
    // CHECK: error: cannot assign to value: 'c' is a 'let' constant

    let nCop = NonCopyable()
    // CHECK: error
}

