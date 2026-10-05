#ifndef TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
#define TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H

#include <swift/bridging>

#pragma clang assume_nonnull begin

// Counters used by executable tests to check that retains and releases are
// balanced (no leaks and no over-releases).
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

  SWIFT_RETURNS_RETAINED
  RefCountedType(int value) : value(value) { RefCountStats::live++; }

  RefCountedType(const RefCountedType &) = delete;

  virtual ~RefCountedType() { RefCountStats::live--; }

  int getRefCount() const { return refCount; }

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

// A foreign reference type that inherits its SWIFT_SHARED_REFERENCE annotation
// from its (primary) base class.
struct DerivedRefCountedType : RefCountedType {
  int secondValue;

  SWIFT_RETURNS_RETAINED
  DerivedRefCountedType(int value, int secondValue)
      : RefCountedType(value), secondValue(secondValue) {}

  // Upcast in C++; the base is at offset zero, so the pointer is unchanged.
  SWIFT_RETURNS_UNRETAINED
  RefCountedType *asBase() { return this; }
};

// A shared reference type whose annotated base is NOT at offset zero: the
// pointer to the RefCountedType subobject differs from the pointer to the
// derived object.
struct NonFRTFirstBase {
  int a = 1, b = 2, c = 3;
  virtual ~NonFRTFirstBase() {}
};

struct MultipleInheritanceRefCounted : NonFRTFirstBase, RefCountedType {
  SWIFT_RETURNS_RETAINED
  MultipleInheritanceRefCounted() : RefCountedType(7) {}

  SWIFT_RETURNS_UNRETAINED
  RefCountedType *asNonPrimaryBase() { return this; }
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

inline const ImmortalRefType *getConstImmortal() { return getImmortal(); }

// An immortal foreign reference type spelled with SWIFT_SHARED_REFERENCE.
struct ImmortalSharedSpelling {
  int value;
} SWIFT_SHARED_REFERENCE(immortal, immortal);

inline ImmortalSharedSpelling *getImmortalSharedSpelling() {
  static ImmortalSharedSpelling instance{1};
  return &instance;
}

// An unsafe foreign reference type.
struct UnsafeRefType {
  int value;
} SWIFT_UNSAFE_REFERENCE;

inline UnsafeRefType *getUnsafeRef() {
  static UnsafeRefType instance{5};
  return &instance;
}

// A class template whose specializations are foreign reference types.
template <class T>
struct SWIFT_IMMORTAL_REFERENCE TemplatedRefType {
  T value;
};

using TemplatedRefTypeInt = TemplatedRefType<int>;

inline TemplatedRefTypeInt *getTemplatedRef() {
  static TemplatedRefTypeInt instance{3};
  return &instance;
}

// A forward-declared foreign reference type (never defined in this header).
struct SWIFT_IMMORTAL_REFERENCE ForwardDeclaredRefType;

ForwardDeclaredRefType *getForwardDeclaredRef();

// Nullable returners.
SWIFT_RETURNS_RETAINED
inline RefCountedType *_Nullable maybeRefCounted(bool make) {
  return make ? new RefCountedType(9) : nullptr;
}

inline ImmortalRefType *_Nullable maybeImmortal(bool make) {
  return make ? getImmortal() : nullptr;
}

// Plain C++ value types: not foreign reference types.
struct ValueType {
  int value;

  ValueType(int value) : value(value) {}
};

inline ValueType *getValueTypePointer() {
  static ValueType instance{1};
  return &instance;
}

// A reference-counted smart pointer to a foreign reference type. The smart
// pointer itself is a C++ value type.
template <class T>
struct SWIFT_REFCOUNTED_PTR(.get) RefPtr {
  RefPtr(T *_Nonnull ptr) : ptr(ptr) { retainRefCounted(ptr); }
  RefPtr(const RefPtr &other) : ptr(other.ptr) { retainRefCounted(ptr); }
  ~RefPtr() { releaseRefCounted(ptr); }
  RefPtr &operator=(const RefPtr &) = delete;

  T *_Nonnull get() const { return ptr; }

private:
  T *_Nonnull ptr;
};

using RefCountedTypePtr = RefPtr<RefCountedType>;

#pragma clang assume_nonnull end

#endif // TEST_INTEROP_CXX_FOREIGN_REFERENCE_INPUTS_ANY_REFERENCE_H
