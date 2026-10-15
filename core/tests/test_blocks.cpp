#include "catch.hpp"

#include <atomic>
#include <chrono>
#include <cstring>
#include <future>
#include <limits>
#include <thread>

#include "bci_engine/c_api.h"
#include "bci_engine/core.hpp"
#include "bci_engine/signal_v2.hpp"
#include "block_queue.hpp"

namespace {

bci_block_info metadata(int frames = 4, int channels = 2) {
  return {sizeof(bci_block_info), BCI_LAYOUT_CHANNEL_MAJOR, frames, channels,
          250.0, 1234, 456789000, BCI_CLOCK_MONOTONIC, 0};
}

bci::SampleBlockPtr block(uint64_t sequence, int frames = 4) {
  bci::SampleBlock info;
  info.frames = frames;
  info.channels = 2;
  info.sample_rate = 250;
  info.first_sample = sequence;
  return std::make_unique<bci::OwnedSampleBlock>(info);
}

struct EngineGuard {
  void* value = bci_engine_create();
  ~EngineGuard() { bci_engine_destroy(value); }
};

struct BlockGuard {
  bci_block* value = nullptr;
  ~BlockGuard() { bci_block_release(value); }
};

}  // namespace

TEST_CASE("owned block metadata validates before allocation", "[blocks]") {
  auto info = metadata();
  BlockGuard handle{bci_block_create(&info)};
  REQUIRE(handle.value != nullptr);
  bci_block_info actual{};
  REQUIRE(bci_block_get_info(handle.value, &actual) == BCI_INVALID_ARGUMENT);
  actual.struct_size = sizeof(actual);
  REQUIRE(bci_block_get_info(handle.value, &actual) == BCI_OK);
  REQUIRE(actual.first_sample == info.first_sample);
  REQUIRE(actual.timestamp_ns == info.timestamp_ns);
  REQUIRE(actual.clock == BCI_CLOCK_MONOTONIC);
  REQUIRE(bci_block_data(handle.value)[0] == 0);
  for (const auto rate : {0.0, -1.0, std::numeric_limits<double>::infinity(),
                          std::numeric_limits<double>::quiet_NaN()}) {
    info.sample_rate = rate;
    REQUIRE(bci_block_create(&info) == nullptr);
  }
  info = metadata();
  info.frames = std::numeric_limits<int32_t>::max();
  info.channels = std::numeric_limits<int32_t>::max();
  REQUIRE(bci_block_create(&info) == nullptr);
  info = metadata();
  info.layout = 2;
  REQUIRE(bci_block_create(&info) == nullptr);
  info = metadata();
  info.struct_size--;
  REQUIRE(bci_block_create(&info) == nullptr);
  REQUIRE(bci_block_create(nullptr) == nullptr);
  REQUIRE(bci_block_data(nullptr) == nullptr);
  bci_block_release(nullptr);
}

