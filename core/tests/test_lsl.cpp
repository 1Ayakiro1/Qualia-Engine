#include "catch.hpp"
#include "bci_engine/c_api.h"
#include <limits>
#include <string>

TEST_CASE("LSL host adapter uses correct signatures and bounded chunks", "[lsl]") {
  REQUIRE(bci_lsl_available() == 1);
  char json[4096] = {};
  REQUIRE(bci_lsl_discover_json("", json, sizeof(json)) == 1);
  REQUIRE(std::string(json).find("Fixture \\\"EEG\\\"") != std::string::npos);
  char tiny[2] = {'x', 'x'};
  REQUIRE(bci_lsl_discover_json("EEG", tiny, sizeof(tiny)) == BCI_QUEUE_OVERFLOW);
  REQUIRE(tiny[0] == '\0');
  auto* inlet = bci_lsl_create();
  REQUIRE(inlet != nullptr);
  REQUIRE(bci_lsl_open_source(inlet, "fixture", 1) == BCI_OK);
  REQUIRE(std::string(bci_lsl_info_json(inlet)).find("250") != std::string::npos);
  float values[9] = {};
  values[8] = 12345;
  int channels = 0;
  double timestamp = 0;
  REQUIRE(bci_lsl_pull(inlet, values, 7, 0, &channels, &timestamp) == 3);
  REQUIRE(channels == 2);
  REQUIRE(timestamp == Approx(10));
  REQUIRE(values[4] == 2);
  REQUIRE(values[5] == -2);
  REQUIRE(values[8] == 12345);
  REQUIRE(bci_lsl_pull(inlet, values, -1, 0, &channels, &timestamp) == BCI_INVALID_ARGUMENT);
  REQUIRE(bci_lsl_pull(inlet, values, 8, std::numeric_limits<double>::quiet_NaN(),
                       &channels, &timestamp) == BCI_INVALID_ARGUMENT);
  bci_lsl_close(inlet);
  REQUIRE(bci_lsl_pull(inlet, values, 8, 0, &channels, &timestamp) == 0);
  bci_lsl_destroy(inlet);
  bci_lsl_destroy(nullptr);
}
