#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/FlycutPackageDerivedData}"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/Flycut.app"
HELPER_APP_PATH="${APP_PATH}/Contents/Library/LoginItems/FlycutHelper.app"

sign_if_present() {
  local target_path="$1"
  local deep_flag="${2:-}"

  if [[ -e "${target_path}" ]]; then
    if [[ -n "${deep_flag}" ]]; then
      codesign --force --deep --sign - "${target_path}"
    else
      codesign --force --sign - "${target_path}"
    fi
  fi
}

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild \
  -project "${ROOT_DIR}/Flycut.xcodeproj" \
  -scheme Flycut \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -destination "generic/platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build

sign_if_present "${HELPER_APP_PATH}"
sign_if_present "${APP_PATH}" "deep"

rm -rf "${DIST_DIR}/Flycut.app"
mkdir -p "${DIST_DIR}"
ditto "${APP_PATH}" "${DIST_DIR}/Flycut.app"

lipo -info "${DIST_DIR}/Flycut.app/Contents/MacOS/Flycut"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${DIST_DIR}/Flycut.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${DIST_DIR}/Flycut.app/Contents/Info.plist"
