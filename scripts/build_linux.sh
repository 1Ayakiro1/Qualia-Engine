#!/usr/bin/env bash
# Builds the Linux release bundle (binary + flutter libs + native core).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_flutter

# `flutter analyze` crashes when the checkout path contains non-ASCII/space
# characters (LSP framing bug in the analysis server). Builders often carry
# such paths (e.g. ".../Проекты/BCI/BCI Engine"), so static checks go through
# a pure-ASCII symlink or plain `dart analyze` — never bare `flutter analyze`.
if [[ "${ROOT_DIR}" =~ [^[:ascii:]] || "${ROOT_DIR}" == *" "* ]]; then
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
log "linux bundle готов: ${BUNDLE}"
