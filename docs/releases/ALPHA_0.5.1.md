# Alpha 0.5.1

## Changes

- JSON/NDJSON frames and manifests up to **1 MiB** (1,048,576 UTF-8 bytes;
  frame delimiter LF is not included).
- `.qmod` packages up to **2 GiB** (2,147,483,648 bytes including ZIP headers).
  Installation reads payloads in chunks, verifies CRC and SHA-256 integrity,
  and inspects native executable headers without loading entire binaries.
- Optional **TCP transport** using the same ready/init/input/output protocol.
  Explicit IP/DNS and ports 1–65535 are supported; loopback port 0 allocates a
  per-instance port via environment variables or launch-argument placeholders.
- **Portable packages**: one script/bytecode payload shared by desktop ABIs,
  with an explicitly required external Python/Java/other runtime. Per-ABI
  launcher names do not duplicate payloads. Native `targets` remain compatible.
- Portable Python stdio/TCP example and expanded
  [AI module-authoring guide](https://github.com/1Ayakiro1/Qualia-Engine/blob/v0.5.1-alpha/docs/MODULE_AUTHORING_AI.md).
- The UI version now agrees with VERSION, Flutter package and native core.

## Downloads and sources

| Asset | Purpose |
|---|---|
| `Qualia-Engine-0.5.1-x86_64.AppImage` | Linux x64 with patched native-vsync GTK embedder |
| `Qualia-Engine-0.5.1-linux-x64.tar.gz` | Same Linux application as a portable bundle |
| `Qualia-Engine-0.5.1-stock-gtk-*` | CI Linux build with standard Flutter GTK, without the native-vsync patch |
| `Qualia-Engine-0.5.1-windows-x64.zip` | Windows portable application; extract all files |
| `Qualia-Engine-0.5.1-macos.zip` | macOS application, ad-hoc signed, not notarized |
| `Qualia-Engine-0.5.1-source.zip` / `.tar.gz` | Complete tracked source tree excluding generated build outputs/tools, with SOURCE_COMMIT marker |
| `MODULE_AUTHORING_AI.md` | Standalone AI authoring instructions, also included in the source archives |
| `portable-echo-0.1.0.qmod` | Single-source Python example, requires Python 3 on PATH |
| `SHA256SUMS` | SHA-256 checksums of attached assets |

Source archives include the Flutter UI, C++ core, SDK, module example sources,
tests, build scripts, native-vsync patch, CI configuration, documentation and
Supabase migrations. External Flutter/toolchain dependencies are not vendored;
build instructions and pinned versions are in `docs/BUILD.md`. GitHub's automatic
source downloads may additionally contain historical tracked build outputs;
use the explicitly named `*-source.*` assets for clean sources.

## Verification

- Local Linux: static analysis, complete Flutter test suite and C++ core tests.
- Dedicated tests cover stdio → TCP → stdio routing, independent TCP instances,
  socket closure, exact 1 MiB inbound/outbound boundaries and corrupt ZIP rejection.
- A separate heavy test packed and installed a package just below 2 GiB and
  rejected an archive exceeding the limit. It is opt-in, not part of every CI run.
- Desktop CI builds and tests Linux, Windows and macOS. The release publication
  records its Actions run and any platform-specific limitations.

## Limitations and deployment

- This is an **Alpha prerelease**, not a stable or security-sandboxed distribution.
- Modules run as trusted user processes. TCP has no built-in TLS/authentication;
  use loopback for local exchange or a separately secured network.
- A portable payload still needs its declared runtime installed. Native Python
  wheels/JNI/drivers require compatible ABI builds; one archive does not shrink
  different native binaries. Cross-version artifact deduplication is not implemented.
- No Docker runtime was added. JSON transport is not a hard-real-time binary EEG API.
- Supabase migration `20261015090000_module_limits_and_transport.sql` is supplied,
  not automatically deployed. A global Storage limit ≥2 GiB and a suitable plan
  are also required. Marketplace executable uploads are not implemented by this release.
- Windows has no Authenticode signature; macOS has no Developer-ID notarization.
  Cross-built ARM payloads are not evidence of execution on every ARM device.
