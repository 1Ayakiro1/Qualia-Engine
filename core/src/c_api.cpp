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

bci::SampleBlock block_info(const bci_block_info* info, float* samples = nullptr) {
  bci::SampleBlock result;
  if (!info || info->struct_size != sizeof(bci_block_info) || info->reserved != 0) {
    return result;
  }
  result.data = samples;
  result.frames = info->frames;
  result.channels = info->channels;
  result.sample_rate = info->sample_rate;
  result.first_sample = info->first_sample;
  result.timestamp_ns = info->timestamp_ns;
  result.layout = static_cast<bci::SampleLayout>(info->layout);
  result.clock = static_cast<bci::SampleClock>(info->clock);
  return result;
}

bci::OwnedSampleBlock* owned(bci_block* block) {
  return reinterpret_cast<bci::OwnedSampleBlock*>(block);
}

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
  try {
    return new Engine();
  } catch (...) {
    return nullptr;
  }
}

BCI_API void bci_engine_destroy(void* engine) {
  delete as_engine(engine);
}

BCI_API int bci_engine_start(void* engine, int sample_rate, int channels) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  try {
    return to_status_code(as_engine(engine)->start(sample_rate, channels));
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API int bci_engine_stop(void* engine) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  try {
    return to_status_code(as_engine(engine)->stop());
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
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
  try {
    return to_status_code(
        as_engine(engine)->push_samples(interleaved, frames, channels));
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API bci_block* bci_block_create(const bci_block_info* info) {
  try {
    const auto view = block_info(info);
    if (!view.valid_metadata()) return nullptr;
    return reinterpret_cast<bci_block*>(new bci::OwnedSampleBlock(view));
  } catch (...) {
    return nullptr;
  }
}

BCI_API bci_block* bci_block_wrap(const bci_block_info* info, float* samples,
                                 bci_block_release_callback release, void* context) {
  try {
    const auto view = block_info(info, samples);
    if (!view.valid() || release == nullptr) return nullptr;
    return reinterpret_cast<bci_block*>(new bci::OwnedSampleBlock(view, release, context));
  } catch (...) {
    return nullptr;
  }
}

BCI_API float* bci_block_data(bci_block* block) {
  return block ? owned(block)->view().data : nullptr;
}

BCI_API int bci_block_get_info(const bci_block* block, bci_block_info* info) {
  if (!block || !info) return BCI_NULL_ARGUMENT;
  if (info->struct_size != sizeof(bci_block_info)) return BCI_INVALID_ARGUMENT;
  const auto& view = reinterpret_cast<const bci::OwnedSampleBlock*>(block)->view();
  *info = {sizeof(bci_block_info), static_cast<uint32_t>(view.layout),
           view.frames, view.channels, view.sample_rate, view.first_sample,
           view.timestamp_ns, static_cast<uint32_t>(view.clock), 0};
  return BCI_OK;
}

BCI_API void bci_block_release(bci_block* block) { delete owned(block); }

BCI_API int bci_engine_configure_queues(void* engine, uint32_t capacity,
                                       uint64_t max_bytes,
                                       uint32_t input_policy, uint32_t output_policy) {
  if (!engine) return BCI_NULL_ARGUMENT;
  if (max_bytes > SIZE_MAX) return BCI_INVALID_ARGUMENT;
  try {
    return to_status_code(as_engine(engine)->configure_queues(
        capacity, static_cast<size_t>(max_bytes),
        static_cast<bci::QueuePolicy>(input_policy),
        static_cast<bci::QueuePolicy>(output_policy)));
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API int bci_engine_push_block(void* engine, bci_block** block) {
  if (!engine || !block || !*block) return BCI_NULL_ARGUMENT;
  bci::SampleBlockPtr handle(owned(*block));
  int result;
  try {
    result = to_status_code(as_engine(engine)->push_block(handle));
  } catch (...) {
    result = BCI_INTERNAL_ERROR;
  }
  *block = reinterpret_cast<bci_block*>(handle.release());
  return result;
}

BCI_API int bci_engine_pop_block(void* engine, bci_block** block) {
  if (!engine || !block) return BCI_NULL_ARGUMENT;
  if (*block) return BCI_INVALID_ARGUMENT;
  bci::SampleBlockPtr handle;
  try {
    const auto result = as_engine(engine)->pop_block(handle);
    *block = reinterpret_cast<bci_block*>(handle.release());
    return to_status_code(result);
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API int bci_engine_pop_samples(void* engine, float* out_interleaved,
                                   int frames, int channels) {
  if (engine == nullptr) {
    return BCI_NULL_ARGUMENT;
  }
  try {
    return as_engine(engine)->pop_samples(out_interleaved, frames, channels);
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
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
