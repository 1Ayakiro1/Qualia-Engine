// Deterministic liblsl C-ABI fixture. It intentionally uses the official
// argument/return types: the old adapter signatures would fail these tests.
#include <algorithm>
#include <cstdint>
#include <cstring>

#ifdef _WIN32
#define EXPORT extern "C" __declspec(dllexport)
#else
#define EXPORT extern "C" __attribute__((visibility("default")))
#endif

EXPORT int lsl_resolve_all(void** infos, uint32_t count, double) {
  if (!infos || count < 1) return 0;
  infos[0] = new int(1);
  return 1;
}
EXPORT int lsl_resolve_byprop(void** infos, uint32_t count, const char* prop,
                             const char* value, int, double) {
  if (!value || (std::strcmp(prop, "source_id") == 0 &&
      std::strcmp(value, "fixture") != 0)) return 0;
  return lsl_resolve_all(infos, count, 0);
}
EXPORT const char* lsl_get_name(void*) { return "Fixture \"EEG\""; }
EXPORT const char* lsl_get_type(void*) { return "EEG"; }
EXPORT const char* lsl_get_source_id(void*) { return "fixture"; }
EXPORT int32_t lsl_get_channel_count(void*) { return 2; }
EXPORT double lsl_get_nominal_srate(void*) { return 250.0; }
EXPORT int32_t lsl_get_channel_format(void*) { return 1; }
EXPORT void lsl_destroy_streaminfo(void* info) { delete static_cast<int*>(info); }
EXPORT void* lsl_create_inlet(void*, int32_t, int32_t, int32_t) {
  return new int(0);
}
EXPORT void lsl_open_stream(void*, double, int32_t* error) { *error = 0; }
EXPORT void lsl_destroy_inlet(void* inlet) { delete static_cast<int*>(inlet); }
EXPORT unsigned long lsl_pull_chunk_f(void* inlet, float* data, double* stamps,
    unsigned long capacity, unsigned long stamp_capacity, double, int32_t* error) {
  *error = 0;
  auto* sequence = static_cast<int*>(inlet);
  if (!data || !stamps || stamp_capacity != capacity / 2 || capacity % 2) {
    *error = -3;
    return 0;
  }
  const auto frames = std::min(3UL, stamp_capacity);
  for (unsigned long f = 0; f < frames; ++f) {
    data[f * 2] = static_cast<float>(*sequence + f);
    data[f * 2 + 1] = -data[f * 2];
    stamps[f] = 10.0 + (*sequence + f) / 250.0;
  }
  *sequence += static_cast<int>(frames);
  return frames * 2;
}
