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

# Also keep a ready-to-run raw binary bundle beside the packages.
# (bci_engine + lib/ + data/ — no unpacking needed for the user).
BIN_DIR="${DIST_OUT}/binary"
if [ -e "${BIN_DIR}" ]; then
  # Re-running a standalone packaging step must not accumulate backup bundles.
  python3 - "${BIN_DIR}" <<'PY'
import pathlib
import shutil
import sys
path = pathlib.Path(sys.argv[1])
if path.is_symlink() or not (path / 'bci_engine').is_file():
    raise SystemExit(f'Refusing to replace an unrecognized bundle: {path}')
shutil.rmtree(path)
PY
fi
mkdir -p "${BIN_DIR}"
cp -a "${BUNDLE}/." "${BIN_DIR}/"
log "тарбол: ${DIST_OUT}/${APP_NAME}-${VERSION}-linux-x64.tar.gz"
log "бинарник: ${BIN_DIR}/bci_engine"
