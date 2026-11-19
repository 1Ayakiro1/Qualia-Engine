# EternalCortex · 0.1.0

Local-first desktop EEG review studio, built on **PySide6 + PyQtGraph + NumPy**.
Its window is independent of the Flutter canvas; Qualia can supervise a separate
process for each installed instance using the unchanged `process-v1` contract.
No server, telemetry, downloads, credentials or network access are used at runtime.

## Current functionality

- Open **plain, uniform-rate EDF** with physical calibration and record ordering.
- Open numeric NPZ signals and precomputed spectrograms (schemas below).
- View up to the first **16 waveform channels**, choose any imported channel for
  its spectrogram, zoom/pan and navigate with the overview strip.
- Common cursor, monotonic play/pause/stop/seek, sample steps, speed 0.25–4× and
  looping within a selection. Replay is local visual playback, not acquisition.
- Point/interval annotations with categories, rename on double-click, deletion,
  undo/redo (100 edits), CSV export protected against spreadsheet formulas.
- Atomic, self-contained `.npz` projects with numeric source data, annotations,
  selected channel, FFT size and selection. Saving does not modify the source.
- Export the displayed numeric spectrogram; reopen it without the original EEG.
- Deterministic synthetic demo; explicitly labelled as **DEMO**.

The dark neutral palette follows `app/lib/core/theme/app_palette.dart`. Plot
colors encode signal data rather than introducing a new engine UI theme.

## Launch

Linux x86_64, after building:

```bash
./dist/EternalCortex-0.1.0-x86_64.AppImage
# Without FUSE:
./dist/EternalCortex-0.1.0-x86_64.AppImage --appimage-extract-and-run
# Or extract the tar.gz and run:
./dist/EternalCortex/EternalCortex --demo
```

Import `dist/eternal-cortex-0.1.0-linux-x64.qmod` through Qualia's local module
import. It bundles Python/Qt/NumPy and needs no pip installation. Add an instance
to a workspace; **Open EternalCortex** restores its dedicated window. Closing a
managed window hides it, preserving its document; stopping/removing its instance
ends the process. Save before stopping the engine: host v1 does not guarantee
graceful shutdown or an unsaved-document prompt. No OS sandbox is provided.

The generated Linux artifacts depend on the build machine's glibc/platform
libraries; AppImage does not guarantee compatibility with older distributions.
Windows/macOS packages have not been built or tested.

## Develop and test independently

Use Python **3.11–3.14**, ideally the same minor version as the release build.
The initial Linux build uses Python 3.14. Dependencies are pinned in
`requirements.txt` (NumPy 2.4.0 was yanked and is intentionally not used).

```bash
python3 -m venv .venv
.venv/bin/pip install -r build-requirements.txt
.venv/bin/python payload/main.py --demo
PYTHONPATH=payload .venv/bin/python -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen .venv/bin/python payload/main.py --smoke
.venv/bin/python build_linux.py
```

Host integration (from repository root, after building):

```bash
cd app
ETERNAL_CORTEX_QMOD="$PWD/../modules/eternal-cortex/dist/eternal-cortex-0.1.0-linux-x64.qmod" flutter test test/eternal_cortex_test.dart
```

This installs the actual archive, launches two isolated instances without Python
on PATH, checks status/handshake and workspace-switch cleanup.

`build_linux.py` stages and smoke-tests all three formats before replacing `dist/`;
SHA256SUMS covers the bundle and packages. It requires `appimagetool` (or the
engine's `tools/appimagetool-x86_64.AppImage`). The source manifest is a portable
**development** entrypoint using `python3`/`python` from PATH: install dependencies
in that interpreter, or prefer the bundled `.qmod`. Do not package `.venv`.

Architecture: `recording.py` handles bounded numeric import and PSD; `timeline.py`
owns the Qt-independent clock/document; `project.py` owns persistence; `app.py`
adapts them to Qt and the existing middle API. File reads/FFT/project writes run
on a bounded worker queue. Input files are capped at 128 MB decoded, signals at
25 million numeric values and 256 imported channels. NPZ NPY headers are checked
before allocation; pickle/object arrays and malformed payloads are rejected.

## Numeric NPZ contracts

Raw signal:

```python
np.savez("recording.npz", samples=samples, sample_rate=256.0,
         labels=np.array(["C3", "C4"]), units=np.array(["uV", "uV"]))
```

`samples`: frames × channels, real finite numbers (one-dimensional single channel
also accepted). `sample_rate`: finite positive scalar. Optional `labels`/`units`:
one string per channel; missing physical units are **not** assumed to be μV.

Precomputed spectrum:

```python
np.savez("spectrum.npz", power_db=power_db, time_step=0.25,
         frequencies=frequencies, offset=0.5)
```

`power_db`: time × frequency, already in dB (no hidden conversion). Frequencies
must be finite, increasing, uniformly spaced Hz bins; at least two bins.
`time_step`: positive seconds between columns. `offset`: first column's centre
in seconds (default 0). Cell boundaries are centre ± half time_step. A spectrum
has no reconstructed EEG: waveform display/FFT changes are unavailable.
Image-only PNG/JPEG imports are intentionally rejected as non-signal data.

Computed PSD uses one-sided Hann-window STFT, mean removal and physical units²/Hz;
FFT sizes 128/256/512/1024/2048. Long-file preview increases hop size to cap output
at roughly 4096 columns. This is a preview, not a lossless full-time-resolution
analysis/export. FFT timestamps refer to window centres. Edge windows are not
presented as exact whole-record coverage. Short signals are zero-padded.
Waveform decimation preserves min/max bins, but the overview strip is sampled.
Each visible waveform is centred and amplitude-normalized for navigation, **not** a calibrated
μV ruler; source arrays/project values remain unchanged.

## API boundaries and limitations

`apiLayers: ["middle"]` for this snapshot: ready/init, allowlisted status and
show-window event only. Identity/routing belongs to the host, not a package ID.
No new protocol, capabilities, external gateway or host/core C ABI are introduced.
No ports are declared: **replay does not publish into the graph**. A future opt-in
output will be `internal` over host-owned links, with explicit bounded payloads
and routing tests; existing JSON process-v1 is not a binary signal data plane.

Not implemented: live EEG acquisition, graph replay output, EDF+/BDF/mixed rates,
MNE/SciPy importers, filtering/rereferencing, spectrogram-image reconstruction,
editing the raw signal, clinical validation or complete performance profiling.
This is an initial research-tool snapshot, **not a medical device**.
