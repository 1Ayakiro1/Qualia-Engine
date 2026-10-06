#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
CACHE="${QUALIA_ENGINE_CACHE:-${HOME}/.cache/qualia-native-vsync}"
OUT="${QUALIA_VSYNC_TEST_OUT:-/tmp/opencode/qualia-native-vsync-tests}"
mkdir -p "$OUT"
g++ -std=c++17 -Wall -Wextra -Werror -I "$ROOT_DIR/native/linux_vsync" \
  "$ROOT_DIR/native/linux_vsync/frame_time_test.cc" -o "$OUT/frame_time_test"
"$OUT/frame_time_test"
g++ -std=c++17 -Wall -Wextra -Werror -pthread \
  -I "$ROOT_DIR/native/linux_vsync" -I "$CACHE/engine/src" \
  "$ROOT_DIR/native/linux_vsync/fl_native_vsync.cc" \
  "$ROOT_DIR/native/linux_vsync/bridge_test.cc" \
  $(pkg-config --cflags --libs gtk+-3.0) -o "$OUT/bridge_test"
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a "$OUT/bridge_test"
else
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || die "bridge-тест требует display или xvfb-run"
  "$OUT/bridge_test"
fi
