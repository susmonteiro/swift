#ifndef TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
#define TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H

#include <swift/bridging>

#pragma clang assume_nonnull begin

// Counters used by executable tests to check that retains and releases are
// balanced.
struct RefCountStats {
  static inline int retains = 0;
  static inline int releases = 0;
};

inline int getRetainCount() { return RefCountStats::retains; }
inline int getReleaseCount() { return RefCountStats::releases; }

// A foreign reference type with retain/release operations. The last release
// deletes the object.
struct RefCountedType {
  int value;
  mutable int refCount = 1;

  SWIFT_RETURNS_RETAINED
  RefCountedType(int value) : value(value) {}

  RefCountedType(const RefCountedType &) = delete;

  virtual ~RefCountedType() {}

  // Returns `this` without transferring ownership: the same object, again.
  SWIFT_RETURNS_UNRETAINED
  RefCountedType *getSelf() { return this; }
} SWIFT_SHARED_REFERENCE(retainRefCounted, releaseRefCounted);

inline void retainRefCounted(RefCountedType *obj) {
  RefCountStats::retains++;
  obj->refCount++;
}

inline void releaseRefCounted(RefCountedType *obj) {
  RefCountStats::releases++;
  if (--obj->refCount == 0)
    delete obj;
}

// The C++ address of an object, for comparison with ObjectIdentifier.
inline const void *addressOf(const RefCountedType *obj) { return obj; }

// A foreign reference type that inherits its SWIFT_SHARED_REFERENCE
// annotation from its (primary) base class.
struct DerivedRefCountedType : RefCountedType {
  SWIFT_RETURNS_RETAINED
  DerivedRefCountedType(int value) : RefCountedType(value) {}

  // Upcast in C++; the base is at offset zero, so the pointer is unchanged.
  SWIFT_RETURNS_UNRETAINED
  RefCountedType *asBase() { return this; }
};

// An immortal foreign reference type.
struct ImmortalRefType {
  int value;
} SWIFT_IMMORTAL_REFERENCE;

inline ImmortalRefType *getImmortal() {
  static ImmortalRefType instance{42};
  return &instance;
}

inline ImmortalRefType *getOtherImmortal() {
  static ImmortalRefType instance{43};
  return &instance;
}

// A plain C++ value type: not a foreign reference type.
struct ValueType {
  int value;

  ValueType(int value) : value(value) {}
};

#pragma clang assume_nonnull end

#endif // TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
