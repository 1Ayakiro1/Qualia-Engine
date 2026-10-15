# Qualia Engine 0.5.2-dev.1 — development checkpoint

**Not a release. The seven-subsystem 0.5.2 acceptance gate is not met.**

- Branch: `feat/ml-runtime-v2`
- Source commit: `a67cc1beaeb0d683497fbe22545de1911f6f1928`.
- Linux binaries: production code from `25e628d5dcae7ab484636a6d3f9c010ab1ad55a3`.
  The subsequent source commit changes only CI and the native test loader.
- No release tag or GitHub Release created. Published 0.5.1 unchanged.

## Implemented at this checkpoint

Native ABI 3 owned/wrapped timestamped float32 blocks, channel-major/interleaved
layouts, move-only native push/process/pop, bounded block/byte queues with
every/drop-oldest/latest-only policies. Legacy samples API preserved, including
correct FIFO partial reads. C++/Python draft QSB2 chunk codecs agree on wire header.

**Not implemented:** host protocol/schema v2, module binary/SHM routes, HAL,
runtime CAS, lifecycle services/jobs/resources, persistent datasets/Model Registry,
ML UI and signed remote installation/enforced capabilities. See the complete
`docs/ML_RUNTIME_V2.md` inside the source archive. The codec is not a transport.

## Local Linux validation

- Native CTest: 19 cases, 336 assertions pass; backpressure suite repeated 100 times.
- Flutter: 145 pass, 3 opt-in fixture tests skipped. Native library actually loaded;
  ABI ownership, pointer identity, metadata and layout checked from Dart FFI.
- Python wire codec: 6 tests pass (fragmented input, >1 MiB tensor, CRC/truncation,
  changed metadata, malformed headers, socket blocks).
- Analyzer and version consistency pass.
- Public C header compiles as C11; metadata struct is 48 bytes.
- Malformed-stream smoke: 10,000 deterministic mutations with 1024-byte budget;
  8,994 rejected, 1,006 structurally valid metadata mutations accepted.
- Native-vsync timing/bridge tests pass.
- Packaged core smoke: create/start/owned-block push/pop/release/stop/destroy passes;
  verifies exact handle and payload pointer identity through the native pipeline.
- AppImage launches and remains running for 10 seconds until explicit timeout.
  GTK emitted ATK/cursor-theme warnings; no fatal startup error observed.
- AppImage/tarball native core is byte-identical to the tested Flutter bundle.
- Source ZIP/tar.gz: 274 files byte-identical to source commit, with SOURCE_COMMIT.
  Clean extracted sources pass native build/CTest, analyzer, 145 Flutter tests
  (with native FFI execution required) and 6 Python codec tests.

Local ASan/UBSan is **not verified**: environment lacks libasan, so compiler
link check fails before project build. Separate sanitizer jobs are configured in
CI. Windows/macOS execution and artifacts require their CI jobs; do not interpret
the Linux results as proof of cross-platform behavior or isolation.

CI for the source commit:
https://github.com/1Ayakiro1/Qualia-Engine/actions/runs/38755451654

That run was cancelled by a newer push after its sanitizer jobs and all three
desktop test suites had completed successfully; the current commit has a new
run linked from the repository Actions page. This file is **not a claim that
the current cross-platform CI run succeeded**.

## Files

- `Qualia-Engine-0.5.2-dev.1-x86_64.AppImage`
- `Qualia-Engine-0.5.2-dev.1-linux-x64.tar.gz`
- `binary/bci_engine` (run alongside the complete binary directory)
- `Qualia-Engine-0.5.2-dev.1-source.zip`
- `Qualia-Engine-0.5.2-dev.1-source.tar.gz`
- `SHA256SUMS`
