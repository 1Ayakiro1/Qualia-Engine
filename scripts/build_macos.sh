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

STAGING="$(mktemp -d "${ROOT_DIR}/.build-staging-XXXXXX")"
trap 'rm -rf "${STAGING}"' EXIT
OUT="${STAGING}/${APP_NAME}-${VERSION}-macos.zip"
ditto -c -k --keepParent "${APP}" "${OUT}"
python3 "${ROOT_DIR}/scripts/publish_build.py" --source "${STAGING}" \
  --output "${DIST_OUT}" --platform macos
log "macOS zip: ${DIST_OUT}/$(basename "${OUT}")"
