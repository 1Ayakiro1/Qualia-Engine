// Stable C ABI implementation. Thin wrappers around bci::Engine.
#include "bci_engine/c_api.h"

#include <atomic>
#include <algorithm>
#include <cmath>
#include <mutex>
#include <new>
#include <string>

#include "bci_engine/core.hpp"
#include "bci_engine/stft.hpp"
#include "bci_engine/lsl_hal.hpp"
#include "log_hook.hpp"
#include "modules.hpp"

using bci::Engine;
using bci::ModuleCategory;
using Status = bci::Status;

struct bci_lsl {
  std::unique_ptr<bci::hal::LslInlet> inlet;
};

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

void write_json(char* output, int output_bytes, const std::string& value) {
  if (!output || output_bytes <= 0) return;
  const size_t count = std::min(value.size(), static_cast<size_t>(output_bytes - 1));
  std::copy_n(value.data(), count, output);
  output[count] = '\0';
}

std::string lsl_stream_json(const bci::hal::LslStreamInfo& stream) {
  return "{\"name\":\"" + json_escape(stream.name) +
         "\",\"type\":\"" + json_escape(stream.type) +
         "\",\"sourceId\":\"" + json_escape(stream.source_id) +
         "\",\"channels\":" + std::to_string(stream.channels) +
         ",\"nominalRate\":" + std::to_string(stream.nominal_srate) +
         ",\"channelFormat\":\"" + json_escape(stream.channel_format) + "\"}";
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

BCI_API int bci_lsl_available(void) {
  return bci::hal::LslInlet::available() ? 1 : 0;
}

BCI_API int bci_lsl_discover_json(const char* type, char* output,
                                  int output_bytes) {
  if (!output || output_bytes <= 0) return BCI_NULL_ARGUMENT;
  try {
    const auto streams = bci::hal::LslInlet::discover(type ? type : "");
    std::string json = "[";
    for (size_t i = 0; i < streams.size(); ++i) {
      if (i) json += ',';
      json += lsl_stream_json(streams[i]);
    }
    json += ']';
    if (json.size() >= static_cast<size_t>(output_bytes)) {
      output[0] = '\0';
      return BCI_QUEUE_OVERFLOW;
    }
    write_json(output, output_bytes, json);
    return static_cast<int>(streams.size());
  } catch (...) {
    write_json(output, output_bytes, "[]");
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API bci_lsl* bci_lsl_create(void) {
  try {
    auto result = std::make_unique<bci_lsl>();
    result->inlet = std::make_unique<bci::hal::LslInlet>();
    return result.release();
  } catch (...) {
    return nullptr;
  }
}

BCI_API void bci_lsl_destroy(bci_lsl* inlet) { delete inlet; }

BCI_API int bci_lsl_open_source(bci_lsl* inlet, const char* source_id,
                                double timeout_seconds) {
  if (!inlet || !inlet->inlet || !source_id) {
    return BCI_NULL_ARGUMENT;
  }
  if (!*source_id || !std::isfinite(timeout_seconds) || timeout_seconds < 0 ||
      timeout_seconds > 30) return BCI_INVALID_ARGUMENT;
  try {
    const auto streams = bci::hal::LslInlet::discover();
    for (const auto& stream : streams) {
      if (stream.source_id == source_id) {
        return inlet->inlet->open(stream, timeout_seconds) ? BCI_OK
                                                            : BCI_INTERNAL_ERROR;
      }
    }
    return BCI_QUEUE_EMPTY;
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
}

BCI_API void bci_lsl_close(bci_lsl* inlet) {
  if (inlet && inlet->inlet) inlet->inlet->close();
}

BCI_API int bci_lsl_pull(bci_lsl* inlet, float* destination, int max_samples,
                         double timeout_seconds, int* channels,
                         double* timestamp_seconds) {
  if (!inlet || !inlet->inlet || !destination || !channels ||
      !timestamp_seconds) {
    return BCI_NULL_ARGUMENT;
  }
  if (max_samples <= 0 || max_samples > 1048576 ||
      !std::isfinite(timeout_seconds) || timeout_seconds < 0 ||
      timeout_seconds > 30) return BCI_INVALID_ARGUMENT;
  try {
    return inlet->inlet->pull(destination, max_samples, timeout_seconds, channels,
                              timestamp_seconds);
  } catch (...) { return BCI_INTERNAL_ERROR; }
}

BCI_API const char* bci_lsl_info_json(bci_lsl* inlet) {
  static thread_local std::string json;
  if (!inlet || !inlet->inlet || !inlet->inlet->opened()) {
    json = "{}";
    return json.c_str();
  }
  json = lsl_stream_json(inlet->inlet->info());
  return json.c_str();
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

BCI_API int bci_stft_compute(const float* samples, uint32_t sample_count,
                             const bci_stft_config* config, float* output,
                             uint32_t max_rows, uint32_t output_values) {
  if (!samples || !config || !output || sample_count == 0 || max_rows == 0 ||
      output_values == 0) {
    return BCI_NULL_ARGUMENT;
  }
  try {
    bci::Stft stft({config->window_size, config->hop_size,
                    config->sample_rate});
    if (!stft.valid()) return BCI_INVALID_ARGUMENT;
    const size_t bins = config->window_size / 2 + 1;
    const size_t rows_capacity =
        std::min<size_t>(max_rows, output_values / bins);
    if (rows_capacity == 0) return BCI_INVALID_ARGUMENT;
    auto rows = stft.push(samples, sample_count);
    const size_t count = std::min(rows_capacity, rows.size());
    for (size_t row = 0; row < count; ++row) {
      std::copy(rows[row].begin(), rows[row].end(), output + row * bins);
    }
    return static_cast<int>(count);
  } catch (...) {
    return BCI_INTERNAL_ERROR;
  }
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
