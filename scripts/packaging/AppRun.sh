#!/bin/sh
# AppRun for the Ayakiro BCI Engine AppImage.
HERE="$(dirname "$(readlink -f "$0")")"

export LD_LIBRARY_PATH="${HERE}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export BCI_OFFLINE=1

exec "${HERE}/bci_engine" "$@"
