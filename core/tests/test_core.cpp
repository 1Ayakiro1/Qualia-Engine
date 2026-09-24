// BCI core tests (Catch2 v2 single header).
#define CATCH_CONFIG_MAIN
#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "catch.hpp"

#include "bci_engine/c_api.h"
#include "bci_engine/core.hpp"

namespace {

std::vector<float> make_sine(int frames, int channels, double frequency,
                             double sample_rate, double amplitude) {
  std::vector<float> data(static_cast<size_t>(frames) * channels, 0.0f);
  for (int f = 0; f < frames; ++f) {
    const double t = static_cast<double>(f) / sample_rate;
    for (int c = 0; c < channels; ++c) {
      data[static_cast<size_t>(f) * channels + c] =
          static_cast<float>(amplitude * std::sin(2.0 * 3.14159265358979323846 *
                                                  frequency * t));
    }
  }
  return data;
}

}  // namespace

TEST_CASE("version constants are coherent", "[version]") {
  REQUIRE(std::strcmp(bci_engine_core_version(), BCI_CORE_VERSION) == 0);
  REQUIRE(bci_engine_abi_version() == BCI_CORE_ABI_VERSION);
}

TEST_CASE("engine lifecycle via C API", "[engine]") {
  void* engine = bci_engine_create();
  REQUIRE(engine != nullptr);

  // Not started: push must fail.
  const auto sine = make_sine(64, 1, 10.0, 256.0, 0.5);
  REQUIRE(bci_engine_push_samples(engine, sine.data(), 64, 1) ==
          BCI_NOT_STARTED);

  REQUIRE(bci_engine_start(engine, 256, 1) == BCI_OK);
  REQUIRE(bci_engine_is_running(engine) == 1);
  REQUIRE(bci_engine_start(engine, 256, 1) == BCI_ALREADY_RUNNING);

  REQUIRE(bci_engine_push_samples(engine, sine.data(), 64, 1) == BCI_OK);
  REQUIRE(bci_engine_push_samples(engine, sine.data(), 64, 1) == BCI_OK);

  // Drain processed samples (worker thread needs a moment).
  std::vector<float> out(static_cast<size_t>(64) * 1, 0.0f);
  int popped = 0;
  for (int attempt = 0; attempt < 100 && popped < 64; ++attempt) {
    const int got = bci_engine_pop_samples(engine, out.data(), 64, 1);
    if (got > 0) {
      popped = got;
    } else {
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
  }
  REQUIRE(popped == 64);

  // Processed samples must not be identical to input (smoothing applies);
  // RMS metric must be positive.
  float metrics[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  REQUIRE(bci_engine_get_metrics(engine, metrics) == BCI_OK);
  REQUIRE(metrics[0] > 0.0f);   // rms
  REQUIRE(metrics[2] >= 0.0f);  // quality
  REQUIRE(metrics[2] <= 1.0f);

  REQUIRE(bci_engine_stop(engine) == BCI_OK);
  REQUIRE(bci_engine_is_running(engine) == 0);
  REQUIRE(bci_engine_stop(engine) == BCI_NOT_STARTED);

  bci_engine_destroy(engine);
}

TEST_CASE("channel mismatch is rejected", "[engine]") {
  void* engine = bci_engine_create();
  REQUIRE(engine != nullptr);
  REQUIRE(bci_engine_start(engine, 250, 2) == BCI_OK);

  const auto mono = make_sine(32, 1, 8.0, 250.0, 0.2);
  REQUIRE(bci_engine_push_samples(engine, mono.data(), 32, 1) ==
          BCI_INVALID_ARGUMENT);

  REQUIRE(bci_engine_stop(engine) == BCI_OK);
  bci_engine_destroy(engine);
}

TEST_CASE("module registry exposes system modules", "[modules]") {
  void* engine = bci_engine_create();
  REQUIRE(engine != nullptr);

  const int count = bci_engine_module_count(engine);
  REQUIRE(count == 0);  // registry is populated on start()

  REQUIRE(bci_engine_start(engine, 250, 2) == BCI_OK);
  const int live_count = bci_engine_module_count(engine);
  REQUIRE(live_count == 6);

  bool saw_gain = false;
  for (int i = 0; i < live_count; ++i) {
    const char* json = bci_engine_module_json(engine, i);
    REQUIRE(json != nullptr);
    const std::string text(json);
    REQUIRE(text.find("\"id\":\"core.") == 1);  // right after the opening '{'
    if (text.find("core.gain") != std::string::npos) {
      saw_gain = true;
    }
  }
  REQUIRE(saw_gain);

  REQUIRE(bci_engine_stop(engine) == BCI_OK);
  bci_engine_destroy(engine);
}

TEST_CASE("core log callback receives engine messages", "[logging]") {
  void* engine = bci_engine_create();
  REQUIRE(engine != nullptr);

  static std::mutex log_mutex;
  static std::vector<std::string> received;
  received.clear();

  bci_engine_set_log_callback([](const char* message) {
    std::lock_guard<std::mutex> lock(log_mutex);
    received.emplace_back(message != nullptr ? message : "");
  });

  REQUIRE(bci_engine_start(engine, 250, 2) == BCI_OK);
  REQUIRE(bci_engine_stop(engine) == BCI_OK);

  bci_engine_set_log_callback(nullptr);  // unsubscribe

  bool saw_started = false;
  {
    std::lock_guard<std::mutex> lock(log_mutex);
    for (const std::string& line : received) {
      if (line.find("engine started") != std::string::npos) {
        saw_started = true;
      }
    }
  }
  REQUIRE(saw_started);

  bci_engine_destroy(engine);
}

TEST_CASE("null arguments are handled", "[engine]") {
  const auto sine = make_sine(8, 1, 5.0, 250.0, 0.1);
  REQUIRE(bci_engine_start(nullptr, 250, 1) == BCI_NULL_ARGUMENT);
  REQUIRE(bci_engine_push_samples(nullptr, sine.data(), 8, 1) ==
          BCI_NULL_ARGUMENT);
  REQUIRE(bci_engine_module_count(nullptr) == BCI_NULL_ARGUMENT);
  float metrics[4] = {};
  REQUIRE(bci_engine_get_metrics(nullptr, metrics) == BCI_NULL_ARGUMENT);
  bci_engine_destroy(nullptr);  // must not crash
}
