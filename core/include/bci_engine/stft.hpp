#pragma once

#include <cstddef>
#include <vector>

#include "bci_engine/c_api.h"

namespace bci {

struct StftConfig {
  size_t window_size = 256;
  size_t hop_size = 32;
  double sample_rate = 256.0;
};

/// Bounded Hann-window STFT for real-time diagnostics. The returned matrix is
/// row-major: one row per completed window, with window_size/2 + 1 bins.
class BCI_API Stft {
 public:
  explicit Stft(StftConfig config = {});

  bool valid() const;
  const StftConfig& config() const { return config_; }
  void reset();

  /// Appends samples and returns newly completed magnitude rows.
  std::vector<std::vector<float>> push(const float* samples, size_t count);

 private:
  StftConfig config_;
  std::vector<float> pending_;
};

}  // namespace bci
