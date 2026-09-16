#include <swift/bridging>

// A foreign reference type with ordinary retain/release operations.
struct RefCountedType {
  int value;
  mutable int refCount = 1;

  SWIFT_RETURNS_RETAINED
  RefCountedType(int value) : value(value) {}

  void retainMe() const { refCount++; }
  void releaseMe() const { refCount--; }
} SWIFT_SHARED_REFERENCE(.retainMe, .releaseMe);

// A foreign reference type that inherits its SWIFT_SHARED_REFERENCE annotation.
struct DerivedRefCountedType : RefCountedType {
  int secondValue;

  SWIFT_RETURNS_RETAINED
  DerivedRefCountedType(int value, int secondValue)
      : RefCountedType(value), secondValue(secondValue) {}
};

// An immortal foreign reference type.
struct ImmortalRefCountedType {
  int value;
} SWIFT_SHARED_REFERENCE(immortal, immortal);

inline ImmortalRefCountedType *_Nonnull getImmortalRefCountedType() {
  static ImmortalRefCountedType instance{42};
  return &instance;
}

// A plain C++ value type: not a foreign reference type.
struct ValueType {
  int value;

  ValueType(int value) : value(value) {}
};
