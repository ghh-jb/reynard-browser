#!/bin/sh

set -eu

GECKO_DIST_BIN="${GECKO_DIST}/bin"
APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FRAMEWORKS_DIR="${APP_BUNDLE}/Frameworks"
GECKOVIEW_FW="${FRAMEWORKS_DIR}/GeckoView.framework"
GECKOVIEW_FW_FRAMEWORKS="${GECKOVIEW_FW}/Frameworks"
SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${EXPANDED_CODE_SIGN_IDENTITY_NAME:-Apple Development}}"
DEFAULT_THEME_SRC="${SRCROOT}/../engine/firefox/toolkit/mozapps/extensions/default-theme"

mkdir -p "${FRAMEWORKS_DIR}"

cp -fL "${GECKO_DIST_BIN}/"*.dylib "${FRAMEWORKS_DIR}/"
cp -fL "${GECKO_DIST_BIN}/plugin-container" "${FRAMEWORKS_DIR}/"

for lib in "${FRAMEWORKS_DIR}/XUL" "${FRAMEWORKS_DIR}/plugin-container" "${FRAMEWORKS_DIR}/"*.dylib; do
	if [ -f "${lib}" ]; then
		codesign --force --sign "${SIGN_IDENTITY}" "${lib}"
	fi
done

mkdir -p "${GECKOVIEW_FW_FRAMEWORKS}"

cp -fL "${GECKO_DIST_BIN}/XUL" "${GECKOVIEW_FW}/XUL"
codesign --force --sign "${SIGN_IDENTITY}" "${GECKOVIEW_FW}/XUL"

cp -fL "${GECKO_DIST_BIN}/plugin-container" "${GECKOVIEW_FW_FRAMEWORKS}/"
codesign --force --sign "${SIGN_IDENTITY}" "${GECKOVIEW_FW_FRAMEWORKS}/plugin-container"

for resource in greprefs.js application.ini platform.ini chrome.manifest dependentlibs.list; do
	cp -fL "${GECKO_DIST_BIN}/${resource}" "${GECKOVIEW_FW_FRAMEWORKS}/"
done

for directory in chrome defaults res components modules actors localization contentaccessible hyphenation dictionaries; do
	cp -RfL "${GECKO_DIST_BIN}/${directory}" "${GECKOVIEW_FW_FRAMEWORKS}/"
done

mkdir -p "${GECKOVIEW_FW_FRAMEWORKS}/default-theme"
cp -RfL "${DEFAULT_THEME_SRC}/" "${GECKOVIEW_FW_FRAMEWORKS}/default-theme/"
echo "resource default-theme file:default-theme/" >> "${GECKOVIEW_FW_FRAMEWORKS}/chrome.manifest"

codesign --force --sign "${SIGN_IDENTITY}" "${GECKOVIEW_FW}"