TEST_CASE("channel-major external lease crosses core without copying", "[blocks]") {
  std::atomic<int> releases{0};
  EngineGuard engine;
  REQUIRE(engine.value != nullptr);
  REQUIRE(bci_engine_start(engine.value, 250, 2) == BCI_OK);
  const auto info = metadata();
  auto* samples = new float[8]{1, 2, 3, 4, 10, 20, 30, 40};
  BlockGuard input{bci_block_wrap(&info, samples, [](float* data, void* context) {
    delete[] data;
    static_cast<std::atomic<int>*>(context)->fetch_add(1);
  }, &releases)};
  REQUIRE(input.value != nullptr);
  auto* original_handle = input.value;
  REQUIRE(bci_engine_push_block(engine.value, &input.value) == BCI_OK);
  REQUIRE(input.value == nullptr);
  BlockGuard output;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
  while (bci_engine_pop_block(engine.value, &output.value) == BCI_QUEUE_EMPTY &&
         std::chrono::steady_clock::now() < deadline) {
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  REQUIRE(output.value == original_handle);
  REQUIRE(bci_block_data(output.value) == samples);
  REQUIRE(releases.load() == 0);
  // The actual native pipeline processed the same channel-major allocation.
  REQUIRE(samples[0] == 1);
  REQUIRE(samples[1] == Approx(1.8));
  REQUIRE(samples[4] == 10);
  REQUIRE(samples[5] == Approx(18));
  bci_block_info actual{};
  actual.struct_size = sizeof(actual);
  REQUIRE(bci_block_get_info(output.value, &actual) == BCI_OK);
  REQUIRE(actual.timestamp_ns == info.timestamp_ns);
  REQUIRE(actual.first_sample == info.first_sample);
  REQUIRE(actual.sample_rate == 250);
  REQUIRE(actual.layout == BCI_LAYOUT_CHANNEL_MAJOR);
  bci_block_release(output.value);
  output.value = nullptr;
  REQUIRE(releases.load() == 1);
}

TEST_CASE("refused C ABI push retains caller ownership", "[blocks]") {
  EngineGuard engine;
  auto info = metadata();
  BlockGuard handle{bci_block_create(&info)};
  auto* original = handle.value;
  REQUIRE(bci_engine_push_block(engine.value, &handle.value) == BCI_NOT_STARTED);
  REQUIRE(handle.value == original);
  REQUIRE(bci_engine_start(engine.value, 250, 1) == BCI_OK);
  REQUIRE(bci_engine_push_block(engine.value, &handle.value) == BCI_INVALID_ARGUMENT);
  REQUIRE(handle.value == original);
  REQUIRE(bci_engine_pop_block(engine.value, &handle.value) == BCI_INVALID_ARGUMENT);
  REQUIRE(bci_engine_configure_queues(engine.value, 1, 1024,
                                    BCI_QUEUE_EVERY, BCI_QUEUE_EVERY) == BCI_ALREADY_RUNNING);
  REQUIRE(bci_engine_stop(engine.value) == BCI_OK);
  REQUIRE(bci_engine_configure_queues(engine.value, 1, 1024, 99, BCI_QUEUE_EVERY) ==
          BCI_INVALID_ARGUMENT);
}

TEST_CASE("unadopted external allocation is never released on validation failure", "[blocks]") {
  auto info = metadata();
  float samples[8]{};
  int releases = 0;
  const auto release = [](float*, void* counter) { ++*static_cast<int*>(counter); };
  info.layout = 99;
  REQUIRE(bci_block_wrap(&info, samples, release, &releases) == nullptr);
  info = metadata();
  REQUIRE(bci_block_wrap(&info, samples, nullptr, &releases) == nullptr);
  REQUIRE(bci_block_wrap(&info, nullptr, release, &releases) == nullptr);
  alignas(float) uint8_t unaligned[sizeof(samples) + 1]{};
  REQUIRE(bci_block_wrap(&info, reinterpret_cast<float*>(unaligned + 1), release,
                         &releases) == nullptr);
  REQUIRE(releases == 0);
}

TEST_CASE("external leases release once on queue eviction and shutdown", "[backpressure]") {
  int released = 0;
  {
    bci::internal::BlockQueue queue;
    REQUIRE(queue.configure(1, 64, bci::QueuePolicy::kLatestOnly));
    queue.open();
    for (uint64_t i = 0; i < 10; ++i) {
      bci::SampleBlock view;
      view.frames = 4;
      view.channels = 2;
      view.sample_rate = 250;
      view.first_sample = i;
      view.data = new float[8]{};
      auto value = std::make_unique<bci::OwnedSampleBlock>(view, [](float* p, void* ctx) {
        delete[] p;
        ++*static_cast<int*>(ctx);
      }, &released);
      uint64_t drops = 0;
      REQUIRE(queue.push(value, drops));
      REQUIRE(released == static_cast<int>(i));
    }
    queue.close(true);
    REQUIRE(released == 10);
    queue.close(true);
  }
  REQUIRE(released == 10);
}

TEST_CASE("queue every refuses overflow without consuming ownership", "[backpressure]") {
  bci::internal::BlockQueue queue;
  REQUIRE(queue.configure(2, 64, bci::QueuePolicy::kEvery));
  queue.open();
  uint64_t drops = 0;
  auto a = block(1), b = block(2), c = block(3);
  REQUIRE(queue.push(a, drops));
  REQUIRE(queue.push(b, drops));
  auto* original = c.get();
  REQUIRE_FALSE(queue.push(c, drops));
  REQUIRE(c.get() == original);
  REQUIRE(drops == 0);
  bci::SampleBlockPtr result;
  REQUIRE(queue.pop(result));
  REQUIRE(result->view().first_sample == 1);
  REQUIRE(queue.push(c, drops));
  REQUIRE(queue.pop(result));
  REQUIRE(result->view().first_sample == 2);
  REQUIRE(queue.pop(result));
  REQUIRE(result->view().first_sample == 3);
  REQUIRE_FALSE(queue.pop(result));
}

TEST_CASE("lossy policies evict whole queued blocks within byte budget", "[backpressure]") {
  for (const auto policy : {bci::QueuePolicy::kDropOldest,
                             bci::QueuePolicy::kLatestOnly}) {
    bci::internal::BlockQueue queue;
    REQUIRE(queue.configure(2, 64, policy));
    queue.open();
    uint64_t drops = 0;
    for (uint64_t i = 1; i <= 3; ++i) {
      auto value = block(i);
      REQUIRE(queue.push(value, drops));
      REQUIRE_FALSE(value);
    }
    // Oversized admission must not evict any previously accepted block.
    auto oversized = block(4, 9);
    REQUIRE_FALSE(queue.push(oversized, drops));
    bci::SampleBlockPtr result;
    REQUIRE(queue.pop(result));
    REQUIRE(result->view().first_sample ==
            (policy == bci::QueuePolicy::kDropOldest ? 2 : 3));
    REQUIRE(drops == (policy == bci::QueuePolicy::kDropOldest ? 1 : 2));
    if (policy == bci::QueuePolicy::kDropOldest) {
      REQUIRE(queue.pop(result));
      REQUIRE(result->view().first_sample == 3);
    }
    REQUIRE_FALSE(queue.pop(result));
  }
}

TEST_CASE("stop wakes worker blocked by every output policy", "[backpressure]") {
  EngineGuard engine;
  REQUIRE(bci_engine_configure_queues(engine.value, 1, 1024,
                                    BCI_QUEUE_EVERY, BCI_QUEUE_EVERY) == BCI_OK);
  REQUIRE(bci_engine_start(engine.value, 250, 2) == BCI_OK);
  auto info = metadata();
  // Saturate pipeline and output without relying on worker scheduling.
  for (int i = 0; i < 100; ++i) {
    BlockGuard input{bci_block_create(&info)};
    const auto code = bci_engine_push_block(engine.value, &input.value);
    REQUIRE((code == BCI_OK || code == BCI_QUEUE_OVERFLOW));
  }
  auto stopped = std::async(std::launch::async, [&] {
    return bci_engine_stop(engine.value);
  });
  REQUIRE(stopped.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
  REQUIRE(stopped.get() == BCI_OK);
  // Repeated runs cannot replay input that belonged to the previous run.
  REQUIRE(bci_engine_start(engine.value, 250, 2) == BCI_OK);
  BlockGuard output;
  REQUIRE(bci_engine_pop_block(engine.value, &output.value) == BCI_QUEUE_EMPTY);
}

TEST_CASE("every propagates a stalled consumer without losing accepted blocks", "[backpressure]") {
  EngineGuard engine;
  REQUIRE(bci_engine_configure_queues(engine.value, 1, 1024,
                                    BCI_QUEUE_EVERY, BCI_QUEUE_EVERY) == BCI_OK);
  REQUIRE(bci_engine_start(engine.value, 250, 2) == BCI_OK);
  auto info = metadata();
  for (uint64_t sequence = 1; sequence <= 3; ++sequence) {
    info.first_sample = sequence;
    BlockGuard input{bci_block_create(&info)};
    REQUIRE(input.value != nullptr);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    int status;
    do {
      status = bci_engine_push_block(engine.value, &input.value);
      if (status == BCI_QUEUE_OVERFLOW) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
      }
    } while (status == BCI_QUEUE_OVERFLOW && std::chrono::steady_clock::now() < deadline);
    REQUIRE(status == BCI_OK);
  }
  // First occupies output, second waits on output credits, third fills input.
  BlockGuard fourth{bci_block_create(&info)};
  const auto* refused = fourth.value;
  REQUIRE(bci_engine_push_block(engine.value, &fourth.value) == BCI_QUEUE_OVERFLOW);
  REQUIRE(fourth.value == refused);
  for (uint64_t sequence = 1; sequence <= 3; ++sequence) {
    BlockGuard output;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    int status;
    do {
      status = bci_engine_pop_block(engine.value, &output.value);
      if (status == BCI_QUEUE_EMPTY) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
      }
    } while (status == BCI_QUEUE_EMPTY &&
             std::chrono::steady_clock::now() < deadline);
    REQUIRE(status == BCI_OK);
    REQUIRE(bci_block_get_info(output.value, &info) == BCI_OK);
    REQUIRE(info.first_sample == sequence);
  }
  REQUIRE(bci_engine_stop(engine.value) == BCI_OK);
}

