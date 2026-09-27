#!/usr/bin/env bash
# Starts the release Linux application and its independent debug terminal.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT_DIR}/app/build/linux/x64/release/bundle/bci_engine"

if [ ! -x "${APP}" ]; then
  echo "Release bundle not found. Build it first with:"
  echo "  PATH=/home/ayakiro/.local/opt/flutter/bin:\$PATH ./scripts/build_linux.sh"
  exit 1
fi

exec "${APP}" --with-debug-terminal "$@"
