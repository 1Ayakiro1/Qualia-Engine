// Ayakiro BCI Engine — module contract.
//
// A module is one processing stage inside the engine pipeline. System modules
// live in the core; user/researcher modules are loaded from a sandbox in a
// later version (see docs/MODULES.md).
#pragma once

#include <memory>
#include <vector>

#include "bci_engine/core.hpp"

namespace bci {

class EngineContext;

class IModule {
 public:
  virtual ~IModule() = default;

  virtual const ModuleInfo& info() const = 0;

  // Called once when the engine starts, before the first process() call.
  virtual void init(EngineContext& ctx) { (void)ctx; }

  // Called for every block. May modify the samples in place.
  virtual void process(SampleBlock& block) = 0;
};

// Builds the working native processing pipeline:
// acquisition passthrough -> gain -> smoothing -> diagnostics.
std::vector<std::unique_ptr<IModule>> create_default_pipeline(
    EngineMetrics& metrics);

// Human-readable category key ("acquisition", "dsp", ...).
const char* module_category_name(int category);

}  // namespace bci
