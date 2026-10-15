#ifndef TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
#define TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H

#include <swift/bridging>

#pragma clang assume_nonnull begin

// Counters used by executable tests to check that retains and releases are
// balanced.
struct RefCountStats {
  static inline int live = 0;
  static inline int retains = 0;
  static inline int releases = 0;
};

inline int getLiveObjects() { return RefCountStats::live; }
inline int getRetainCount() { return RefCountStats::retains; }
inline int getReleaseCount() { return RefCountStats::releases; }
inline void resetRefCountStats() {
  RefCountStats::retains = 0;
  RefCountStats::releases = 0;
}

// A foreign reference type with ordinary retain/release operations. The last
// release deletes the object, so an over-release is a use-after-free.
struct RefCountedType {
  int value;
  mutable int refCount = 1;

  SWIFT_RETURNS_RETAINED RefCountedType(int value) : value(value) { RefCountStats::live++; }

  RefCountedType(const RefCountedType &) = delete;

  virtual ~RefCountedType() { RefCountStats::live--; }

  int getRefCount() const { return refCount; }

  // Returns `this` without transferring ownership: the same object, again.
  SWIFT_RETURNS_UNRETAINED RefCountedType *getSelf() { return this; }
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

#pragma clang assume_nonnull end

#endif // TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
