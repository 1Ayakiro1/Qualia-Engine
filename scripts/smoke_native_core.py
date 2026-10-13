#!/usr/bin/env python3
"""Load the library actually shipped in the desktop bundle and verify C ABI."""
import ctypes
import pathlib
import platform
import re

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
    assert library.bci_engine_stop(engine) == 0
finally:
    library.bci_engine_destroy(engine)
print("Native engine create/start/stop/destroy OK")
