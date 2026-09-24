#include "bci_engine/version.h"

namespace bci {

const char* core_version() { return BCI_CORE_VERSION; }

int core_abi_version() { return BCI_CORE_ABI_VERSION; }

}  // namespace bci
