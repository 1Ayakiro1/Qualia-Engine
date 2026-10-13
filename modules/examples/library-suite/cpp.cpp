#include "qualia.hpp"
extern "C" double qualia_square(double);
class LibraryModule final : public qualia::Module {
  int count_ = 0;
 public:
  void input(const std::string& port, const qualia::Json& value) override {
    if (port != "input") return;
    auto result = value;
    result["energy"] = qualia_square(value.at("mean").get<double>());
    result["cppCalls"] = ++count_;
    state({{"result", result}});
    emit("output", result);
  }
  void event(const std::string& id, const qualia::Json&) override {
    if (id == "crash") throw std::runtime_error("intentional fixture crash");
    if (id == "badOutput") emit("output", "invalid schema");
  }
};
int main() { LibraryModule module; return module.run(); }
