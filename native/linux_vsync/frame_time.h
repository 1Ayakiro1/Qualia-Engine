#ifndef QUALIA_FRAME_TIME_H_
#define QUALIA_FRAME_TIME_H_

#include <cstdint>

namespace qualia {
struct FrameTime {
  uint64_t start;
  uint64_t target;
};

// GTK timestamps are monotonic microseconds; Flutter uses monotonic nanoseconds.
// Sample both clocks at delivery, rather than assuming identical clock epochs.
inline FrameTime frame_time(uint64_t engine_now,
                            int64_t gtk_now,
                            int64_t gtk_frame,
                            int64_t gtk_target,
                            int64_t interval) {
  if (interval <= 0) interval = 16667;  // Only for unavailable refresh info.
  const int64_t age = gtk_now > gtk_frame ? gtk_now - gtk_frame : 0;
  const uint64_t age_ns = static_cast<uint64_t>(age) * 1000;
  const uint64_t start = age_ns < engine_now ? engine_now - age_ns : 0;
  const int64_t remaining = gtk_target > gtk_now ? gtk_target - gtk_now : interval;
  return {start, engine_now + static_cast<uint64_t>(remaining) * 1000};
}
}  // namespace qualia
#endif
