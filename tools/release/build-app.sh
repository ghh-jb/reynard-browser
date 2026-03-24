#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT_PATH="$ROOT_DIR/browser/Reynard.xcodeproj"
XCCONFIG_PATH="$ROOT_DIR/browser/Configuration/Reynard.xcconfig"

cd "$ROOT_DIR"

"$ROOT_DIR/tools/development/build-gecko.sh"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

BUILD_SHA=$(git -C "$ROOT_DIR" rev-parse --short HEAD)
GECKO_VERSION=$(tr -d '\000\r' < "$ROOT_DIR/engine/release.txt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
sed -i '' "s/CURRENT_BUILD = .*/CURRENT_BUILD = $BUILD_SHA/" "$DIST_DIR/Reynard.xcconfig"
sed -i '' "s/GECKO_VERSION = .*/GECKO_VERSION = $GECKO_VERSION/" "$DIST_DIR/Reynard.xcconfig"

xcodebuild clean -scheme "Reynard" -project "$PROJECT_PATH" -sdk iphoneos -arch arm64 -configuration Release

xcodebuild archive -scheme "Reynard" -archivePath "$DIST_DIR/Reynard.xcarchive" -project "$PROJECT_PATH" -sdk iphoneos -arch arm64 -configuration Release -xcconfig "$DIST_DIR/Reynard.xcconfig"
