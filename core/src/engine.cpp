// Engine implementation: worker thread + bounded ownership queues + pipeline.
#include "bci_engine/core.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <utility>

#include "block_queue.hpp"

#include "modules.hpp"
#include "log_hook.hpp"

namespace bci {

// ---------------------------------------------------------------- context

double EngineContext::sample_rate() const { return engine_.sample_rate(); }
int EngineContext::channels() const { return engine_.channels(); }
EngineMetrics& EngineContext::metrics() { return engine_.metrics(); }
void EngineContext::log(const std::string& message) {
  engine_.core_log(message);
}

// ---------------------------------------------------------------- pimpl

struct Engine::Impl {
  internal::BlockQueue in_queue;
  internal::BlockQueue out_queue;
};

// ---------------------------------------------------------------- lifecycle

Engine::Engine() : impl_(std::make_unique<Impl>()) {}

Engine::~Engine() {
  stop();
}

Status Engine::start(int sample_rate, int channels) {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (sample_rate <= 0 || channels <= 0) {
    set_last_error("start: sample_rate and channels must be positive");
    return Status::kInvalidArgument;
  }
  if (running_.load(std::memory_order_acquire)) {
    return Status::kAlreadyRunning;
  }
  if (worker_.joinable()) worker_.join();

  sample_rate_ = static_cast<double>(sample_rate);
  channels_ = channels;
  sample_counter_ = 0;
  build_pipeline();

  for (auto& module : pipeline_) {
    EngineContext ctx(*this);
    module->init(ctx);
  }

  draining_.reset();
  drain_offset_ = 0;
  impl_->in_queue.open();
  impl_->out_queue.open();

  running_.store(true, std::memory_order_release);
  try {
    worker_ = std::thread(&Engine::worker_loop, this);
  } catch (...) {
    running_.store(false, std::memory_order_release);
    impl_->in_queue.close(true);
    impl_->out_queue.close(true);
    throw;
  }
  core_log("engine started: " + std::to_string(sample_rate) + " Hz, " +
           std::to_string(channels) + " ch, " +
           std::to_string(pipeline_.size()) + " modules");
  return Status::kOk;
}

Status Engine::stop() {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  const bool was_running = running_.exchange(false, std::memory_order_acq_rel);
  impl_->in_queue.close(true);
  impl_->out_queue.close(false);
  if (worker_.joinable()) {
    worker_.join();
  }
  if (!was_running) return Status::kNotStarted;
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
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (!running_.load(std::memory_order_acquire)) return Status::kNotStarted;
  SampleBlock info;
  info.data = const_cast<float*>(interleaved);
  info.frames = frames;
  info.channels = channels;
  info.sample_rate = sample_rate_;
  info.first_sample = sample_counter_;
  if (!info.valid() || channels != channels_) return Status::kInvalidArgument;
  auto block = std::make_unique<OwnedSampleBlock>(info);
  std::copy_n(interleaved, info.size(), block->view().data);
  uint64_t dropped = 0;
  if (!impl_->in_queue.push(block, dropped)) return Status::kQueueOverflow;
  metrics_.dropped_blocks.fetch_add(dropped, std::memory_order_relaxed);
  sample_counter_ += static_cast<uint64_t>(frames);
  return Status::kOk;
}

Status Engine::configure_queues(size_t capacity, size_t max_bytes,
                                QueuePolicy input, QueuePolicy output) {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (running_.load(std::memory_order_acquire)) return Status::kAlreadyRunning;
  if (worker_.joinable()) worker_.join();
  // Validate both policies before making either change.
  internal::BlockQueue check_input, check_output;
  if (!check_input.configure(capacity, max_bytes, input) ||
      !check_output.configure(capacity, max_bytes, output)) {
    return Status::kInvalidArgument;
  }
  impl_->in_queue.close(true);
  impl_->out_queue.close(true);
  draining_.reset();
  drain_offset_ = 0;
  impl_->in_queue.configure(capacity, max_bytes, input);
  impl_->out_queue.configure(capacity, max_bytes, output);
  return Status::kOk;
}

Status Engine::push_block(SampleBlockPtr& block) {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (!block || !block->view().valid()) return Status::kInvalidArgument;
  if (!running_.load(std::memory_order_acquire)) return Status::kNotStarted;
  const auto& info = block->view();
  if (info.channels != channels_ || info.sample_rate != sample_rate_) {
    set_last_error("push_block: channel count/sample rate mismatch");
    return Status::kInvalidArgument;
  }
  uint64_t dropped = 0;
  if (!impl_->in_queue.push(block, dropped)) return Status::kQueueOverflow;
  metrics_.dropped_blocks.fetch_add(dropped, std::memory_order_relaxed);
  return Status::kOk;
}

Status Engine::pop_block(SampleBlockPtr& block) {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (draining_) return Status::kInvalidArgument; // Don't reorder legacy data.
  return impl_->out_queue.pop(block) ? Status::kOk : Status::kQueueEmpty;
}

int Engine::pop_samples(float* out_interleaved, int frames, int channels) {
  std::lock_guard<std::mutex> lock(lifecycle_mutex_);
  if (out_interleaved == nullptr || frames <= 0 || channels <= 0) {
    return static_cast<int>(Status::kInvalidArgument);
  }
  if (channels != channels_) {
    return static_cast<int>(Status::kInvalidArgument);
  }

  int filled = 0;
  if (static_cast<size_t>(frames) >
      SampleBlock::kMaxBytes / sizeof(float) / static_cast<size_t>(channels)) {
    return static_cast<int>(Status::kInvalidArgument);
  }
  while (filled < frames) {
    if (!draining_ && !impl_->out_queue.pop(draining_)) break;
    const auto& info = draining_->view();
    const int count = std::min(info.frames - drain_offset_, frames - filled);
    for (int f = 0; f < count; ++f) {
      for (int c = 0; c < channels; ++c) {
        out_interleaved[static_cast<size_t>(filled + f) * channels + c] =
            info.at(drain_offset_ + f, c);
      }
    }
    filled += count;
    drain_offset_ += count;
    if (drain_offset_ == info.frames) {
      draining_.reset();
      drain_offset_ = 0;
    }
  }
  return filled;
}

void Engine::worker_loop() {
  try {
    SampleBlockPtr block;
    while (running_.load(std::memory_order_acquire) &&
           impl_->in_queue.pop(block, true)) {
      for (auto& module : pipeline_) {
        module->process(block->view());
      }
      metrics_.processed_blocks.fetch_add(1, std::memory_order_relaxed);
      uint64_t dropped = 0;
      // `every` propagates pressure to input; no loss on output saturation.
      // stop() closes both queues and wakes this wait before joining.
      if (!impl_->out_queue.push(block, dropped, true)) ++dropped;
      metrics_.dropped_blocks.fetch_add(dropped, std::memory_order_relaxed);
    }
  } catch (const std::exception& error) {
    set_last_error(error.what());
    running_.store(false, std::memory_order_release);
    impl_->in_queue.close(true);
    impl_->out_queue.close(false);
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
