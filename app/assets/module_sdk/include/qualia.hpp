#pragma once
#include "json.hpp"
#include <iostream>
#include <stdexcept>
#include <string>
#include <cstddef>

namespace qualia {
// API layers: input/emit = internal module data contract, carried by the middle
// process-v1 host protocol. emit() never addresses a peer process directly; the
// host selects recipients using workspace links. External services/AI API are a
// separate integration boundary, not commands on this stream (api_layers.json).
using Json = nlohmann::json;
inline constexpr std::size_t kMaxFrameBytes = 1024 * 1024;
// stdout is protocol-only. Diagnostics belong on stderr.
class Module {
 public:
  virtual ~Module() = default;
  virtual void initialize(const Json&) {}
  virtual void parameters(const Json&) {}
  virtual void event(const std::string&, const Json&) {}
  virtual void input(const std::string&, const Json&) {}
  void state(const Json& values) { send({{"type", "state"}, {"values", values}}); }
  void emit(const std::string& port, const Json& value) {
    send({{"type", "output"}, {"port", port}, {"value", value}, {"hops", hops_}});
  }
  int run() {
    try {
      send({{"type", "ready"}, {"protocol", 1}});
      std::string line;
      while (read_line(line)) {
        auto message = Json::parse(line);
        const auto type = message.value("type", "");
        hops_ = 32;
        if (type == "stop") return 0;
        if (type == "init") initialize(message);
        else if (type == "parameters") parameters(message.at("values"));
        else if (type == "event") event(message.at("id"), message.value("value", Json()));
        else if (type == "input") {
          hops_ = message.value("hops", 0);
          input(message.at("port"), message.at("value"));
        }
      }
      return 0; // Closing the host's stdin terminates this instance.
    } catch (const std::exception& e) {
      std::cerr << e.what() << '\n';
      return 1;
    }
  }
 private:
  int hops_ = 32;
  static bool read_line(std::string& line) {
    line.clear();
    char ch;
    while (std::cin.get(ch)) {
      if (ch == '\n') return true;
      if (line.size() >= kMaxFrameBytes) throw std::runtime_error("IPC frame too large");
      line += ch;
    }
    return false;
  }
  static void send(const Json& message) {
    const auto frame = message.dump();
    if (frame.size() > kMaxFrameBytes) throw std::runtime_error("IPC frame too large");
    std::cout << frame << '\n' << std::flush;
  }
};
} // namespace qualia
