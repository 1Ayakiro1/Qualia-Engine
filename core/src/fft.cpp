#include "fft.hpp"

#include <cmath>
#include <cstdlib>

namespace bci {

namespace {
bool is_power_of_two(size_t n) { return n != 0 && (n & (n - 1)) == 0; }

size_t log2_exact(size_t n) {
#ifdef _MSC_VER
  size_t bits = 0;
  while ((size_t(1) << bits) < n) {
    ++bits;
  }
  return bits;
#else
  return static_cast<size_t>(__builtin_ctzll(static_cast<unsigned long long>(n)));
#endif
}

size_t bit_reverse(size_t value, size_t bits) {
  size_t reversed = 0;
  for (size_t i = 0; i < bits; ++i) {
    reversed = (reversed << 1) | (value & 1);
    value >>= 1;
  }
  return reversed;
}
}  // namespace

void fft_in_place(std::vector<std::complex<double>>& data) {
  const size_t n = data.size();
  if (n < 2 || !is_power_of_two(n)) {
    return;
  }
  const size_t bits = log2_exact(n);

  // Bit-reversal permutation.
  for (size_t i = 0; i < n; ++i) {
    const size_t j = bit_reverse(i, bits);
    if (i < j) {
      std::swap(data[i], data[j]);
    }
  }

  // Cooley-Tukey butterflies.
  for (size_t len = 2; len <= n; len <<= 1) {
    const double angle = -2.0 * 3.14159265358979323846 / static_cast<double>(len);
    const std::complex<double> step(std::cos(angle), std::sin(angle));
    const size_t half = len / 2;
    for (size_t start = 0; start < n; start += len) {
      std::complex<double> w(1.0, 0.0);
      for (size_t k = 0; k < half; ++k) {
        const std::complex<double> u = data[start + k];
        const std::complex<double> v = data[start + k + half] * w;
        data[start + k] = u + v;
        data[start + k + half] = u - v;
        w *= step;
      }
    }
  }
}

std::vector<double> fft_magnitude(const double* samples, size_t count) {
  if (samples == nullptr || count == 0 || !is_power_of_two(count)) {
    return {};
  }
  std::vector<std::complex<double>> spectrum(count);
  for (size_t i = 0; i < count; ++i) {
    spectrum[i] = std::complex<double>(samples[i], 0.0);
  }
  fft_in_place(spectrum);

  std::vector<double> magnitude(count / 2 + 1);
  for (size_t i = 0; i < magnitude.size(); ++i) {
    magnitude[i] = std::abs(spectrum[i]) / static_cast<double>(count);
    if (i != 0 && i != count / 2) {
      magnitude[i] *= 2.0;  // one-sided spectrum correction
    }
  }
  return magnitude;
}

}  // namespace bci
