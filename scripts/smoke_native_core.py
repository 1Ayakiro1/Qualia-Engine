#!/usr/bin/env python3
"""Load the library actually shipped in the desktop bundle and verify C ABI."""
import ctypes
import pathlib
import platform
import re
import time

root = pathlib.Path(__file__).resolve().parent.parent
relative = {
    "Linux": "app/build/linux/x64/release/bundle/lib/libbci_engine_core.so",
    "Windows": "app/build/windows/x64/runner/Release/bci_engine_core.dll",
    "Darwin": "app/build/macos/Build/Products/Release/bci_engine.app/Contents/Frameworks/libbci_engine_core.dylib",
}[platform.system()]
library = ctypes.CDLL(str(root / relative))
library.bci_engine_core_version.restype = ctypes.c_char_p
expected = (root / "VERSION").read_text().strip()
actual = library.bci_engine_core_version().decode()
assert actual == expected, f"Native version mismatch: {actual} != {expected}"
print(f"Bundled native core OK: {relative}, version {actual}")
header = (root / 'core/include/bci_engine/version.h').read_text()
expected_abi = int(re.search(r'#define BCI_CORE_ABI_VERSION (\d+)', header).group(1))
assert library.bci_engine_abi_version() == expected_abi
library.bci_engine_create.restype = ctypes.c_void_p
library.bci_engine_start.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
library.bci_engine_stop.argtypes = [ctypes.c_void_p]
library.bci_engine_destroy.argtypes = [ctypes.c_void_p]
engine = library.bci_engine_create()
assert engine, "Native engine allocation failed"
try:
    assert library.bci_engine_start(engine, 256, 8) == 0
    if expected_abi >= 3:
        class BlockInfo(ctypes.Structure):
            _fields_ = [('struct_size', ctypes.c_uint32), ('layout', ctypes.c_uint32),
                        ('frames', ctypes.c_int32), ('channels', ctypes.c_int32),
                        ('sample_rate', ctypes.c_double), ('first_sample', ctypes.c_uint64),
                        ('timestamp_ns', ctypes.c_int64), ('clock', ctypes.c_uint32),
                        ('reserved', ctypes.c_uint32)]
        library.bci_block_create.argtypes = [ctypes.POINTER(BlockInfo)]
        library.bci_block_create.restype = ctypes.c_void_p
        library.bci_block_data.argtypes = [ctypes.c_void_p]
        library.bci_block_data.restype = ctypes.POINTER(ctypes.c_float)
        library.bci_block_release.argtypes = [ctypes.c_void_p]
        library.bci_block_get_info.argtypes = [ctypes.c_void_p, ctypes.POINTER(BlockInfo)]
        library.bci_engine_push_block.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
        library.bci_engine_pop_block.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
        info = BlockInfo(ctypes.sizeof(BlockInfo), 1, 4, 8, 256.0, 99, 123456000, 1, 0)
        handle = ctypes.c_void_p(library.bci_block_create(ctypes.byref(info)))
        output = ctypes.c_void_p()
        try:
            assert handle.value, 'Block allocation failed'
            original = handle.value
            samples = library.bci_block_data(handle)
            address = ctypes.addressof(samples.contents)
            for channel in range(8):
                for frame in range(4):
                    samples[channel * 4 + frame] = float(channel + 1)
            assert library.bci_engine_push_block(engine, ctypes.byref(handle)) == 0
            assert handle.value is None, 'Push must transfer ownership'
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                code = library.bci_engine_pop_block(engine, ctypes.byref(output))
                if code == 0:
                    break
                assert code == -7, f'Unexpected block pop code {code}'
                time.sleep(.001)
            assert output.value == original, 'Block handle changed in core'
            result = library.bci_block_data(output)
            assert ctypes.addressof(result.contents) == address, 'Payload copied in core'
            for channel in range(8):
                assert abs(result[channel * 4 + 1] - float(channel + 1)) < 1e-5
            actual = BlockInfo(struct_size=ctypes.sizeof(BlockInfo))
            assert library.bci_block_get_info(output, ctypes.byref(actual)) == 0
            assert (actual.timestamp_ns, actual.first_sample, actual.layout, actual.clock) == (123456000, 99, 1, 1)
            print('Bundled native block ABI OK: same handle/pointer, channel-major data, timestamps')
        finally:
            library.bci_block_release(output)
            library.bci_block_release(handle)
    assert library.bci_engine_stop(engine) == 0
finally:
    library.bci_engine_destroy(engine)
print("Native engine create/start/stop/destroy OK")
