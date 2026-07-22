#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/LocalsendCore"
OUT_DIR="$ROOT_DIR/Frameworks"
XCFRAMEWORK="$OUT_DIR/LocalSendCore.xcframework"
BUILD_DIR="$OUT_DIR/LocalSendCoreBuild"
SIM_LIB="$BUILD_DIR/ios-simulator/liblocalsendcore.a"

if xcode-select -p | grep -q "CommandLineTools" && [ -d /Applications/Xcode-beta.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-17.0}"

mkdir -p "$OUT_DIR"

cargo build --manifest-path "$CRATE_DIR/Cargo.toml" --release --lib --features http --target aarch64-apple-ios
cargo build --manifest-path "$CRATE_DIR/Cargo.toml" --release --lib --features http --target aarch64-apple-ios-sim
cargo build --manifest-path "$CRATE_DIR/Cargo.toml" --release --lib --features http --target x86_64-apple-ios

rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$SIM_LIB")"
xcrun lipo -create \
    "$CRATE_DIR/target/aarch64-apple-ios-sim/release/liblocalsendcore.a" \
    "$CRATE_DIR/target/x86_64-apple-ios/release/liblocalsendcore.a" \
    -output "$SIM_LIB"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
    -library "$CRATE_DIR/target/aarch64-apple-ios/release/liblocalsendcore.a" \
    -headers "$CRATE_DIR/include" \
    -library "$SIM_LIB" \
    -headers "$CRATE_DIR/include" \
    -output "$XCFRAMEWORK"

rm -rf "$BUILD_DIR"
