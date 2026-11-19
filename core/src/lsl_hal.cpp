#include "bci_engine/lsl_hal.hpp"

#include <algorithm>
#include <cmath>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace bci::hal {
namespace {
using StreamInfo = void*;
using Inlet = void*;
using Resolve = int (*)(StreamInfo*, int, const char*, const char*, int, double);
using ResolveAll = int (*)(StreamInfo*, unsigned, double);
using InfoString = const char* (*)(StreamInfo);
using InfoInt = int (*)(StreamInfo);
using InfoDouble = double (*)(StreamInfo);
using OpenInlet = Inlet (*)(StreamInfo, int, int, int);
using OpenStream = void (*)(Inlet, double, int*);
using CloseInlet = void (*)(Inlet);
using PullFloat = unsigned long (*)(Inlet, float*, double*, unsigned long,
                                    unsigned long, double, int*);
using DestroyInfo = void (*)(StreamInfo);

#ifdef _WIN32
using Library = HMODULE;
Library open_library(const char* name) { return LoadLibraryA(name); }
void close_library(Library library) { FreeLibrary(library); }
void* symbol(Library library, const char* name) {
  return reinterpret_cast<void*>(GetProcAddress(library, name));
}
#else
using Library = void*;
Library open_library(const char* name) { return dlopen(name, RTLD_LAZY | RTLD_LOCAL); }
void close_library(Library library) { dlclose(library); }
void* symbol(Library library, const char* name) { return dlsym(library, name); }
#endif
}  // namespace

struct LslInlet::Api {
  Library library = nullptr;
  Resolve resolve = nullptr;
  ResolveAll resolve_all = nullptr;
  InfoString name = nullptr;
  InfoString type = nullptr;
  InfoString source_id = nullptr;
  InfoInt channels = nullptr;
  InfoDouble nominal_srate = nullptr;
  InfoInt channel_format = nullptr;
  OpenInlet open = nullptr;
  OpenStream open_stream = nullptr;
  CloseInlet close = nullptr;
  PullFloat pull = nullptr;
  DestroyInfo destroy_info = nullptr;

  ~Api() {
    if (library != nullptr) close_library(library);
  }

  static std::unique_ptr<Api> load() {
    auto api = std::make_unique<Api>();
#ifdef _WIN32
    const char* names[] = {"lsl.dll", "liblsl.dll"};
#else
    const char* names[] = {"liblsl.so", "liblsl.so.1", "liblsl.dylib"};
#endif
    for (const char* name : names) {
      api->library = open_library(name);
      if (api->library != nullptr) break;
    }
    if (api->library == nullptr) return nullptr;
#define LSL_SYMBOL(field, type, name) \
    api->field = reinterpret_cast<type>(symbol(api->library, name)); \
    if (api->field == nullptr) return nullptr
    LSL_SYMBOL(resolve, Resolve, "lsl_resolve_byprop");
    LSL_SYMBOL(resolve_all, ResolveAll, "lsl_resolve_all");
    LSL_SYMBOL(name, InfoString, "lsl_get_name");
    LSL_SYMBOL(type, InfoString, "lsl_get_type");
    LSL_SYMBOL(source_id, InfoString, "lsl_get_source_id");
    LSL_SYMBOL(channels, InfoInt, "lsl_get_channel_count");
    LSL_SYMBOL(nominal_srate, InfoDouble, "lsl_get_nominal_srate");
    LSL_SYMBOL(channel_format, InfoInt, "lsl_get_channel_format");
    LSL_SYMBOL(open, OpenInlet, "lsl_create_inlet");
    LSL_SYMBOL(open_stream, OpenStream, "lsl_open_stream");
    LSL_SYMBOL(close, CloseInlet, "lsl_destroy_inlet");
    LSL_SYMBOL(pull, PullFloat, "lsl_pull_chunk_f");
    LSL_SYMBOL(destroy_info, DestroyInfo, "lsl_destroy_streaminfo");
#undef LSL_SYMBOL
    return api;
  }
};

LslInlet::LslInlet() : api_(Api::load()) {}
LslInlet::~LslInlet() { close(); }

bool LslInlet::available() { return Api::load() != nullptr; }

std::vector<LslStreamInfo> LslInlet::discover(const std::string& type) {
  std::vector<LslStreamInfo> result;
  auto api = Api::load();
  if (!api) return result;
  StreamInfo infos[16] = {};
  const int count = type.empty() ? api->resolve_all(infos, 16, 1.0)
      : api->resolve(infos, 16, "type", type.c_str(), 1, 1.0);
  if (count <= 0) return result;
  for (int i = 0; i < std::min(count, 16); ++i) {
    if (!infos[i]) continue;
    result.push_back({api->name(infos[i]), api->type(infos[i]),
                      api->source_id(infos[i]), api->channels(infos[i]),
                      api->nominal_srate(infos[i]),
                      std::to_string(api->channel_format(infos[i]))});
    api->destroy_info(infos[i]);
  }
  return result;
}

bool LslInlet::open(const LslStreamInfo& stream, double timeout_seconds) {
  close();
  if (!api_ || stream.source_id.empty() || stream.channels <= 0 ||
      stream.channels > 256 || !std::isfinite(stream.nominal_srate) ||
      stream.nominal_srate <= 0 || !std::isfinite(timeout_seconds) ||
      timeout_seconds < 0) return false;
  StreamInfo infos[1] = {};
  const int count = api_->resolve(infos, 1, "source_id", stream.source_id.c_str(),
                                  1, timeout_seconds);
  if (count <= 0 || !infos[0]) return false;
  // Resolve again may find a restarted outlet. Trust the actual inlet format,
  // not stale discovery metadata (especially for destination buffer sizing).
  const int actual_channels = api_->channels(infos[0]);
  const double actual_rate = api_->nominal_srate(infos[0]);
  if (actual_channels != stream.channels || actual_rate != stream.nominal_srate) {
    api_->destroy_info(infos[0]);
    return false;
  }
  int error = 0;
  inlet_ = api_->open(infos[0], 32, 0, 1);
  info_ = stream;
  api_->destroy_info(infos[0]);
  if (!inlet_) return false;
  api_->open_stream(inlet_, timeout_seconds, &error);
  if (error != 0) close();
  return inlet_ != nullptr;
}

void LslInlet::close() {
  if (inlet_ && api_) api_->close(inlet_);
  inlet_ = nullptr;
}

int LslInlet::pull(float* destination, int max_samples, double timeout_seconds,
                   int* channels, double* timestamp_seconds) {
  if (!inlet_ || !api_ || !destination || max_samples <= 0 || !channels ||
      !timestamp_seconds || info_.channels <= 0 ||
      !std::isfinite(timeout_seconds) || timeout_seconds < 0) return 0;
  const int max_values = std::min(
      max_samples, max_samples / info_.channels * info_.channels);
  if (max_values == 0) return 0;
  std::vector<double> timestamps(max_values / info_.channels);
  int error = 0;
  const auto elements = api_->pull(inlet_, destination, timestamps.data(),
      max_values, timestamps.size(), timeout_seconds, &error);
  if (error != 0) return BCI_INTERNAL_ERROR;
  if (elements == 0) return 0;
  if (elements > static_cast<unsigned long>(max_values) ||
      elements % info_.channels != 0) return BCI_INVALID_ARGUMENT;
  *timestamp_seconds = timestamps.front();
  *channels = info_.channels;
  return static_cast<int>(elements / info_.channels);
}

}  // namespace bci::hal
