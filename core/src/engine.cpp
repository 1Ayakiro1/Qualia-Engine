// Engine implementation: worker thread + lock-free queues + pipeline.
#include "bci_engine/core.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <utility>

#ifdef BCI_HAVE_RWQ
#include <readerwriterqueue.h>
#else
#include "spsc_queue.hpp"
#endif

#include "modules.hpp"
#include "log_hook.hpp"

namespace bci {

namespace {
constexpr auto kIdleSleep = std::chrono::microseconds(200);
}  // namespace

// ---------------------------------------------------------------- context

double EngineContext::sample_rate() const { return engine_.sample_rate(); }
int EngineContext::channels() const { return engine_.channels(); }
EngineMetrics& EngineContext::metrics() { return engine_.metrics(); }
void EngineContext::log(const std::string& message) {
  engine_.core_log(message);
}

// ---------------------------------------------------------------- pimpl

struct Engine::Impl {
#ifdef BCI_HAVE_RWQ
  moodycamel::ReaderWriterQueue<BlockPtr> in_queue;
  moodycamel::ReaderWriterQueue<BlockPtr> out_queue;
#else
  internal::SpscRing<BlockPtr> in_queue;
  internal::SpscRing<BlockPtr> out_queue;
#endif

  explicit Impl(size_t capacity)
      : in_queue(capacity), out_queue(capacity) {}
};

// ---------------------------------------------------------------- lifecycle

Engine::Engine() : impl_(std::make_unique<Impl>(kQueueCapacity)) {}

Engine::~Engine() {
  if (running_.load(std::memory_order_acquire)) {
    stop();
  }
}

Status Engine::start(int sample_rate, int channels) {
  if (sample_rate <= 0 || channels <= 0) {
    set_last_error("start: sample_rate and channels must be positive");
    return Status::kInvalidArgument;
  }
  if (running_.load(std::memory_order_acquire)) {
    return Status::kAlreadyRunning;
  }

  sample_rate_ = static_cast<double>(sample_rate);
  channels_ = channels;
  sample_counter_ = 0;
  build_pipeline();

  for (auto& module : pipeline_) {
    EngineContext ctx(*this);
    module->init(ctx);
  }

  // Drop stale output from a previous run.
  BlockPtr stale;
  while (impl_->out_queue.try_dequeue(stale)) {
  }

  running_.store(true, std::memory_order_release);
  worker_ = std::thread(&Engine::worker_loop, this);
  core_log("engine started: " + std::to_string(sample_rate) + " Hz, " +
           std::to_string(channels) + " ch, " +
           std::to_string(pipeline_.size()) + " modules");
  return Status::kOk;
}

Status Engine::stop() {
  if (!running_.exchange(false, std::memory_order_acq_rel)) {
    return Status::kNotStarted;
  }
  if (worker_.joinable()) {
    worker_.join();
  }
  core_log("engine stopped");
  return Status::kOk;
}

void Engine::build_pipeline() {
  pipeline_ = create_default_pipeline(metrics_);

  module_infos_.clear();
  module_infos_.reserve(pipeline_.size());
  for (const auto& module : pipeline_) {
    module_infos_.push_back(module->info());
  }
}

// ---------------------------------------------------------------- data flow

Status Engine::push_samples(const float* interleaved, int frames,
                            int channels) {
  if (interleaved == nullptr || frames <= 0 || channels <= 0) {
    return Status::kInvalidArgument;
  }
  if (!running_.load(std::memory_order_acquire)) {
    return Status::kNotStarted;
  }
  if (channels != channels_) {
    set_last_error("push_samples: channel count mismatch");
    return Status::kInvalidArgument;
  }

  auto block = std::make_unique<Block>();
  block->data.assign(interleaved, interleaved + frames * channels);
  block->frames = frames;
  block->channels = channels;
  block->sample_rate = sample_rate_;
  block->first_sample = sample_counter_;
  sample_counter_ += static_cast<uint64_t>(frames);

  if (!impl_->in_queue.try_enqueue(std::move(block))) {
    // Latency-bounded policy: drop the oldest input block.
    BlockPtr dropped;
    if (impl_->in_queue.try_dequeue(dropped)) {
      metrics_.dropped_blocks.fetch_add(1, std::memory_order_relaxed);
    }
    if (!impl_->in_queue.try_enqueue(std::move(block))) {
      return Status::kQueueOverflow;
    }
  }
  return Status::kOk;
}

int Engine::pop_samples(float* out_interleaved, int frames, int channels) {
  if (out_interleaved == nullptr || frames <= 0 || channels <= 0) {
    return static_cast<int>(Status::kInvalidArgument);
  }
  if (channels != channels_) {
    return static_cast<int>(Status::kInvalidArgument);
  }

  int filled = 0;
  const int total = frames * channels;
  while (filled < total) {
    BlockPtr block;
    if (!impl_->out_queue.try_dequeue(block)) {
      break;
    }
    const int available = block->frames * block->channels;
    const int to_copy = std::min(available, total - filled);
    for (int i = 0; i < to_copy; ++i) {
      out_interleaved[filled + i] = block->data[i];
    }
    filled += to_copy;
    if (to_copy < available) {
      // Partial drain: rebuild the remainder and put the block back.
      auto remainder = std::make_unique<Block>();
      const int remainder_frames = available - to_copy;
      remainder->data.assign(block->data.begin() + to_copy, block->data.end());
      remainder->frames = remainder_frames / block->channels;
      remainder->channels = block->channels;
      remainder->sample_rate = block->sample_rate;
      remainder->first_sample = block->first_sample + to_copy / block->channels;
      impl_->out_queue.try_enqueue(std::move(remainder));
    }
  }
  return filled / channels;
}

void Engine::worker_loop() {
  BlockPtr block;
  while (running_.load(std::memory_order_acquire)) {
    if (!impl_->in_queue.try_dequeue(block)) {
      std::this_thread::sleep_for(kIdleSleep);
      continue;
    }

    SampleBlock view;
    view.data = block->data.data();
    view.frames = block->frames;
    view.channels = block->channels;
    view.sample_rate = block->sample_rate;
    view.first_sample = block->first_sample;

    for (auto& module : pipeline_) {
      module->process(view);
    }

    metrics_.processed_blocks.fetch_add(1, std::memory_order_relaxed);
    if (!impl_->out_queue.try_enqueue(std::move(block))) {
      metrics_.dropped_blocks.fetch_add(1, std::memory_order_relaxed);
    }
  }
}

// ---------------------------------------------------------------- misc

void Engine::set_last_error(const std::string& error) {
  std::lock_guard<std::mutex> lock(error_mutex_);
  last_error_ = error;
}

std::string Engine::last_error() const {
  std::lock_guard<std::mutex> lock(error_mutex_);
  return last_error_;
}

void Engine::core_log(const std::string& message) {
  // Lightweight logger for v0.1; quill integration is planned.
  std::fprintf(stderr, "[bci-core] %s\n", message.c_str());
  if (const auto callback = internal::g_log_callback.load(std::memory_order_acquire)) {
    callback(message.c_str());
  }
}

}  // namespace bci

