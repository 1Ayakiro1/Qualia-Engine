// Ayakiro BCI Engine — stable C ABI exported from libbci_engine_core.
//
// The Dart side (app/lib/core/native/engine_bindings.dart) loads this library
// through dart:ffi. This ABI is kept intentionally small and POD-only.
#pragma once

#include <stdint.h>

#if defined(_WIN32) && defined(BCI_BUILD_CORE_DLL)
#define BCI_API __declspec(dllexport)
#elif defined(_WIN32)
#define BCI_API __declspec(dllimport)
#else
#define BCI_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Result codes shared with the Dart side.
#define BCI_OK 0
#define BCI_NULL_ARGUMENT (-1)
#define BCI_NOT_STARTED (-2)
#define BCI_ALREADY_RUNNING (-3)
#define BCI_INVALID_ARGUMENT (-4)
#define BCI_QUEUE_OVERFLOW (-5)
#define BCI_INTERNAL_ERROR (-6)

// Returns BCI_CORE_ABI_VERSION.
BCI_API int bci_engine_abi_version(void);

// Returns the core semantic version string ("0.1.0"). Valid for the whole
// process lifetime.
BCI_API const char* bci_engine_core_version(void);

// Creates an engine instance (opaque). Returns NULL on failure.
BCI_API void* bci_engine_create(void);

// Destroys an engine instance. Passing NULL is allowed.
BCI_API void bci_engine_destroy(void* engine);

// Starts the processing worker. sample_rate > 0, channels > 0.
BCI_API int bci_engine_start(void* engine, int sample_rate, int channels);

// Stops the worker. Pending input is discarded, output can still be drained.
BCI_API int bci_engine_stop(void* engine);

// Returns 1 when the worker is running, 0 otherwise, negative on error.
BCI_API int bci_engine_is_running(void* engine);

// Pushes an interleaved block of samples into the engine (non-blocking).
// Returns BCI_OK or a negative error code. Overfull queue drops the oldest
// data to keep latency bounded (see bci_engine_get_metrics).
BCI_API int bci_engine_push_samples(void* engine, const float* interleaved,
                                    int frames, int channels);

// Pops processed samples into out_interleaved. Returns the number of frames
// actually popped (>= 0) or a negative error code.
BCI_API int bci_engine_pop_samples(void* engine, float* out_interleaved,
                                   int frames, int channels);

// Fills out4 with { rms, peak_freq_hz, quality_0_to_1, reserved }.
// Returns BCI_OK or a negative error code.
BCI_API int bci_engine_get_metrics(void* engine, float* out4);

// Number of registered system modules.
BCI_API int bci_engine_module_count(void* engine);

// Returns a JSON descriptor for module `index`:
// {"id","name","category","description","version","enabled"}
// The pointer stays valid until the next call on this engine.
BCI_API const char* bci_engine_module_json(void* engine, int index);

// Signature of the core log callback: receives one UTF-8 line per call.
typedef void (*bci_log_callback)(const char* message);

// Installs (or removes, with NULL) a global log callback. The callback may be
// invoked from the engine worker thread; keep it fast and non-blocking.
BCI_API void bci_engine_set_log_callback(bci_log_callback callback);

// Last human-readable error for this engine ("" when none).
BCI_API const char* bci_engine_last_error(void* engine);

#ifdef __cplusplus
}  // extern "C"
#endif
