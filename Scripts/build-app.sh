#!/bin/sh
set -eu

APP_NAME="MicGate"
BUNDLE_ID="dev.local.MicGate"
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/Build/Release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

mkdir -p "$BUILD_DIR"

xcrun swiftc \
  -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -framework CoreAudio \
  -framework ServiceManagement \
  -framework UserNotifications \
  "$ROOT_DIR"/Source/Application/*.swift \
  "$ROOT_DIR"/Source/Features/*.swift \
  "$ROOT_DIR"/Source/Features/HotKey/*.swift \
  "$ROOT_DIR"/Source/Services/*.swift \
  -o "$EXECUTABLE"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

sed \
  -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
  -e "s/\$(PRODUCT_NAME)/$APP_NAME/g" \
  "$ROOT_DIR/Info.plist" > "$CONTENTS_DIR/Info.plist"

if [ -d "$ROOT_DIR/Resources" ]; then
  cp -R "$ROOT_DIR/Resources"/. "$RESOURCES_DIR/"
fi

printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=4 "$APP_DIR"

echo "$APP_DIR"
