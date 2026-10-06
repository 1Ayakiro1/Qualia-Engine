#!/usr/bin/env bash
# Pinned Flutter GTK embedder, with native frame-clock vsync. SDK stays untouched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
ensure_flutter

REVISION=af7e796e161ae0bb1ff0758c71a7105418bd9ded
MODE="${1:-release}"
[[ "$MODE" == release || "$MODE" == profile || "$MODE" == debug ]] || die "неизвестный режим: $MODE"
SDK="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
[[ "$(cat "$SDK/bin/cache/engine.stamp")" == "$REVISION" ]] || die "native vsync требует engine $REVISION; обновите и протестируйте патч для нового SDK"
CACHE="${QUALIA_ENGINE_CACHE:-${HOME}/.cache/qualia-native-vsync}"
SRC="$CACHE/engine/src"
OUT="$SRC/out/qualia_${MODE}"
mkdir -p "$CACHE"
exec 9>"$CACHE/.build.lock"
flock 9

if [[ ! -d "$CACHE/depot_tools/.git" ]]; then
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$CACHE/depot_tools"
fi
export PATH="$CACHE/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0
if [[ ! -f "$CACHE/depot_tools/python3_bin_reldir.txt" ]]; then
  source "$CACHE/depot_tools/bootstrap_python3"
  bootstrap_python3
fi
if [[ ! -d "$CACHE/.git" ]]; then
  git init "$CACHE"
  git -C "$CACHE" remote add origin https://github.com/flutter/flutter.git
  git -C "$CACHE" fetch --depth 1 origin "$REVISION"
  git -C "$CACHE" switch --detach FETCH_HEAD
fi
[[ "$(git -C "$CACHE" rev-parse HEAD)" == "$REVISION" ]] || die "несовместимая версия исходников в $CACHE"

if [[ ! -f "$CACHE/.qualia-prepared-$REVISION" ]]; then
  cp "$ROOT_DIR/native/linux_vsync/gclient.config" "$CACHE/.gclient"
  # The official monorepo gclient solution is ".": engine sources and their
  # dependencies share the checkout root, retaining Git revision metadata.
  (cd "$CACHE" && gclient sync --no-history --shallow --nohooks -j "${QUALIA_SYNC_JOBS:-6}")
  (cd "$CACHE" && gclient runhooks)
  touch "$CACHE/.qualia-prepared-$REVISION"
fi
python3 "$ROOT_DIR/native/linux_vsync/apply_engine_patch.py" "$SRC/flutter"
"$SRC/flutter/tools/gn" --runtime-mode "$MODE" --target-dir "qualia_${MODE}" \
  --no-goma --no-rbe --no-lto --no-enable-unittests \
  --no-build-glfw-shell --no-build-embedder-examples
ninja -C "$OUT" -j "${QUALIA_ENGINE_JOBS:-4}" flutter/shell/platform/linux:flutter_linux_gtk
[[ -f "$OUT/libflutter_linux_gtk.so" ]] || die "custom embedder не собран"
strings "$OUT/libflutter_linux_gtk.so" | grep 'Qualia native vsync: enabled' >/dev/null || die "vsync отсутствует в библиотеке"
log "native GTK embedder: $OUT/libflutter_linux_gtk.so"
