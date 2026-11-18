#include "bci_engine/stft.hpp"

#include <algorithm>
#include <cmath>
#include <utility>

#include "fft.hpp"

namespace bci {
namespace {
bool power_of_two(size_t value) {
  return value != 0 && (value & (value - 1)) == 0;
}
}  // namespace

Stft::Stft(StftConfig config) : config_(config) {
  if (valid()) pending_.reserve(config_.window_size);
}

bool Stft::valid() const {
  return power_of_two(config_.window_size) && config_.window_size >= 2 &&
         config_.hop_size > 0 && config_.hop_size <= config_.window_size &&
         std::isfinite(config_.sample_rate) && config_.sample_rate > 0.0;
}

void Stft::reset() { pending_.clear(); }

std::vector<std::vector<float>> Stft::push(const float* samples, size_t count) {
  std::vector<std::vector<float>> rows;
  if (!valid() || samples == nullptr || count == 0) return rows;
  pending_.insert(pending_.end(), samples, samples + count);
  while (pending_.size() >= config_.window_size) {
    std::vector<double> frame(config_.window_size);
    for (size_t i = 0; i < config_.window_size; ++i) {
      const double phase = 2.0 * 3.14159265358979323846 * i /
                           static_cast<double>(config_.window_size - 1);
      frame[i] = pending_[i] * (0.5 * (1.0 - std::cos(phase)));
    }
    const auto magnitude = fft_magnitude(frame.data(), frame.size());
    std::vector<float> row;
    row.reserve(magnitude.size());
    for (const double value : magnitude) row.push_back(static_cast<float>(value));
    rows.push_back(std::move(row));
    const size_t advance = std::min(config_.hop_size, pending_.size());
    pending_.erase(pending_.begin(), pending_.begin() + static_cast<ptrdiff_t>(advance));
  }
  return rows;
}

}  // namespace bci
