// Ayakiro BCI Engine — core version constants.
// Keep in sync with the VERSION file in the repository root and
// app/pubspec.yaml version.
#pragma once

#define BCI_CORE_VERSION_MAJOR 0
#define BCI_CORE_VERSION_MINOR 5
#define BCI_CORE_VERSION_PATCH 2
#define BCI_CORE_VERSION "0.5.2-dev.4"

// Bumped whenever the C ABI of the core changes.
// v2: added bci_engine_set_log_callback.
// v3: owned timestamped float32 blocks and bounded queue policies (additive).
#define BCI_CORE_ABI_VERSION 3
