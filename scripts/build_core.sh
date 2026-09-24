#!/usr/bin/env bash
# Builds the C++ core standalone and runs its tests (Catch2).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

cd "${ROOT_DIR}/core"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBCI_BUILD_TESTS=ON
cmake --build build -j "$(nproc)"
ctest --test-dir build --output-on-failure
log "ядро собрано и протестировано"
