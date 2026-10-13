#!/usr/bin/env bash
# Builds the Linux release bundle (binary + flutter libs + native core).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_flutter

# A stock Linux embedder is capped at fallback 60 Hz. Build our ABI-compatible
# pinned GTK library before packaging; never silently ship the stock fallback.
if [[ "${QUALIA_LINUX_EMBEDDER:-native}" == native ]]; then
  bash "${ROOT_DIR}/scripts/build_native_embedder.sh" release
elif [[ "${QUALIA_LINUX_EMBEDDER}" == stock ]]; then
  warn "explicit stock GTK build: native vsync patch is NOT included"
else
  die "QUALIA_LINUX_EMBEDDER must be native or stock"
fi

# `flutter analyze` crashes when the checkout path contains non-ASCII/space
# characters (LSP framing bug in the analysis server). Builders often carry
# such paths (e.g. ".../Проекты/BCI/BCI Engine"), so static checks go through
# a pure-ASCII symlink or plain `dart analyze` — never bare `flutter analyze`.
# Note: bash `[[ =~ ]]` has no [[:ascii:]] class — probe bytes with grep -C locale.
if [[ "${ROOT_DIR}" == *" "* ]] ||
  printf '%s' "${ROOT_DIR}" | LC_ALL=C grep -q '[^ -~]'; then
  LINK="/tmp/bci-engine-build"
  warn "путь содержит не-ASCII/пробелы — анализ через симлинк ${LINK}"
  ln -sfn "${ROOT_DIR}" "${LINK}"
  (cd "${LINK}/app" && dart analyze)
else
  (cd "${ROOT_DIR}/app" && dart analyze)
fi

cd "${ROOT_DIR}/app"
flutter build linux --release "$@"
BUNDLE="${ROOT_DIR}/app/build/linux/x64/release/bundle"
[ -f "${BUNDLE}/bci_engine" ] || die "бинарник не найден после сборки"
[ -f "${BUNDLE}/lib/libbci_engine_core.so" ] || die "libbci_engine_core.so не в бандле"
if [[ "${QUALIA_LINUX_EMBEDDER:-native}" == native ]]; then
  NATIVE_ENGINE="${QUALIA_ENGINE_CACHE:-${HOME}/.cache/qualia-native-vsync}/engine/src/out/qualia_release/libflutter_linux_gtk.so"
  cp "${NATIVE_ENGINE}" "${BUNDLE}/lib/libflutter_linux_gtk.so"
fi
log "linux bundle готов: ${BUNDLE}"
