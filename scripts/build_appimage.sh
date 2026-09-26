#!/usr/bin/env bash
# Builds a portable Linux AppImage (type 2) via appimagetool.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BUNDLE="${ROOT_DIR}/app/build/linux/x64/release/bundle"
[ -d "${BUNDLE}" ] || die "bundle не найден — сначала scripts/build_linux.sh"

ARCH="${ARCH:-x86_64}"
APPDIR="${ROOT_DIR}/build/appimage/AppDir"
mkdir_dist_out
rm -rf "${ROOT_DIR}/build/appimage"
mkdir -p "${APPDIR}"

# Bundle already contains: bci_engine, lib/, data/.
cp -a "${BUNDLE}/." "${APPDIR}/"
sed "s/@VERSION@/${VERSION}/g" \
  "${ROOT_DIR}/scripts/packaging/bci-engine.desktop" \
  > "${APPDIR}/bci-engine.desktop"
cp "${ROOT_DIR}/app/assets/icons/bci_engine_256.png" "${APPDIR}/bci_engine.png"
ln -sf bci_engine.png "${APPDIR}/.DirIcon"
cp "${ROOT_DIR}/scripts/packaging/AppRun.sh" "${APPDIR}/AppRun"
chmod +x "${APPDIR}/AppRun"

# Locate (or download) appimagetool.
APPIMAGETOOL="$(command -v appimagetool || true)"
TOOL="${ROOT_DIR}/tools/appimagetool-${ARCH}.AppImage"
if [ -z "${APPIMAGETOOL}" ]; then
  if [ ! -f "${TOOL}" ]; then
    log "скачиваю appimagetool..."
    mkdir -p "${ROOT_DIR}/tools"
    curl -fsSL -o "${TOOL}" \
      "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  fi
  chmod +x "${TOOL}"
  APPIMAGETOOL="${TOOL}"
fi

EXTRACT_RUN=""
if "${APPIMAGETOOL}" --appimage-extract-and-run --help >/dev/null 2>&1; then
  EXTRACT_RUN="--appimage-extract-and-run"
fi

OUT="${DIST_OUT}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
log "собираю AppImage..."
"${APPIMAGETOOL}" ${EXTRACT_RUN} "${APPDIR}" "${OUT}"
log "AppImage готов: ${OUT}"
