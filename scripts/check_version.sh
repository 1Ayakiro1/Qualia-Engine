#!/usr/bin/env bash
# Verifies that VERSION, version.h and pubspec.yaml agree.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FILE_VERSION="$(cat "${ROOT_DIR}/VERSION")"
H_VERSION="$(grep -oP '(?<=#define BCI_CORE_VERSION ")[^"]+' \
  "${ROOT_DIR}/core/include/bci_engine/version.h")"
PUBSPEC_VERSION="$(grep -oP '(?<=^version: )\d+\.\d+\.\d+' \
  "${ROOT_DIR}/app/pubspec.yaml")"

if [ "${FILE_VERSION}" != "${H_VERSION}" ] || [ "${FILE_VERSION}" != "${PUBSPEC_VERSION}" ]; then
  die "версии не совпадают: VERSION=${FILE_VERSION}, version.h=${H_VERSION}, pubspec=${PUBSPEC_VERSION}"
fi

# The numeric macros must compose into the same string (catches a bumped
# BCI_CORE_VERSION with forgotten MAJOR/MINOR/PATCH edits).
MAJOR="$(grep -oP '(?<=#define BCI_CORE_VERSION_MAJOR )\d+' \
  "${ROOT_DIR}/core/include/bci_engine/version.h")"
MINOR="$(grep -oP '(?<=#define BCI_CORE_VERSION_MINOR )\d+' \
  "${ROOT_DIR}/core/include/bci_engine/version.h")"
PATCH="$(grep -oP '(?<=#define BCI_CORE_VERSION_PATCH )\d+' \
  "${ROOT_DIR}/core/include/bci_engine/version.h")"
if [ "${FILE_VERSION}" != "${MAJOR}.${MINOR}.${PATCH}" ]; then
  die "макросы version.h дают ${MAJOR}.${MINOR}.${PATCH}, а VERSION=${FILE_VERSION}"
fi

log "версии согласованы: ${FILE_VERSION}"
