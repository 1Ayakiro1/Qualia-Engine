#include "qualia.hpp"

// One instance of this class per OS process / workspace node.
class Gain final : public qualia::Module {
 public:
  void initialize(const qualia::Json& message) override {
    parameters(message.at("parameters"));
  }
  void parameters(const qualia::Json& values) override {
    gain_ = values.value("gain", 1.0);
    sample_ = values.value("sample", 1.0);
  }
  void event(const std::string& id, const qualia::Json&) override {
    if (id == "run") process(sample_);
  }
  void input(const std::string& port, const qualia::Json& value) override {
    if (port == "input" && value.is_number()) process(value.get<double>());
  }
 private:
  double gain_ = 1.0, sample_ = 1.0;
  void process(double value) {
    const double result = value * gain_;
    state({{"result", result}});
    emit("output", result);
  }
};
int main() { Gain module; return module.run(); }
