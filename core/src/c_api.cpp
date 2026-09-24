// Stable C ABI implementation. Thin wrappers around bci::Engine.
#include "bci_engine/c_api.h"

#include <atomic>
#include <mutex>
#include <new>
#include <string>

#include "bci_engine/core.hpp"
#include "log_hook.hpp"
#include "modules.hpp"

using bci::Engine;
using bci::ModuleCategory;
using Status = bci::Status;

namespace {

int to_status_code(Status status) { return static_cast<int>(status); }

Engine* as_engine(void* handle) { return static_cast<Engine*>(handle); }

std::string json_escape(const std::string& input) {
  std::string out;
  out.reserve(input.size() + 8);
  for (const char c : input) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          out += ' ';
        } else {
          out += c;
        }
    }
  }
  return out;
}

}  // namespace

extern "C" {

BCI_API int bci_engine_abi_version(void) {
  return static_cast<int>(bci::kAbiVersion);
}

BCI_API const char* bci_engine_core_version(void) {
  static const char* kVersion = BCI_CORE_VERSION;
  return kVersion;
}

BCI_API void* bci_engine_create(void) {
  auto* engine = new (std::nothrow) Engine();
  return engine;
}

BCI_API void bci_engine_destroy(void* engine) {
  delete as_engine(engine);
}

BCI_API int bci_engine_start(void* engine, int sample_rate, int channels) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return to_status_code(as_engine(engine)->start(sample_rate, channels));
}

BCI_API int bci_engine_stop(void* engine) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return to_status_code(as_engine(engine)->stop());
}

BCI_API int bci_engine_is_running(void* engine) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return as_engine(engine)->running() ? 1 : 0;
}

BCI_API int bci_engine_push_samples(void* engine, const float* interleaved,
                                    int frames, int channels) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return to_status_code(
      as_engine(engine)->push_samples(interleaved, frames, channels));
}

BCI_API int bci_engine_pop_samples(void* engine, float* out_interleaved,
                                   int frames, int channels) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return as_engine(engine)->pop_samples(out_interleaved, frames, channels);
}

BCI_API int bci_engine_get_metrics(void* engine, float* out4) {
  if (engine == nullptr || out4 == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  const auto& metrics = as_engine(engine)->metrics();
  out4[0] = metrics.rms.load(std::memory_order_relaxed);
  out4[1] = metrics.peak_freq.load(std::memory_order_relaxed);
  out4[2] = metrics.quality.load(std::memory_order_relaxed);
  out4[3] = 0.0f;  // reserved
  return BCI_OK;
}

BCI_API int bci_engine_module_count(void* engine) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  return static_cast<int>(as_engine(engine)->module_infos().size());
}

BCI_API const char* bci_engine_module_json(void* engine, int index) {
  if (engine == nullptr) {
    return "{}";
  }
  const auto& infos = as_engine(engine)->module_infos();
  if (index < 0 || index >= static_cast<int>(infos.size())) {
    return "{}";
  }
  const bci::ModuleInfo& info = infos[static_cast<size_t>(index)];

  static std::string json;
  static std::mutex json_mutex;
  std::lock_guard<std::mutex> lock(json_mutex);
  json = "{\"id\":\"" + json_escape(info.id) +
         "\",\"name\":\"" + json_escape(info.name) +
         "\",\"category\":\"" + bci::module_category_name(info.category) +
         "\",\"description\":\"" + json_escape(info.description) +
         "\",\"version\":\"" + json_escape(info.version) +
         "\",\"enabled\":" + (info.enabled ? "true" : "false") + "}";
  return json.c_str();
}

BCI_API const char* bci_engine_last_error(void* engine) {
  static std::string empty;
  if (engine == nullptr) {
    empty.clear();
    return empty.c_str();
  }
  static std::string error;
  static std::mutex error_mutex;
  std::lock_guard<std::mutex> lock(error_mutex);
  error = as_engine(engine)->last_error();
  return error.c_str();
}

BCI_API void bci_engine_set_log_callback(bci_log_callback callback) {
  bci::internal::g_log_callback.store(callback, std::memory_order_release);
}

}  // extern "C"

namespace bci {
namespace internal {

std::atomic<LogCallback> g_log_callback{nullptr};

}  // namespace internal
}  // namespace bci
