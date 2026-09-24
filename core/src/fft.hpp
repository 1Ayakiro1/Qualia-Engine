// Simple radix-2 iterative FFT (power-of-two sizes only).
// Enough for diagnostics and the first spectrogram experiments; a real-time
// optimized implementation (real-input FFT / WebGLP) lands later.
#pragma once

#include <complex>
#include <cstddef>
#include <vector>

namespace bci {

// In-place FFT over `data` (size must be a power of two, >= 1).
void fft_in_place(std::vector<std::complex<double>>& data);

// Magnitude spectrum (N/2 + 1 bins) of a real signal.
std::vector<double> fft_magnitude(const double* samples, size_t count);

}  // namespace bci
