#!/usr/bin/env bash
# Full local build for Linux: core tests -> app bundle -> tar.gz -> AppImage.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Assemble all formats outside builds first. Never publish a partial build.
FINAL_OUT="${DIST_OUT}"
STAGING="$(mktemp -d "${ROOT_DIR}/.build-staging-XXXXXX")"
trap 'rm -rf "${STAGING}"' EXIT
export DIST_OUT="${STAGING}"
"${ROOT_DIR}/scripts/build_core.sh"
"${ROOT_DIR}/scripts/build_linux.sh"
"${ROOT_DIR}/scripts/package_linux.sh"
"${ROOT_DIR}/scripts/build_appimage.sh"
python3 "${ROOT_DIR}/scripts/publish_build.py" --source "${STAGING}" \
  --output "${FINAL_OUT}" --platform linux
log "единственная актуальная сборка в ${FINAL_OUT}:"
ls -lh "${FINAL_OUT}"
