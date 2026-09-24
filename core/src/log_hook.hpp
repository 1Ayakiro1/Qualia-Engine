// Forwarding of core log messages to an external sink (e.g. the Dart logger).
#pragma once

#include <atomic>

namespace bci {
namespace internal {

using LogCallback = void (*)(const char* message);

// Set from the C API (bci_engine_set_log_callback); may be null.
extern std::atomic<LogCallback> g_log_callback;

}  // namespace internal
}  // namespace bci
