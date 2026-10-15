// Bounded ownership queue. A producer must never dequeue from an SPSC ring to
// implement drop-oldest: that would create two racing consumers. This queue
// serializes admission and eviction, and never releases external leases while
// holding its mutex. It is zero-copy, but is NOT a hard-real-time lock-free API.
#pragma once

#include <condition_variable>
#include <deque>
#include <mutex>
#include <vector>

#include "bci_engine/sample_block.hpp"

namespace bci::internal {

class BlockQueue {
 public:
  bool configure(size_t capacity, size_t max_bytes, QueuePolicy policy) {
    if (capacity == 0 || capacity > 4096 || max_bytes == 0 ||
        max_bytes > 2ULL * 1024 * 1024 * 1024 ||
        (policy != QueuePolicy::kEvery && policy != QueuePolicy::kDropOldest &&
         policy != QueuePolicy::kLatestOnly)) {
      return false;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    if (!closed_ || !queue_.empty()) return false;
    capacity_ = capacity;
    max_bytes_ = max_bytes;
    policy_ = policy;
    return true;
  }

  // On refusal, the caller retains the identical handle and must retry or
  // release it. `every` never silently drops a block. Rejected blocks do not
  // evict accepted data (including blocks larger than the byte budget).
  bool push(SampleBlockPtr& block, uint64_t& dropped, bool wait = false) {
    if (!block) return false;
    const auto bytes = block->bytes();
    std::vector<SampleBlockPtr> evicted;
    std::unique_lock<std::mutex> lock(mutex_);
    if (closed_ || bytes > max_bytes_) return false;
    if (policy_ == QueuePolicy::kEvery) {
      if (wait) {
        changed_.wait(lock, [&] { return closed_ || fits(bytes); });
      }
      if (closed_ || !fits(bytes)) return false;
    }
    // Allocate all metadata before changing accepted blocks or byte accounting.
    // Allocation failure must leave caller ownership and queued data unchanged.
    if (policy_ != QueuePolicy::kEvery &&
        (policy_ == QueuePolicy::kLatestOnly || !fits(bytes))) {
      evicted.reserve(queue_.size());
    }
    queue_.emplace_back();
    if (policy_ != QueuePolicy::kEvery) {
      while (queue_.size() > 1 &&
             (policy_ == QueuePolicy::kLatestOnly || queue_.size() > capacity_ ||
              bytes > max_bytes_ - bytes_)) {
        bytes_ -= queue_.front()->bytes();
        evicted.push_back(std::move(queue_.front()));
        queue_.pop_front();
        ++dropped;
      }
    }
    queue_.back() = std::move(block);
    bytes_ += bytes;
    lock.unlock();
    changed_.notify_all();
    return true;
  }

  bool pop(SampleBlockPtr& block, bool wait = false) {
    // Do not release a previous lease while holding the queue mutex.
    SampleBlockPtr next;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      if (wait) changed_.wait(lock, [&] { return closed_ || !queue_.empty(); });
      if (queue_.empty()) return false;
      bytes_ -= queue_.front()->bytes();
      next = std::move(queue_.front());
      queue_.pop_front();
    }
    block = std::move(next);
    changed_.notify_all();
    return true;
  }

  void close(bool discard) {
    std::deque<SampleBlockPtr> discarded;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      closed_ = true;
      if (discard) {
        queue_.swap(discarded);
        bytes_ = 0;
      }
    }
    changed_.notify_all();
  }

  // Called only after the previous worker has joined.
  void open() {
    close(true);
    std::lock_guard<std::mutex> lock(mutex_);
    closed_ = false;
  }

 private:
  bool fits(size_t bytes) const {
    return queue_.size() < capacity_ && bytes <= max_bytes_ - bytes_;
  }
  std::mutex mutex_;
  std::condition_variable changed_;
  std::deque<SampleBlockPtr> queue_;
  size_t bytes_ = 0;
  size_t capacity_ = 512;
  size_t max_bytes_ = 64 * 1024 * 1024;
  QueuePolicy policy_ = QueuePolicy::kDropOldest;
  bool closed_ = true;
};

}  // namespace bci::internal
