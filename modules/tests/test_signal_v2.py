"""Wire codec conformance, without NumPy/PyTorch or network downloads."""
import dataclasses
import io
import pathlib
import socket
import struct
import sys
import threading
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "app/assets/module_sdk"))
from signal_v2 import BlockInfo, HEADER, MAX_BLOCK_BYTES, decode, encode


class Fragmented(io.BytesIO):
    def readinto(self, view):
        return super().readinto(view[:min(7, len(view))])


class CodecTests(unittest.TestCase):
    def setUp(self):
        self.info = BlockInfo(7, 1234, -456789000, 250.0, 2, 4)
        self.payload = struct.pack("<8f", 1, 2, 3, 4, 10, 20, 30, 40)

    def wire(self, info=None, payload=None, **kwargs):
        return b"".join(bytes(h) + bytes(p) for h, p in encode(info or self.info, self.payload if payload is None else payload, **kwargs))

    def test_cpp_golden_header(self):
        header, view = next(encode(self.info, self.payload))
        self.assertEqual(HEADER.size, 80)
        self.assertEqual(header.hex(), "515342320200500001010000010000000700000000000000d204000000000000f8f3c5e4ffffffff0000000000406f400200000004000000000000000000000020000000000000002000000049d32de2")
        self.assertIs(view.obj, self.payload)
        actual, payload = decode(Fragmented(header + view))
        self.assertEqual(actual, self.info)
        self.assertEqual(payload, self.payload)

    def test_large_tensor_fragmented_multichunk(self):
        info = dataclasses.replace(self.info, frames=140000)
        payload = bytes(info.size_bytes)
        actual, data = decode(Fragmented(self.wire(info, payload)))
        self.assertEqual(actual, info)
        self.assertEqual(data, payload)

    def test_reject_before_allocating(self):
        good = list(HEADER.unpack(self.wire()[:HEADER.size]))
        for index, value in ((0, b"BAD!"), (1, 1), (2, 0), (3, 2), (3, 0x400), (4, 2),
                             (8, float('nan')), (8, 0), (9, 0xffffffff), (10, 0),
                             (11, 4), (12, MAX_BLOCK_BYTES + 4), (13, 0), (13, 1048580)):
            fields = good.copy()
            fields[index] = value
            with self.subTest(index=index, value=value), self.assertRaises(ValueError):
                decode(io.BytesIO(HEADER.pack(*fields)))
        with self.assertRaises(ValueError):
            decode(io.BytesIO(self.wire()), max_bytes=16)
        with self.assertRaises(ValueError):
            decode(io.BytesIO(self.wire()), after_sequence=7)

    def test_crc_truncation_and_changed_metadata(self):
        wire = bytearray(self.wire())
        wire[-1] ^= 1
        with self.assertRaises(ValueError):
            decode(io.BytesIO(wire))
        for end in (0, 79, 80, len(wire)-1):
            with self.subTest(end=end), self.assertRaises(EOFError):
                decode(io.BytesIO(self.wire()[:end]))
        chunks = list(encode(self.info, self.payload, chunk_bytes=16))
        fields = list(HEADER.unpack(chunks[1][0]))
        fields[5] += 1
        wire = chunks[0][0] + chunks[0][1] + HEADER.pack(*fields) + chunks[1][1]
        with self.assertRaises(ValueError):
            decode(io.BytesIO(wire))

    def test_consecutive_socket_blocks(self):
        reader, writer = socket.socketpair()
        reader.settimeout(3)
        writer.settimeout(3)
        errors = []
        def send():
            try:
                for seq in (7, 8):
                    for header, payload in encode(dataclasses.replace(self.info, sequence=seq), self.payload, 4):
                        writer.sendall(header)
                        writer.sendall(payload)
            except Exception as error:
                errors.append(error)
            finally:
                writer.close()
        worker = threading.Thread(target=send)
        worker.start()
        try:
            with reader, reader.makefile('rb') as stream:
                first, data = decode(stream)
                second, other = decode(stream, after_sequence=first.sequence)
                self.assertEqual((first.sequence, second.sequence), (7, 8))
                self.assertEqual(data, other)
        finally:
            reader.close()
            worker.join(5)
        self.assertFalse(worker.is_alive())
        self.assertEqual(errors, [])

    def test_invalid_dimensions_and_lengths(self):
        for change in ({'channels': 0}, {'frames': -1}, {'frames': 2**31}, {'clock': 3},
                       {'layout': True}, {'sequence': -1}, {'sample_rate': float('inf')}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                list(encode(dataclasses.replace(self.info, **change), self.payload))
        with self.assertRaises(ValueError):
            list(encode(self.info, self.payload[:-1]))


if __name__ == '__main__':
    unittest.main()
