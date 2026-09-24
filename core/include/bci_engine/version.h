// Ayakiro BCI Engine — core version constants.
// Keep in sync with the VERSION file in the repository root and
// app/pubspec.yaml version.
#pragma once

#define BCI_CORE_VERSION_MAJOR 0
#define BCI_CORE_VERSION_MINOR 2
#define BCI_CORE_VERSION_PATCH 1
#define BCI_CORE_VERSION "0.2.1"

// Bumped whenever the C ABI of the core changes.
// v2: added bci_engine_set_log_callback.
#define BCI_CORE_ABI_VERSION 2
