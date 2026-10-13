#!/usr/bin/env bash
# Called by the Runner Xcode target: also works with flutter build/run macos.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
command -v cmake >/dev/null || { echo "Install CMake (brew install cmake) to build the native core." >&2; exit 1; }
ARCHITECTURES="${ARCHS:-$(uname -m)}"
if [[ "${ONLY_ACTIVE_ARCH:-NO}" == YES ]]; then
  ARCHITECTURES="${NATIVE_ARCH_ACTUAL:-$(uname -m)}"
fi
ARCHITECTURES="${ARCHITECTURES// /;}"
CONFIG=Release
[[ "${CONFIGURATION:-Release}" != Debug ]] || CONFIG=Debug
BUILD="${PROJECT_TEMP_DIR:?Xcode PROJECT_TEMP_DIR is required}/qualia-core-${CONFIG}"
DEST="${TARGET_BUILD_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}"
cmake -S "${ROOT}/core" -B "${BUILD}" \
  -DCMAKE_BUILD_TYPE="${CONFIG}" -DBCI_BUILD_TESTS=OFF -DBCI_FETCH_DEPS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="${ARCHITECTURES}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
cmake --build "${BUILD}" --config "${CONFIG}" --parallel 2
mkdir -p "${DEST}"
cp -L "${BUILD}/libbci_engine_core.dylib" "${DEST}/libbci_engine_core.dylib"
install_name_tool -id '@rpath/libbci_engine_core.dylib' "${DEST}/libbci_engine_core.dylib"
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "${DEST}/libbci_engine_core.dylib"
fi
