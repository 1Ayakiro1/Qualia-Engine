#!/usr/bin/env bash
# Packages the Linux bundle into a portable .tar.gz.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BUNDLE="${ROOT_DIR}/app/build/linux/x64/release/bundle"
[ -d "${BUNDLE}" ] || die "bundle не найден — сначала scripts/build_linux.sh"

mkdir_dist_out
STAGING_ROOT="$(mktemp -d "${DIST_OUT}/.package-XXXXXX")"
trap 'rm -rf "${STAGING_ROOT}"' EXIT
STAGE="${STAGING_ROOT}/${APP_NAME}-${VERSION}"
mkdir -p "${STAGE}"
cp -a "${BUNDLE}/." "${STAGE}/"
tar -C "${STAGING_ROOT}" -czf \
  "${DIST_OUT}/${APP_NAME}-${VERSION}-linux-x64.tar.gz" \
  "$(basename "${STAGE}")"

# Also keep a ready-to-run raw binary bundle right in builds/binary/
# (bci_engine + lib/ + data/ — no unpacking needed for the user).
BIN_DIR="${DIST_OUT}/binary"
if [ -e "${BIN_DIR}" ]; then
  mv "${BIN_DIR}" "${DIST_OUT}/binary-previous-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "${BIN_DIR}"
cp -a "${BUNDLE}/." "${BIN_DIR}/"
log "тарбол: ${DIST_OUT}/${APP_NAME}-${VERSION}-linux-x64.tar.gz"
log "бинарник: ${BIN_DIR}/bci_engine"
