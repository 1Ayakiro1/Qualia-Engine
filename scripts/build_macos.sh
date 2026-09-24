#!/usr/bin/env bash
# Builds the macOS app bundle + zip (run on macOS).
# Note: the C++ core is not yet wired into the Xcode build; the app runs with
# the core offline until the macOS integration lands (see docs/BUILD.md).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_flutter
cd "${ROOT_DIR}/app"
flutter build macos --release

APP="${ROOT_DIR}/app/build/macos/Build/Products/Release/bci_engine.app"
[ -d "${APP}" ] || die "app bundle не найден после сборки"

mkdir_dist_out
OUT="${DIST_OUT}/${APP_NAME}-${VERSION}-macos.zip"
ditto -c -k --keepParent "${APP}" "${OUT}"
log "macOS zip: ${OUT}"
