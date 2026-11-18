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
#define BCI_QUEUE_EMPTY (-7)

// Returns BCI_CORE_ABI_VERSION.
BCI_API int bci_engine_abi_version(void);

// Returns the core semantic version string ("0.5.2-dev.4"). Valid for the whole
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

// Copies an interleaved block of samples into the engine (does not wait for
// capacity; uses a short admission mutex, not a hard-real-time guarantee).
// Returns BCI_OK or a negative error code. Overfull queue drops the oldest
// data by default; configure_queues can explicitly select another policy.
BCI_API int bci_engine_push_samples(void* engine, const float* interleaved,
                                    int frames, int channels);

// ABI v3 additive API. These functions do not change the legacy samples ABI.
// Float32 samples, uniform spacing within each block; timestamp_ns = frame 0.
#define BCI_LAYOUT_INTERLEAVED 0u
#define BCI_LAYOUT_CHANNEL_MAJOR 1u
#define BCI_CLOCK_UNKNOWN 0u
#define BCI_CLOCK_MONOTONIC 1u
#define BCI_CLOCK_UNIX 2u
#define BCI_QUEUE_EVERY 0u
#define BCI_QUEUE_DROP_OLDEST 1u
#define BCI_QUEUE_LATEST_ONLY 2u

typedef struct bci_block_info {
  uint32_t struct_size;  // MUST equal sizeof(bci_block_info); reserved = 0.
  uint32_t layout;
  int32_t frames;
  int32_t channels;
  double sample_rate;
  uint64_t first_sample;
  int64_t timestamp_ns;
  uint32_t clock;
  uint32_t reserved;
} bci_block_info;

typedef struct bci_block bci_block;
typedef void (*bci_block_release_callback)(float* samples, void* context);

// Allocate a block, or adopt an EXCLUSIVE mutable external lease without copy.
// Dimensions are bounded to 256 MiB/block; invalid metadata returns NULL.
// wrap requires exactly frames*channels float32 values at samples. On failure
// ownership stays with caller and release is NOT invoked. The caller must not
// access a successfully wrapped allocation until its release callback fires.
// Callback fires once on discard/release/destruction, possibly on the worker;
// it must not throw, block, or call back into this engine.
BCI_API bci_block* bci_block_create(const bci_block_info* info);
BCI_API bci_block* bci_block_wrap(const bci_block_info* info, float* samples,
                                 bci_block_release_callback release, void* context);
BCI_API float* bci_block_data(bci_block* block);
BCI_API int bci_block_get_info(const bci_block* block, bci_block_info* info);
BCI_API void bci_block_release(bci_block* block);

// Configure input/output queues while stopped (also discards stale output).
// capacity 1..4096; each queue has a max_bytes budget 1..2 GiB.
// every: push returns OVERFLOW, ownership retained, caller retries; worker waits
// for output credits. drop-oldest: discard oldest queued blocks to admit newest.
// latest-only: keep only newest QUEUED block; a block in flight is not canceled.
// No policy silently converts every to a lossy mode. stop wakes blocked worker.
// Queue admission uses a short mutex; not a hard-real-time/lock-free guarantee.
BCI_API int bci_engine_configure_queues(void* engine, uint32_t capacity,
                                       uint64_t max_bytes,
                                       uint32_t input_policy, uint32_t output_policy);

// Push moves ownership and sets *block=NULL only on OK; on refusal unchanged.
// Engine rate/channels must match. Blocks move through the in-place native
// pipeline without copying; this does NOT claim cross-process SHM transport.
BCI_API int bci_engine_push_block(void* engine, bci_block** block);

// Pop moves an entire processed block out of the engine. *block must be NULL.
// Returns QUEUE_EMPTY if none available. Do not mix with a partially drained
// legacy pop_samples block (INVALID_ARGUMENT). Caller eventually releases it.
BCI_API int bci_engine_pop_block(void* engine, bci_block** block);

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

// Native STFT helper. Computes up to max_rows Hann-windowed magnitude rows for
// a mono float32 input. Output is row-major with window_size/2 + 1 bins per
// row. Returns the number of rows, or a negative status code on invalid input.
typedef struct bci_stft_config {
  uint32_t window_size;
  uint32_t hop_size;
  double sample_rate;
} bci_stft_config;

BCI_API int bci_stft_compute(const float* samples, uint32_t sample_count,
                             const bci_stft_config* config, float* output,
                             uint32_t max_rows, uint32_t output_values);

#ifdef __cplusplus
}  // extern "C"
#endif
