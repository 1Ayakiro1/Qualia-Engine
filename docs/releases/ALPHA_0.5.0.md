# Alpha 0.5.0

## Changes

- Built-in Workspace IF, filter, select-fields, schema-validation and bounded
  script blocks, with separate Explorer/search/icons and visibility filters.
- Language-neutral `process-v1` offline `.qmod` packages with bundled runtimes,
  launch arguments, file integrity checks and port schemas. Legacy C++ packages
  remain compatible. Only declared parameters are forwarded to modules.
- Explorer module management and independent workspace transfers.
- macOS Xcode builds automatically embed the native core; Windows packages
  verify the core DLL. GitHub Actions desktop build/test matrix for three OSes.
- Authoring guide for AI assistants and C++/Python/Go examples.

## Verification scenarios

Library integration fixtures are in `modules/examples/library-suite`:

1. Python bundled CPython + NumPy/OpenBLAS + ctypes loading a packaged C library.
2. C++ nlohmann/json + packaged shared C library via relocatable `$ORIGIN` RPATH.
3. Static Go module using encoding/json and crypto/sha256 libraries.
4. Actual engine routing Python → field allowlist → C++ → Go, numerical results,
   independent PIDs/counters, schema rejection and recovery on subsequent inputs.
5. Deliberate crash isolates the failing node; disable/enable creates fresh state.
6. Missing shared library is rejected by integrity validation before launch.
7. Installed payload relocated from build directory, no system interpreter/PATH.

Prepare and run locally (Linux x64, build tools + NumPy wheel required only on
the build machine):

```bash
python3 -m pip install --only-binary=:all: numpy==2.4.6
python3 modules/examples/library-suite/prepare.py /path/to/fixtures
cd app
QUALIA_LIBRARY_FIXTURES=/path/to/fixtures flutter test
```

System NumPy variants may use runtime-discovered BLAS backends (e.g. FlexiBLAS)
that `ldd` does not detect. Use a self-contained wheel and verify its actual
offline execution; merely copying ELF dependencies is insufficient.
The fixture builder downloads nothing and makes no runtime installations.
Test runtime copies are not curated redistributable distributions: review licenses
and platform baseline before independently distributing module binaries.

## Alpha limitations

- Executable `.qmod` currently supports **Linux x64 only**. Windows/macOS engine
  builds do not execute Linux ELF packages. Built-in logic is platform-neutral.
- Modules are trusted user processes, not security sandboxes.
- JSON ports are for bounded control data, not hard-real-time EEG/SampleBlock.
- Windows portable ZIP has no Authenticode signature. macOS application ZIP is
  ad-hoc signed, not Developer-ID notarized; Gatekeeper may require user approval.
- CI Linux artifacts marked `stock` use standard Flutter GTK; the locally built
  Linux artifacts use the native-vsync patched embedder. Neither is mislabeled.
- Source archives are provided with the release; desktop binaries do not require
  development toolchains. Android/iOS are not part of this desktop release.
