#!/bin/sh
# AppRun for the Ayakiro BCI Engine AppImage.
HERE="$(dirname "$(readlink -f "$0")")"

# Core + bundled flutter libraries live in ./lib.
export LD_LIBRARY_PATH="${HERE}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Make the engine fully offline/self-contained (no cloud calls by default).
export BCI_OFFLINE=1

exec "${HERE}/bci_engine" "$@"
