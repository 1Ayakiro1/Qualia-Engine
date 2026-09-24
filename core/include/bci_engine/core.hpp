// Ayakiro BCI Engine — public C++ API of the core.
#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "bci_engine/version.h"

namespace bci {

class IModule;

constexpr int kAbiVersion = BCI_CORE_ABI_VERSION;

// Result codes (mirror of the C ABI values).
enum class Status : int {
  kOk = 0,
  kNullArgument = -1,
  kNotStarted = -2,
  kAlreadyRunning = -3,
  kInvalidArgument = -4,
  kQueueOverflow = -5,
  kInternalError = -6,
};

// A view over an interleaved sample buffer: data[frame * channels + channel].
struct SampleBlock {
  float* data = nullptr;
  int frames = 0;
  int channels = 0;
  double sample_rate = 0.0;
  uint64_t first_sample = 0;
};

// Module categories (kept as int in ModuleInfo for the C ABI).
enum class ModuleCategory : int {
  kAcquisition = 0,
  kDsp = 1,
  kFeature = 2,
  kInference = 3,
  kOutput = 4,
  kUtility = 5,
};

struct ModuleInfo {
  std::string id;
  std::string name;
  std::string description;
  std::string version;
  int category = static_cast<int>(ModuleCategory::kUtility);
  bool enabled = true;
};

// Live metrics produced by the pipeline (thread-safe).
struct EngineMetrics {
  std::atomic<float> rms{0.0f};         // RMS of the latest processed block
  std::atomic<float> peak_freq{0.0f};   // dominant spectral frequency (Hz)
  std::atomic<float> quality{0.0f};     // heuristic signal quality 0..1
  std::atomic<uint64_t> processed_blocks{0};
  std::atomic<uint64_t> dropped_blocks{0};
};

class Engine;

// View of engine services handed to modules. Never stored by modules.
class EngineContext {
 public:
  explicit EngineContext(Engine& engine) : engine_(engine) {}

  double sample_rate() const;
  int channels() const;
  EngineMetrics& metrics();
  void log(const std::string& message);

 private:
  Engine& engine_;
};

// Real-time engine: owns the worker thread, the lock-free queues and the
// processing pipeline (list of system modules).
class Engine {
 public:
  Engine();
  ~Engine();

  Engine(const Engine&) = delete;
  Engine& operator=(const Engine&) = delete;

  Status start(int sample_rate, int channels);
  Status stop();

  bool running() const { return running_.load(std::memory_order_acquire); }

  // Producer side (called from the Dart/UI thread).
  Status push_samples(const float* interleaved, int frames, int channels);

  // Consumer side (called from the Dart/UI thread).
  int pop_samples(float* out_interleaved, int frames, int channels);

  const std::vector<ModuleInfo>& module_infos() const { return module_infos_; }
  EngineMetrics& metrics() { return metrics_; }
  double sample_rate() const { return sample_rate_; }
  int channels() const { return channels_; }

  void set_last_error(const std::string& error);
  std::string last_error() const;

  // --- internal (used via EngineContext) ---
  void core_log(const std::string& message);

 private:
  struct Block {
    std::vector<float> data;
    int frames = 0;
    int channels = 0;
    double sample_rate = 0.0;
    uint64_t first_sample = 0;
  };
  using BlockPtr = std::unique_ptr<Block>;

  void worker_loop();
  void build_pipeline();

  static constexpr size_t kQueueCapacity = 512;  // blocks per queue

  struct Impl;

  std::unique_ptr<Impl> impl_;
  std::vector<std::unique_ptr<IModule>> pipeline_;

  std::vector<ModuleInfo> module_infos_;
  EngineMetrics metrics_;

  double sample_rate_ = 0.0;
  int channels_ = 0;
  uint64_t sample_counter_ = 0;

  std::atomic<bool> running_{false};
  std::thread worker_;

  mutable std::mutex error_mutex_;
  std::string last_error_;
};

}  // namespace bci
