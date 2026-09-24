// Internal lock-free SPSC ring buffer fallback.
//
// Used only when readerwriterqueue could not be fetched. Single producer /
// single consumer semantics: exactly one thread calls push(), exactly one
// thread calls try_dequeue().
#pragma once

#include <atomic>
#include <cstddef>
#include <memory>
#include <vector>

namespace bci {
namespace internal {

template <typename T>
class SpscRing {
 public:
  explicit SpscRing(size_t capacity)
      : slots_(capacity), capacity_(capacity) {
    head_.store(0, std::memory_order_relaxed);
    tail_.store(0, std::memory_order_relaxed);
  }

  // Producer side. Returns false when the ring is full.
  bool try_enqueue(T value) {
    const size_t head = head_.load(std::memory_order_relaxed);
    const size_t tail = tail_.load(std::memory_order_acquire);
    if (head - tail >= capacity_) {
      return false;
    }
    slots_[head % capacity_] = std::move(value);
    head_.store(head + 1, std::memory_order_release);
    return true;
  }

  // Consumer side. Returns false when the ring is empty.
  bool try_dequeue(T& out) {
    const size_t tail = tail_.load(std::memory_order_relaxed);
    const size_t head = head_.load(std::memory_order_acquire);
    if (tail == head) {
      return false;
    }
    out = std::move(slots_[tail % capacity_]);
    tail_.store(tail + 1, std::memory_order_release);
    return true;
  }

  size_t size_approx() const {
    return head_.load(std::memory_order_acquire) -
           tail_.load(std::memory_order_acquire);
  }

 private:
  std::vector<T> slots_;
  size_t capacity_;
  // Cache-line padded to avoid false sharing.
  alignas(64) std::atomic<size_t> head_;
  alignas(64) std::atomic<size_t> tail_;
};

}  // namespace internal
}  // namespace bci
