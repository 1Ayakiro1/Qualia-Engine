#include <math.h>
// Small FFI dependency shared by C++ and Python; one ABI, no host plugin loading.
double qualia_square(double value) { return value * value; }
double qualia_rms(const double* values, int count) {
  double sum = 0;
  for (int i = 0; i < count; ++i) sum += values[i] * values[i];
  return count ? sqrt(sum / count) : 0;
}
