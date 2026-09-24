#!/usr/bin/env bash
# Packages the Linux bundle into a portable .tar.gz.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BUNDLE="${ROOT_DIR}/app/build/linux/x64/release/bundle"
[ -d "${BUNDLE}" ] || die "bundle не найден — сначала scripts/build_linux.sh"

mkdir_dist_out
STAGE="${DIST_OUT}/stage/${APP_NAME}-${VERSION}"
rm -rf "${DIST_OUT}/stage"
mkdir -p "${STAGE}"
cp -a "${BUNDLE}/." "${STAGE}/"
tar -C "${DIST_OUT}/stage" -czf \
  "${DIST_OUT}/${APP_NAME}-${VERSION}-linux-x64.tar.gz" \
  "$(basename "${STAGE}")"
rm -rf "${DIST_OUT}/stage"

# Also keep a ready-to-run raw binary bundle right in builds/binary/
# (bci_engine + lib/ + data/ — no unpacking needed for the user).
BIN_DIR="${DIST_OUT}/binary"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"
cp -a "${BUNDLE}/." "${BIN_DIR}/"
log "тарбол: ${DIST_OUT}/${APP_NAME}-${VERSION}-linux-x64.tar.gz"
log "бинарник: ${BIN_DIR}/bci_engine"
