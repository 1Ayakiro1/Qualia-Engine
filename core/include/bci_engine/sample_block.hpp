// Owned, timestamped float32 signal blocks. No protocol or OS handles here.
#pragma once

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

namespace bci {

enum class SampleLayout : uint32_t { kInterleaved = 0, kChannelMajor = 1 };
enum class SampleClock : uint32_t { kUnknown = 0, kMonotonic = 1, kUnix = 2 };
enum class QueuePolicy : uint32_t { kEvery = 0, kDropOldest = 1, kLatestOnly = 2 };

// Samples are uniformly spaced within a block. timestamp_ns refers to frame 0
// in the explicitly named clock domain, never an implicit wall-clock guess.
struct SampleBlock {
  float* data = nullptr;
  int frames = 0;
  int channels = 0;
  double sample_rate = 0.0;
  uint64_t first_sample = 0;
  int64_t timestamp_ns = 0;
  SampleLayout layout = SampleLayout::kInterleaved;
  SampleClock clock = SampleClock::kUnknown;

  static constexpr size_t kMaxBytes = 256 * 1024 * 1024;

  bool valid_metadata() const {
    if (frames <= 0 || channels <= 0 ||
        !std::isfinite(sample_rate) || sample_rate <= 0 ||
        (layout != SampleLayout::kInterleaved &&
         layout != SampleLayout::kChannelMajor) ||
        (clock != SampleClock::kUnknown && clock != SampleClock::kMonotonic &&
         clock != SampleClock::kUnix)) {
      return false;
    }
    // Divide before multiplying: dimensions from untrusted callers cannot wrap.
    return first_sample <= UINT64_MAX - static_cast<uint64_t>(frames) &&
           static_cast<size_t>(frames) <=
           kMaxBytes / sizeof(float) / static_cast<size_t>(channels);
  }
  bool valid() const {
    return data != nullptr && reinterpret_cast<uintptr_t>(data) % alignof(float) == 0 &&
           valid_metadata();
  }

  size_t size() const {
    return static_cast<size_t>(frames) * static_cast<size_t>(channels);
  }
  size_t bytes() const { return size() * sizeof(float); }

  float& at(int frame, int channel) const {
    return data[layout == SampleLayout::kInterleaved
                    ? static_cast<size_t>(frame) * channels + channel
                    : static_cast<size_t>(channel) * frames + frame];
  }
};

// A block owns either a native allocation or one exclusively leased external
// allocation (e.g. an SHM slot). Its address and sample pointer stay stable as
// the unique handle moves through the core. No copy on push/process/pop.
class OwnedSampleBlock {
 public:
  using Release = void (*)(float* data, void* context);

  explicit OwnedSampleBlock(const SampleBlock& info)
      : info_(info), storage_(info.size()) {
    info_.data = storage_.data();
  }
  OwnedSampleBlock(const SampleBlock& info, Release release, void* context)
      : info_(info), release_(release), context_(context) {}
  ~OwnedSampleBlock() {
    if (release_ != nullptr) release_(info_.data, context_);
  }
  OwnedSampleBlock(const OwnedSampleBlock&) = delete;
  OwnedSampleBlock& operator=(const OwnedSampleBlock&) = delete;

  SampleBlock& view() { return info_; }
  const SampleBlock& view() const { return info_; }
  size_t bytes() const { return info_.bytes(); }

 private:
  SampleBlock info_;
  std::vector<float> storage_;
  Release release_ = nullptr;
  void* context_ = nullptr;
};

using SampleBlockPtr = std::unique_ptr<OwnedSampleBlock>;

}  // namespace bci
