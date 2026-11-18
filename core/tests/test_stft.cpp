#include "catch.hpp"

#include <cmath>
#include <vector>

#include "bci_engine/c_api.h"
#include "bci_engine/lsl_hal.hpp"
#include "bci_engine/stft.hpp"

TEST_CASE("native STFT emits Hann-windowed magnitude rows", "[stft]") {
  constexpr size_t window = 256;
  std::vector<float> samples(window * 3, 0.0f);
  for (size_t i = 0; i < samples.size(); ++i) {
    samples[i] = static_cast<float>(std::sin(2.0 * 3.14159265358979323846 *
                                             32.0 * i / window));
  }
  bci::Stft stft({window, 32, 256.0});
  const auto rows = stft.push(samples.data(), samples.size());
  REQUIRE(rows.size() == 17);
  REQUIRE(rows.front().size() == window / 2 + 1);
  size_t peak = 0;
  for (size_t i = 1; i < rows.front().size(); ++i) {
    if (rows.front()[i] > rows.front()[peak]) peak = i;
  }
  REQUIRE(peak == 32);
}

TEST_CASE("STFT C ABI rejects undersized output", "[stft]") {
  std::vector<float> samples(256, 1.0f);
  bci_stft_config config{256, 32, 256.0};
  std::vector<float> output(8);
  REQUIRE(bci_stft_compute(samples.data(), samples.size(), &config,
                           output.data(), 1, 8) == BCI_INVALID_ARGUMENT);
}

TEST_CASE("LSL adapter is optional and does not require a system library", "[hal]") {
  // The test is intentionally environment-independent: availability may be
  // either true or false, but discovery must never throw when absent.
  REQUIRE_NOTHROW(bci::hal::LslInlet::discover());
}
