#!/usr/bin/env bash
# Static analysis of the Flutter app.
#
# NOTE: `flutter analyze` crashes on checkout paths containing non-ASCII
# characters or spaces (e.g. ".../Проекты/BCI/BCI Engine"): the analysis
# server fails to frame the LSP messages and exits with code 255
# ("Unexpected end of input"). `dart analyze` uses the same analyzer without
# the LSP framing, so it works on any path. Always use this script (or plain
# `dart analyze`) instead of `flutter analyze`.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_flutter
cd "${ROOT_DIR}/app"
dart analyze "$@"
