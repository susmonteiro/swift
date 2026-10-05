// RUN: %target-swift-ide-test -print-module -module-to-print=AnyReferenceFRTs -I %S%{fs-sep}Inputs -source-filename=x -cxx-interoperability-mode=default -enable-experimental-feature AnyReference | %FileCheck %s
// RUN: %target-swift-ide-test -print-module -module-to-print=AnyReferenceFRTs -I %S%{fs-sep}Inputs -source-filename=x -cxx-interoperability-mode=default -enable-experimental-feature AnyReference | %FileCheck %s --check-prefix=NO-AR

// REQUIRES: swift_feature_AnyReference

// Foreign reference types satisfy `AnyReference` without any synthesized
// conformance, so the imported module interface is unchanged.

// NO-AR-NOT: AnyReference

// CHECK: class RefCountedType {
// CHECK: func getSelf() -> RefCountedType
// CHECK: }
// CHECK: class DerivedRefCountedType : RefCountedType {
// CHECK: func asBase() -> RefCountedType
// CHECK: }
// CHECK: struct NonFRTFirstBase {
// CHECK: class MultipleInheritanceRefCounted {
// CHECK: func asNonPrimaryBase() -> RefCountedType
// CHECK: }
// CHECK: class ImmortalRefType {
// CHECK: func getImmortal() -> ImmortalRefType
// CHECK: func getConstImmortal() -> ImmortalRefType
// CHECK: class ImmortalSharedSpelling {
// CHECK: @unsafe class UnsafeRefType {
// CHECK: class TemplatedRefType<CInt> {
// CHECK: class ForwardDeclaredRefType {
// CHECK: func maybeRefCounted(_ make: CBool) -> RefCountedType?
// CHECK: func maybeImmortal(_ make: CBool) -> ImmortalRefType?
// CHECK: struct ValueType {
// CHECK: func getValueTypePointer() -> UnsafeMutablePointer<ValueType>
// CHECK: @_refCountedPtr struct RefPtr<RefCountedType> {

