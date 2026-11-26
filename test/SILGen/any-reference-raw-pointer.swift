// RUN: %target-swift-frontend -enable-experimental-feature AnyReference -enable-experimental-feature NondeinitableTypes -enable-builtin-module -emit-silgen -sil-verify-all -Xllvm -sil-print-types %s | %FileCheck %s
// RUN: %target-swift-frontend -enable-experimental-feature AnyReference -enable-experimental-feature NondeinitableTypes -enable-builtin-module -emit-sil -sil-verify-all -Xllvm -sil-print-types %s | %FileCheck %s --check-prefix=CANON
// RUN: %target-swift-frontend -enable-experimental-feature AnyReference -enable-experimental-feature NondeinitableTypes -enable-builtin-module -enable-sil-opaque-values -emit-silgen -sil-verify-all -Xllvm -sil-print-types %s | %FileCheck %s --check-prefix=OPAQUE

// REQUIRES: swift_feature_AnyReference
// REQUIRES: swift_feature_NondeinitableTypes

import Builtin

// Bridging a '_AnyReference' value to a raw pointer reads the pointer in
// place, without copying or destroying the value.

// CHECK-LABEL: sil hidden [ossa] @$s{{.*}}6borrow
// CHECK: [[ADDRESS:%.*]] = unchecked_addr_cast {{%.*}} : $*{{.*}} to $*Builtin.RawPointer
// CHECK-NEXT: [[POINTER:%.*]] = load [trivial] [[ADDRESS]]
// CHECK: return [[POINTER]]
// CANON-LABEL: sil hidden{{.*}} @$s{{.*}}6borrow
// CANON-NOT: copy_addr
// CANON-NOT: destroy_addr
// CANON: return
// OPAQUE-LABEL: sil hidden [ossa] [opaque] @$s{{.*}}6borrow
// OPAQUE: unchecked_trivial_bit_cast {{%.*}} : $T to $Builtin.RawPointer
func borrow<T: _AnyReference & ~Copyable & ~Deinitable>(
  _ value: borrowing T
) -> Builtin.RawPointer {
  Builtin.bridgeToRawPointer(value)
}
