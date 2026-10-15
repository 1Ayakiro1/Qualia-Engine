"""Draft QSB2 data-plane codec; stdlib only, no JSON/base64 signal payloads.

This is a codec, NOT host protocol-v2 support or a shared-memory transport.
One authenticated/negotiated stream carries one edge, one block at a time.
Payload is float32 little-endian, interleaved or [channels, frames].
"""
from dataclasses import dataclass
import math
import struct
import zlib

HEADER = struct.Struct("<4sHHIIQQqdIIQQII")
MAX_CHUNK_BYTES = 1024 * 1024
MAX_BLOCK_BYTES = 256 * 1024 * 1024
DTYPE_FLOAT32 = 1


@dataclass(frozen=True)
class BlockInfo:
    sequence: int
    first_sample: int
    timestamp_ns: int
    sample_rate: float
    channels: int
    frames: int
    layout: int = 1  # 0 interleaved; 1 channel-major
    clock: int = 1   # 0 unknown; 1 monotonic; 2 Unix

    @property
    def size_bytes(self):
        return self.channels * self.frames * 4

    def validate(self, max_bytes=MAX_BLOCK_BYTES):
        for field in (self.sequence, self.first_sample):
            if type(field) is not int or not 0 <= field < 2**64:
                raise ValueError("Invalid sequence/sample index")
        if type(self.timestamp_ns) is not int or not -2**63 <= self.timestamp_ns < 2**63:
            raise ValueError("Invalid timestamp")
        if type(self.sample_rate) not in (int, float) or not math.isfinite(self.sample_rate) or self.sample_rate <= 0:
            raise ValueError("Invalid sample rate")
        if (type(self.channels) is not int or type(self.frames) is not int
                or not 0 < self.channels < 2**31 or not 0 < self.frames < 2**31
                or self.size_bytes > min(max_bytes, MAX_BLOCK_BYTES)):
            raise ValueError("Invalid dimensions or block byte limit")
        if self.first_sample > (2**64 - 1) - self.frames:
            raise ValueError("Sample index overflow")
        if type(self.layout) is not int or type(self.clock) is not int or self.layout not in (0, 1) or self.clock not in (0, 1, 2):
            raise ValueError("Invalid layout/clock")


def encode(info, payload, chunk_bytes=MAX_CHUNK_BYTES):
    """Yield (header, payload memoryview), suitable for sendmsg/writev or sendall.

    No concatenation/copy of payload. Keep the source allocation immutable until
    all views have been sent. Bytes must already be float32 LITTLE endian.
    """
    info.validate()
    if type(chunk_bytes) is not int or not 4 <= chunk_bytes <= MAX_CHUNK_BYTES or chunk_bytes % 4:
        raise ValueError("Invalid chunk size")
    view = memoryview(payload).cast("B")
    if len(view) != info.size_bytes:
        raise ValueError("Payload length does not match tensor dimensions")
    flags = info.layout | info.clock << 8
    for offset in range(0, len(view), chunk_bytes):
        chunk = view[offset:offset + chunk_bytes]
        header = HEADER.pack(b"QSB2", 2, HEADER.size, flags, DTYPE_FLOAT32,
                             info.sequence, info.first_sample, info.timestamp_ns,
                             info.sample_rate, info.channels, info.frames,
                             offset, info.size_bytes, len(chunk), zlib.crc32(chunk))
        yield header, chunk


def _read_exact(reader, count):
    result = bytearray(count)
    view = memoryview(result)
    offset = 0
    while offset < count:
        n = reader.readinto(view[offset:])
        if n is None:
            raise BlockingIOError("Use a blocking/deadline-bound binary stream")
        if n <= 0:
            raise EOFError("Truncated signal block")
        offset += n
    return result


def decode(reader, max_bytes=MAX_BLOCK_BYTES, after_sequence=None):
    """Read exactly one block from a binary file/socket.makefile('rb').

    Validates the complete header BEFORE allocating the block; CRC is verified
    chunk by chunk. Reads directly into the final allocation, not an unbounded
    chunk list. On any error close this stream (no attempted resynchronization).
    Set socket/read deadlines externally; this decoder has no scheduler.
    """
    if type(max_bytes) is not int or not 0 < max_bytes <= MAX_BLOCK_BYTES:
        raise ValueError("Invalid receiver budget")
    payload = None
    expected = None
    position = 0
    while True:
        (magic, version, size, flags, dtype, seq, first, timestamp, rate,
         channels, frames, offset, total, length, crc) = HEADER.unpack(_read_exact(reader, HEADER.size))
        if magic != b"QSB2" or version != 2 or size != HEADER.size or dtype != DTYPE_FLOAT32 or flags & ~0x301:
            raise ValueError("Invalid QSB2 header")
        info = BlockInfo(seq, first, timestamp, rate, channels, frames, flags & 1, flags >> 8)
        info.validate(max_bytes)
        if after_sequence is not None and seq <= after_sequence:
            raise ValueError("Replayed or out-of-order block")
        if (total != info.size_bytes or offset != position or length <= 0
                or length > MAX_CHUNK_BYTES or length % 4 or offset + length > total):
            raise ValueError("Invalid chunk dimensions/offset")
        if expected is None:
            expected = info
            payload = bytearray(total)
        elif info != expected:
            raise ValueError("Block metadata changed during assembly")
        chunk = memoryview(payload)[position:position + length]
        written = 0
        while written < length:
            n = reader.readinto(chunk[written:])
            if n is None:
                raise BlockingIOError("Use a blocking/deadline-bound binary stream")
            if n <= 0:
                raise EOFError("Truncated chunk")
            written += n
        if zlib.crc32(chunk) != crc:
            raise ValueError("Chunk CRC mismatch")
        position += length
        if position == total:
            return expected, payload
