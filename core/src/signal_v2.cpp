#include "bci_engine/signal_v2.hpp"

#include <cstring>
#include <limits>
#include <stdexcept>

namespace bci::wire {
namespace {

void put(uint8_t* out, uint64_t value, size_t count) {
  for (size_t i = 0; i < count; ++i) out[i] = static_cast<uint8_t>(value >> (8 * i));
}
uint64_t get(const uint8_t* data, size_t count) {
  uint64_t value = 0;
  for (size_t i = 0; i < count; ++i) value |= uint64_t(data[i]) << (8 * i);
  return value;
}
void validate(const ChunkHeader& h, size_t max_bytes) {
  if (!h.info.valid_metadata() || h.info.bytes() > max_bytes ||
      h.length == 0 || h.length > kMaxChunkBytes || h.length % 4 != 0 ||
      h.offset % 4 != 0 || h.offset > h.info.bytes() ||
      h.length > h.info.bytes() - h.offset) {
    throw std::invalid_argument("Invalid signal chunk dimensions/budget");
  }
}
bool same(const SampleBlock& a, const SampleBlock& b) {
  return a.frames == b.frames && a.channels == b.channels &&
         a.sample_rate == b.sample_rate && a.first_sample == b.first_sample &&
         a.timestamp_ns == b.timestamp_ns && a.layout == b.layout && a.clock == b.clock;
}
bool little_endian() {
  const uint16_t value = 1;
  return *reinterpret_cast<const uint8_t*>(&value) == 1;
}

}  // namespace

uint32_t crc32(const uint8_t* data, size_t size) {
  uint32_t crc = 0xffffffffu;
  for (size_t i = 0; i < size; ++i) {
    crc ^= data[i];
    for (int bit = 0; bit < 8; ++bit) {
      crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
  }
  return crc ^ 0xffffffffu;
}

std::array<uint8_t, kHeaderBytes> encode(const ChunkHeader& h) {
  validate(h, SampleBlock::kMaxBytes);
  std::array<uint8_t, kHeaderBytes> result{};
  auto* p = result.data();
  std::memcpy(p, "QSB2", 4);
  put(p + 4, 2, 2);
  put(p + 6, kHeaderBytes, 2);
  put(p + 8, static_cast<uint32_t>(h.info.layout) |
                 (static_cast<uint32_t>(h.info.clock) << 8), 4);
  put(p + 12, 1, 4); // dtype float32
  put(p + 16, h.sequence, 8);
  put(p + 24, h.info.first_sample, 8);
  uint64_t timestamp, rate;
  static_assert(sizeof(double) == 8 && sizeof(float) == 4 &&
                std::numeric_limits<float>::is_iec559 &&
                std::numeric_limits<double>::is_iec559, "IEEE754 types required");
  std::memcpy(&timestamp, &h.info.timestamp_ns, 8);
  std::memcpy(&rate, &h.info.sample_rate, 8);
  put(p + 32, timestamp, 8);
  put(p + 40, rate, 8);
  put(p + 48, static_cast<uint32_t>(h.info.channels), 4);
  put(p + 52, static_cast<uint32_t>(h.info.frames), 4);
  put(p + 56, h.offset, 8);
  put(p + 64, h.info.bytes(), 8);
  put(p + 72, h.length, 4);
  put(p + 76, h.crc, 4);
  return result;
}

ChunkHeader decode(const uint8_t* p, size_t size, size_t max_block_bytes) {
  if (!p || size != kHeaderBytes || std::memcmp(p, "QSB2", 4) != 0 ||
      get(p + 4, 2) != 2 || get(p + 6, 2) != kHeaderBytes ||
      get(p + 12, 4) != 1 || (get(p + 8, 4) & ~uint64_t(0x301)) != 0 ||
      max_block_bytes == 0 || max_block_bytes > SampleBlock::kMaxBytes) {
    throw std::invalid_argument("Invalid QSB2 header");
  }
  ChunkHeader h;
  h.info.layout = static_cast<SampleLayout>(get(p + 8, 4) & 1);
  h.info.clock = static_cast<SampleClock>(get(p + 8, 4) >> 8);
  h.sequence = get(p + 16, 8);
  h.info.first_sample = get(p + 24, 8);
  auto timestamp = get(p + 32, 8), rate = get(p + 40, 8);
  std::memcpy(&h.info.timestamp_ns, &timestamp, 8);
  std::memcpy(&h.info.sample_rate, &rate, 8);
  const auto channels = get(p + 48, 4), frames = get(p + 52, 4);
  if (channels > INT32_MAX || frames > INT32_MAX) {
    throw std::invalid_argument("Invalid signal dimensions");
  }
  h.info.channels = static_cast<int>(channels);
  h.info.frames = static_cast<int>(frames);
  h.offset = get(p + 56, 8);
  h.length = static_cast<uint32_t>(get(p + 72, 4));
  h.crc = static_cast<uint32_t>(get(p + 76, 4));
  validate(h, max_block_bytes);
  if (get(p + 64, 8) != h.info.bytes()) {
    throw std::invalid_argument("Signal payload length mismatch");
  }
  return h;
}

Assembler::Assembler(size_t max_bytes) : max_bytes_(max_bytes) {
  if (max_bytes == 0 || max_bytes > SampleBlock::kMaxBytes) {
    throw std::invalid_argument("Invalid receiver budget");
  }
}

void Assembler::append(const ChunkHeader& h, const uint8_t* payload, size_t size) {
  validate(h, max_bytes_);
  if (!payload || size != h.length || h.offset != offset_ ||
      (received_ && h.sequence <= last_sequence_) ||
      (block_ && (complete() || h.sequence != sequence_ || !same(h.info, block_->view())))) {
    throw std::invalid_argument("Out-of-order or inconsistent signal chunk");
  }
  if (crc32(payload, size) != h.crc) throw std::invalid_argument("Signal CRC mismatch");
  if (!block_) {
    block_ = std::make_unique<OwnedSampleBlock>(h.info);
    sequence_ = h.sequence;
  }
  auto* destination = reinterpret_cast<uint8_t*>(block_->view().data) + offset_;
  if (little_endian()) {
    std::memcpy(destination, payload, size);
  } else {
    for (size_t i = 0; i < size; i += 4) {
      for (size_t byte = 0; byte < 4; ++byte) destination[i + byte] = payload[i + 3 - byte];
    }
  }
  offset_ += size;
}

bool Assembler::complete() const { return block_ && offset_ == block_->bytes(); }

SampleBlockPtr Assembler::take() {
  if (!complete()) throw std::logic_error("Signal block incomplete");
  last_sequence_ = sequence_;
  received_ = true;
  offset_ = 0;
  return std::move(block_);
}

void Assembler::reset() {
  block_.reset();
  offset_ = 0;
  // Reset assembly, not replay protection. New stream -> new Assembler.
}

}  // namespace bci::wire
