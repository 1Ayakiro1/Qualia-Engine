#!/usr/bin/env bash
# Full local build for Linux: core tests -> app bundle -> tar.gz -> AppImage.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

"${ROOT_DIR}/scripts/build_core.sh"
"${ROOT_DIR}/scripts/build_linux.sh"
"${ROOT_DIR}/scripts/package_linux.sh"
"${ROOT_DIR}/scripts/build_appimage.sh"
log "все артефакты в ${DIST_OUT}:"
ls -lh "${DIST_OUT}"
