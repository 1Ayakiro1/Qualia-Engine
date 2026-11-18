#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "bci_engine/c_api.h"
#include "bci_engine/sample_block.hpp"

namespace bci::hal {

struct LslStreamInfo {
  std::string name;
  std::string type;
  std::string source_id;
  int channels = 0;
  double nominal_srate = 0.0;
  std::string channel_format;
};

/// Optional Lab Streaming Layer adapter. It loads liblsl at runtime, so the
/// core remains usable on systems where LSL is not installed.
class BCI_API LslInlet {
 public:
  LslInlet();
  ~LslInlet();
  LslInlet(const LslInlet&) = delete;
  LslInlet& operator=(const LslInlet&) = delete;

  static bool available();
  static std::vector<LslStreamInfo> discover(const std::string& type = {});
  bool open(const LslStreamInfo& stream, double timeout_seconds = 2.0);
  void close();
  bool opened() const { return inlet_ != nullptr; }
  const LslStreamInfo& info() const { return info_; }

  /// Pulls a float32 chunk into [destination]. LSL timestamps are normalized
  /// to the caller-selected clock in a future clock-sync layer; this v0.2
  /// adapter records the LSL timestamp and marks the block clock unknown.
  int pull(float* destination, int max_samples, double timeout_seconds,
           int* channels, double* timestamp_seconds);

 private:
  struct Api;
  std::unique_ptr<Api> api_;
  void* inlet_ = nullptr;
  LslStreamInfo info_;
};

}  // namespace bci::hal