TEST_CASE("legacy partial reads preserve FIFO and channel order", "[blocks]") {
  EngineGuard engine;
  REQUIRE(bci_engine_start(engine.value, 250, 2) == BCI_OK);
  auto info = metadata(4, 2);
  for (int i = 0; i < 2; ++i) {
    BlockGuard input{bci_block_create(&info)};
    auto* samples = bci_block_data(input.value);
    std::fill_n(samples, 4, i ? 9.0f : 1.0f);
    std::fill_n(samples + 4, 4, i ? 90.0f : 10.0f);
    REQUIRE(bci_engine_push_block(engine.value, &input.value) == BCI_OK);
  }
  float values[2]{};
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
  int received = 0;
  while (received < 8 && std::chrono::steady_clock::now() < deadline) {
    const int frames = bci_engine_pop_samples(engine.value, values, 1, 2);
    if (frames == 0) {
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
      continue;
    }
    REQUIRE(frames == 1);
    REQUIRE(values[1] == Approx(values[0] * 10));
    if (received < 4) REQUIRE(values[0] == 1);
    else REQUIRE(values[0] > 1);
    ++received;
  }
  REQUIRE(received == 8);
}

TEST_CASE("concurrent eviction preserves unique leases and increasing order", "[backpressure]") {
  bci::internal::BlockQueue queue;
  REQUIRE(queue.configure(4, 128, bci::QueuePolicy::kDropOldest));
  queue.open();
  constexpr uint64_t count = 20000;
  std::atomic<bool> done{false};
  std::atomic<bool> ordered{true};
  uint64_t received = 0;
  std::thread consumer([&] {
    uint64_t previous = 0;
    bci::SampleBlockPtr value;
    while (!done.load(std::memory_order_acquire) || queue.pop(value)) {
      if (!value && !queue.pop(value)) {
        std::this_thread::yield();
        continue;
      }
      const auto sequence = value->view().first_sample;
      if (sequence <= previous) ordered = false;
      previous = sequence;
      ++received;
      value.reset();
    }
  });
  uint64_t dropped = 0;
  bool admitted = true;
  for (uint64_t i = 1; i <= count; ++i) {
    auto value = block(i);
    if (!queue.push(value, dropped)) admitted = false;
  }
  done.store(true, std::memory_order_release);
  consumer.join();
  REQUIRE(admitted);
  REQUIRE(ordered.load());
  REQUIRE(received + dropped == count);
}

