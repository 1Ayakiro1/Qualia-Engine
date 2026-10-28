#!/usr/bin/env bash
# Common helpers for BCI Engine build scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
APP_NAME="Qualia-Engine"
DIST_OUT="${DIST_OUT:-${ROOT_DIR}/builds/${VERSION}}"

log() { printf '\033[1;34m[bci]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bci]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[bci]\033[0m %s\n' "$*" >&2; exit 1; }

ensure_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    if [ -x "${HOME}/development/flutter/bin/flutter" ]; then
      export PATH="${HOME}/development/flutter/bin:${PATH}"
    else
      die "flutter не найден в PATH (и ~/development/flutter не существует)"
    fi
  fi
}

mkdir_dist_out() {
  mkdir -p "${DIST_OUT}"
}
