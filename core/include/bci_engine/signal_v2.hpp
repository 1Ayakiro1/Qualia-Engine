// Draft binary data-plane codec. Not an implementation of host negotiation/SHM.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

#include "bci_engine/sample_block.hpp"
#include "bci_engine/c_api.h"

namespace bci::wire {

constexpr size_t kHeaderBytes = 80;
constexpr size_t kMaxChunkBytes = 1024 * 1024;

struct ChunkHeader {
  SampleBlock info;
  uint64_t sequence = 0;
  uint64_t offset = 0;
  uint32_t length = 0;
  uint32_t crc = 0;
};

// Header and float32 payload are little endian. Encode copies ONLY 80 bytes of
// metadata; caller supplies a view into the immutable outgoing allocation.
BCI_API std::array<uint8_t, kHeaderBytes> encode(const ChunkHeader& chunk);
BCI_API ChunkHeader decode(const uint8_t* data, size_t size,
                   size_t max_block_bytes = SampleBlock::kMaxBytes);
BCI_API uint32_t crc32(const uint8_t* data, size_t size);

// One bounded contiguous block at a time. Reject changed metadata, gaps,
// duplicates, corrupt CRC, replay and overflow before allocation/copy.
// Caller reads a header, validates with decode, reads at most kMaxChunkBytes,
// then calls append; it MUST impose a connection/assembly deadline itself.
class BCI_API Assembler {
 public:
  explicit Assembler(size_t max_bytes = SampleBlock::kMaxBytes);
  void append(const ChunkHeader& header, const uint8_t* payload, size_t size);
  bool complete() const;
  SampleBlockPtr take();
  void reset();

 private:
  size_t max_bytes_;
  SampleBlockPtr block_;
  uint64_t sequence_ = 0;
  uint64_t last_sequence_ = 0;
  size_t offset_ = 0;
  bool received_ = false;
};

}  // namespace bci::wire