TEST_CASE("QSB2 header agrees with Python golden and assembles tensor", "[wire]") {
  auto value = block(1234);
  auto& view = value->view();
  view.layout = bci::SampleLayout::kChannelMajor;
  view.clock = bci::SampleClock::kMonotonic;
  view.timestamp_ns = -456789000;
  const float samples[8]{1, 2, 3, 4, 10, 20, 30, 40};
  std::copy_n(samples, 8, view.data);
  const auto* bytes = reinterpret_cast<const uint8_t*>(view.data);
  bci::wire::ChunkHeader header;
  header.info = view;
  header.sequence = 7;
  header.length = 32;
  header.crc = bci::wire::crc32(bytes, 32);
  const auto encoded = bci::wire::encode(header);
  const std::string golden = "515342320200500001010000010000000700000000000000d204000000000000f8f3c5e4ffffffff0000000000406f400200000004000000000000000000000020000000000000002000000049d32de2";
  std::string actual;
  for (const auto byte : encoded) {
    actual += "0123456789abcdef"[byte >> 4];
    actual += "0123456789abcdef"[byte & 15];
  }
  REQUIRE(actual == golden);
  auto decoded = bci::wire::decode(encoded.data(), encoded.size());
  REQUIRE(decoded.info.timestamp_ns == view.timestamp_ns);
  REQUIRE(decoded.sequence == 7);
  bci::wire::Assembler assembler;
  assembler.append(decoded, bytes, 32);
  REQUIRE(assembler.complete());
  auto result = assembler.take();
  REQUIRE(std::memcmp(result->view().data, view.data, 32) == 0);
  REQUIRE_THROWS_AS(assembler.append(decoded, bytes, 32), std::invalid_argument);
}

