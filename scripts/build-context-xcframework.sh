#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rust_root="${repo_root}/rust"
artifact_root="${repo_root}/packages/ContextCoreFFIKit/.artifacts"
xcframework_path="${artifact_root}/ContextCoreFFI.xcframework"
generated_root="${artifact_root}/generated"
headers_root="${artifact_root}/headers"
swift_output_root="${repo_root}/packages/ContextCoreFFIKit/.generated/ContextCoreFFIGenerated"
temporary_root="$(mktemp -d)"

cleanup() {
  rm -rf "${temporary_root}"
}
trap cleanup EXIT

for tool in cargo lipo xcodebuild; do
  command -v "${tool}" >/dev/null || {
    echo "required tool is unavailable: ${tool}" >&2
    exit 1
  }
done

mkdir -p "${generated_root}" "${headers_root}" "${swift_output_root}"
rm -rf "${xcframework_path}"

(
  cd "${rust_root}"
  cargo build --locked --release -p context-ffi
  cargo run --locked --release -p dayline-uniffi-bindgen -- \
    generate target/release/libcontext_ffi.dylib \
    --language swift \
    --out-dir "${generated_root}"

  IPHONEOS_DEPLOYMENT_TARGET=18.0 \
    cargo build --locked --release -p context-ffi --target aarch64-apple-ios
  IPHONEOS_DEPLOYMENT_TARGET=18.0 \
    cargo build --locked --release -p context-ffi --target aarch64-apple-ios-sim
  IPHONEOS_DEPLOYMENT_TARGET=18.0 \
    cargo build --locked --release -p context-ffi --target x86_64-apple-ios
  MACOSX_DEPLOYMENT_TARGET=15.0 \
    cargo build --locked --release -p context-ffi --target aarch64-apple-darwin
  MACOSX_DEPLOYMENT_TARGET=15.0 \
    cargo build --locked --release -p context-ffi --target x86_64-apple-darwin
)

cp "${generated_root}/context_ffiFFI.h" "${headers_root}/"
sed '/use "_Builtin_/d' \
  "${generated_root}/context_ffiFFI.modulemap" \
  >"${headers_root}/module.modulemap"
cp "${generated_root}/context_ffi.swift" "${swift_output_root}/ContextCoreFFI.swift"

lipo -create \
  "${rust_root}/target/aarch64-apple-ios-sim/release/libcontext_ffi.a" \
  "${rust_root}/target/x86_64-apple-ios/release/libcontext_ffi.a" \
  -output "${temporary_root}/libcontext_ffi-simulator.a"
lipo -create \
  "${rust_root}/target/aarch64-apple-darwin/release/libcontext_ffi.a" \
  "${rust_root}/target/x86_64-apple-darwin/release/libcontext_ffi.a" \
  -output "${temporary_root}/libcontext_ffi-macos.a"

xcodebuild -create-xcframework \
  -library "${rust_root}/target/aarch64-apple-ios/release/libcontext_ffi.a" \
  -headers "${headers_root}" \
  -library "${temporary_root}/libcontext_ffi-simulator.a" \
  -headers "${headers_root}" \
  -library "${temporary_root}/libcontext_ffi-macos.a" \
  -headers "${headers_root}" \
  -output "${xcframework_path}"

test -f "${xcframework_path}/Info.plist"
test -f "${swift_output_root}/ContextCoreFFI.swift"
if rg --quiet 'use "_Builtin_' "${xcframework_path}"; then
  echo "generated module map contains Xcode-incompatible builtin imports" >&2
  exit 1
fi
