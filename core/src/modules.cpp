// System modules of the v0.1 skeleton (part 1: acquisition + dsp).
//
// Every entry is intentionally minimal but real: the module contract
// (IModule) is the same that user/researcher modules will use later.
#include "modules.hpp"

#include <cmath>
#include <string>
#include <vector>

#include "fft.hpp"

namespace bci {

const char* module_category_name(int category) {
  switch (static_cast<ModuleCategory>(category)) {
    case ModuleCategory::kAcquisition:
      return "acquisition";
    case ModuleCategory::kDsp:
      return "dsp";
    case ModuleCategory::kFeature:
      return "feature";
    case ModuleCategory::kInference:
      return "inference";
    case ModuleCategory::kOutput:
      return "output";
    case ModuleCategory::kUtility:
      return "utility";
  }
  return "utility";
}

namespace {

class PassthroughModule final : public IModule {
 public:
  const ModuleInfo& info() const override { return info_; }
  void process(SampleBlock& block) override {
    (void)block;  // v0.1: raw HAL frames enter the pipeline here as-is.
  }

 private:
  ModuleInfo info_{"core.acquisition_passthrough",
                   "Прохождение сырого сигнала",
                   "Точка входа сырых кадров HAL в конвейер (v0.1 — passthrough).",
                   "0.1.0",
                   static_cast<int>(ModuleCategory::kAcquisition),
                   true};
};

class GainModule final : public IModule {
 public:
  const ModuleInfo& info() const override { return info_; }
  void process(SampleBlock& block) override {
    if (gain_ == 1.0f) {
      return;
    }
    const size_t count = static_cast<size_t>(block.frames) * block.channels;
    for (size_t i = 0; i < count; ++i) {
      block.data[i] *= gain_;
    }
  }

  // Parameter exposed for the future params API (bci_engine_set_param).
  float gain_ = 1.0f;

 private:
  ModuleInfo info_{"core.gain",
                   "Усиление",
                   "Масштабирование сигнала на коэффициент усиления.",
                   "0.1.0",
                   static_cast<int>(ModuleCategory::kDsp),
                   true};
};

class SmoothingModule final : public IModule {
 public:
  const ModuleInfo& info() const override { return info_; }
  void process(SampleBlock& block) override {
    // Per-channel exponential moving average: y = a*y + (1-a)*x.
    if (prev_.size() != static_cast<size_t>(block.channels)) {
      prev_.assign(static_cast<size_t>(block.channels), 0.0f);
      primed_.assign(static_cast<size_t>(block.channels), false);
    }
    const int ch = block.channels;
    for (int f = 0; f < block.frames; ++f) {
      for (int c = 0; c < ch; ++c) {
        const float x = block.data[f * ch + c];
        if (!primed_[c]) {
          prev_[c] = x;
          primed_[c] = true;
        } else {
          prev_[c] = alpha_ * prev_[c] + (1.0f - alpha_) * x;
        }
        block.data[f * ch + c] = prev_[c];
      }
    }
  }

  float alpha_ = 0.2f;  // smoothing factor (0 = no smoothing, 1 = frozen)

 private:
  ModuleInfo info_{"core.smoothing",
                   "Сглаживание (EMA)",
                   "Экспоненциальное сглаживание по каналам; снижает высокочастотный шум.",
                   "0.1.0",
                   static_cast<int>(ModuleCategory::kDsp),
                   true};

  std::vector<float> prev_;
  std::vector<bool> primed_;
};

class DiagnosticsModule final : public IModule {
 public:
  explicit DiagnosticsModule(EngineMetrics& metrics) : metrics_(metrics) {}

  const ModuleInfo& info() const override { return info_; }
  void init(EngineContext& ctx) override { sample_rate_ = ctx.sample_rate(); }

  void process(SampleBlock& block) override {
    const int ch = block.channels > 0 ? block.channels : 1;

    // RMS over all channels of this block.
    double sum_squares = 0.0;
    const size_t count = static_cast<size_t>(block.frames) * ch;
    for (size_t i = 0; i < count; ++i) {
      sum_squares += static_cast<double>(block.data[i]) * block.data[i];
    }
    const double rms = std::sqrt(sum_squares / static_cast<double>(count));
    metrics_.rms.store(static_cast<float>(rms), std::memory_order_relaxed);

    // Heuristic quality: penalize silence and saturation.
    double quality = 0.0;
    if (rms > 1e-6 && rms < 2.0) {
      quality = 1.0 - std::fabs(std::log10(rms + 1e-6) + 3.0) / 6.0;
      if (quality < 0.0) quality = 0.0;
      if (quality > 1.0) quality = 1.0;
    }
    metrics_.quality.store(static_cast<float>(quality),
                           std::memory_order_relaxed);

    // Spectrum of channel 0 over a Hann-windowed 256-sample window.
    for (int f = 0; f < block.frames; ++f) {
      window_[write_pos_] = block.data[f * ch];
      write_pos_ = (write_pos_ + 1) % kWindow;
      if (write_pos_ == 0) {
        filled_ = true;
      }
      if (filled_ && write_pos_ == 0) {
        update_spectrum();
      }
    }
  }

 private:
  static constexpr size_t kWindow = 256;

  void update_spectrum() {
    double framed[kWindow];
    for (size_t i = 0; i < kWindow; ++i) {
      const double hann =
          0.5 * (1.0 - std::cos(2.0 * 3.14159265358979323846 *
                                static_cast<double>(i) / (kWindow - 1)));
      framed[i] = window_[i] * hann;
    }
    const auto magnitude = fft_magnitude(framed, kWindow);
    size_t peak_bin = 1;
    double peak_value = 0.0;
    for (size_t bin = 1; bin < magnitude.size(); ++bin) {
      if (magnitude[bin] > peak_value) {
        peak_value = magnitude[bin];
        peak_bin = bin;
      }
    }
    const double freq =
        static_cast<double>(peak_bin) * sample_rate_ / kWindow;
    metrics_.peak_freq.store(static_cast<float>(freq),
                             std::memory_order_relaxed);
  }

  ModuleInfo info_{"core.diagnostics",
                   "Диагностика сигнала",
                   "RMS, доминирующая частота спектра и эвристическое качество сигнала.",
                   "0.1.0",
                   static_cast<int>(ModuleCategory::kFeature),
                   true};

  EngineMetrics& metrics_;
  double sample_rate_ = 250.0;
  double window_[kWindow] = {};
  size_t write_pos_ = 0;
  bool filled_ = false;
};

}  // namespace

std::vector<std::unique_ptr<IModule>> create_default_pipeline(
    EngineMetrics& metrics) {
  std::vector<std::unique_ptr<IModule>> pipeline;
  pipeline.push_back(std::make_unique<PassthroughModule>());
  pipeline.push_back(std::make_unique<GainModule>());
  pipeline.push_back(std::make_unique<SmoothingModule>());
  pipeline.push_back(std::make_unique<DiagnosticsModule>(metrics));
  return pipeline;
}

}  // namespace bci
