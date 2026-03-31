#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/FlycutPackageDerivedData}"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/Flycut.app"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild \
  -project "${ROOT_DIR}/Flycut.xcodeproj" \
  -scheme Flycut \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -destination "generic/platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "${DIST_DIR}/Flycut.app"
mkdir -p "${DIST_DIR}"
ditto "${APP_PATH}" "${DIST_DIR}/Flycut.app"

lipo -info "${DIST_DIR}/Flycut.app/Contents/MacOS/Flycut"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${DIST_DIR}/Flycut.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${DIST_DIR}/Flycut.app/Contents/Info.plist"