TEST_CASE("QSB2 rejects oversized malformed changed and corrupt chunks", "[wire]") {
  auto value = block(1, 140000);
  auto& info = value->view();
  info.clock = bci::SampleClock::kMonotonic;
  const auto* bytes = reinterpret_cast<const uint8_t*>(info.data);
  bci::wire::ChunkHeader header;
  header.info = info;
  header.sequence = 1;
  header.length = bci::wire::kMaxChunkBytes;
  header.crc = bci::wire::crc32(bytes, header.length);
  auto encoded = bci::wire::encode(header);
  REQUIRE_THROWS_AS(bci::wire::decode(encoded.data(), encoded.size(), 64),
                    std::invalid_argument);
  bci::wire::Assembler assembler;
  assembler.append(header, bytes, header.length);
  REQUIRE_FALSE(assembler.complete());
  REQUIRE_THROWS_AS(assembler.take(), std::logic_error);
  REQUIRE_THROWS_AS(assembler.append(header, bytes, header.length), std::invalid_argument);
  header.offset = header.length;
  header.length = static_cast<uint32_t>(info.bytes() - header.offset);
  header.crc = bci::wire::crc32(bytes + header.offset, header.length);
  header.info.timestamp_ns++;
  REQUIRE_THROWS_AS(assembler.append(header, bytes + header.offset, header.length),
                    std::invalid_argument);
  header.info.timestamp_ns--;
  header.crc ^= 1;
  REQUIRE_THROWS_AS(assembler.append(header, bytes + header.offset, header.length),
                    std::invalid_argument);
  header.crc ^= 1;
  assembler.append(header, bytes + header.offset, header.length);
  REQUIRE(assembler.complete());
  auto complete = assembler.take();
  REQUIRE(complete->bytes() > 1024 * 1024);
  encoded[8] = 2;
  REQUIRE_THROWS_AS(bci::wire::decode(encoded.data(), encoded.size()), std::invalid_argument);
}
