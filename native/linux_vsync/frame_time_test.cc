#include "frame_time.h"
#include <cassert>
#include <cstdio>
#include <initializer_list>

int main() {
  const uint64_t now = 90000000000;
  for (const auto interval : {6944LL, 6061LL, 4167LL, 16667LL}) {
    const auto time = qualia::frame_time(now, 400000, 399000, 400000 + interval, interval);
    assert(time.start == now - 1000000);
    assert(time.target == now + interval * 1000);
    assert(time.target > time.start);
  }
  const auto unknown = qualia::frame_time(now, 400000, 400000, 0, 0);
  assert(unknown.target == now + 16667000);
  const auto stale = qualia::frame_time(now, 400000, 390000, 399000, 6944);
  assert(stale.target == now + 6944000);
  const auto future = qualia::frame_time(now, 400000, 401000, 407000, 6944);
  assert(future.start == now);
  assert(future.target > future.start);
  std::puts("native vsync timing: 60/144/165/240 Hz and unknown/stale clocks passed");
}
