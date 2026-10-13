#!/usr/bin/env bash
# Builds the macOS app bundle + zip (run on macOS).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_flutter
cd "${ROOT_DIR}/app"
flutter build macos --release "$@"

APP="${ROOT_DIR}/app/build/macos/Build/Products/Release/bci_engine.app"
[ -d "${APP}" ] || die "app bundle не найден после сборки"
[ -f "${APP}/Contents/Frameworks/libbci_engine_core.dylib" ] || die "native core не включён в app bundle"
codesign --verify --deep --strict "${APP}"

mkdir_dist_out
OUT="${DIST_OUT}/${APP_NAME}-${VERSION}-macos.zip"
ditto -c -k --keepParent "${APP}" "${OUT}"
log "macOS zip: ${OUT}"
