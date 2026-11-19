"""Bounded file readers, independent of Qt. Raw arrays are read-only/mapped."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import math
import zipfile

import numpy as np

MAX_VALUES = 25_000_000


@dataclass(frozen=True)
class Recording:
    samples: np.ndarray  # frames x channels, physical units (not assumed μV)
    rate: float
    labels: tuple[str, ...]
    units: tuple[str, ...]
    path: Path | None = None

    def __post_init__(self):
        if (self.samples.ndim != 2 or not 0 < self.samples.size <= MAX_VALUES
                or not 1 <= self.samples.shape[1] <= 256
                or not math.isfinite(self.rate) or not 0 < self.rate <= 1_000_000
                or len(self.labels) != self.samples.shape[1]
                or len(self.units) != self.samples.shape[1]
                or self.samples.dtype.kind not in "fiu"):
            raise ValueError("Invalid recording dimensions, metadata or sample rate")
        # Validate in chunks to avoid a full-size temporary boolean array.
        for start in range(0, len(self.samples), 65536):
            if not np.isfinite(self.samples[start:start + 65536]).all():
                raise ValueError("Recording contains NaN/Inf")
        self.samples.flags.writeable = False

    @property
    def duration(self) -> float:
        return len(self.samples) / self.rate

    def window(self, start: float, end: float, channel: int) -> tuple[np.ndarray, np.ndarray]:
        first = max(0, int(start * self.rate))
        last = min(len(self.samples), math.ceil(end * self.rate))
        return np.arange(first, last) / self.rate, self.samples[first:last, channel]


@dataclass(frozen=True)
class Spectrogram:
    db: np.ndarray  # time x frequency
    step: float
    frequencies: np.ndarray
    offset: float = 0.0
    path: Path | None = None

    def __post_init__(self):
        if (self.db.ndim != 2 or not 0 < self.db.size <= MAX_VALUES
                or self.frequencies.ndim != 1 or len(self.frequencies) != self.db.shape[1]
                or len(self.frequencies) < 2 or not math.isfinite(self.step) or self.step <= 0
                or not math.isfinite(self.offset) or self.offset < 0
                or not np.isfinite(self.db).all() or not np.isfinite(self.frequencies).all()
                or self.frequencies[0] < 0 or not (np.diff(self.frequencies) > 0).all()
                or not np.allclose(np.diff(self.frequencies), np.diff(self.frequencies)[0])):
            raise ValueError("Invalid spectrogram: expected finite uniformly spaced frequency bins")
        self.db.flags.writeable = False
        self.frequencies.flags.writeable = False

    @property
    def duration(self):
        return self.offset + (len(self.db) - .5) * self.step


def _bounded_npz(path: Path):
    if path.stat().st_size > 128_000_000:
        raise ValueError("File exceeds the 128 MB input limit")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) > 16 or sum(i.file_size for i in entries) > 128_000_000:
            raise ValueError("NPZ exceeds the 128 MB decoded limit")
        if len({i.filename for i in entries}) != len(entries):
            raise ValueError("Duplicate NPZ entries")
        # Validate NPY headers before np.load can allocate from an untrusted
        # shape. ZIP size alone does not protect against a forged huge shape.
        for entry in entries:
            if not entry.filename.endswith(".npy") or "/" in entry.filename:
                raise ValueError("NPZ must contain only flat NPY arrays")
            with archive.open(entry) as stream:
                version = np.lib.format.read_magic(stream)
                if version == (1, 0):
                    shape, _, dtype = np.lib.format.read_array_header_1_0(stream)
                elif version == (2, 0):
                    shape, _, dtype = np.lib.format.read_array_header_2_0(stream)
                else:
                    raise ValueError("Unsupported NPY version")
                size = math.prod(shape) * dtype.itemsize
                if dtype.hasobject or len(shape) > 2 or size > 128_000_000 or stream.tell() + size != entry.file_size:
                    raise ValueError("Invalid NPY shape, dtype or payload length")
    return np.load(path, allow_pickle=False)


def load(path: str | Path) -> Recording | Spectrogram:
    path = Path(path).resolve()
    if path.stat().st_size > 128_000_000:
        raise ValueError("File exceeds the 128 MB input limit")
    if path.suffix.lower() == ".edf":
        return read_edf(path)
    if path.suffix.lower() != ".npz":
        raise ValueError("Open EDF or numeric NPZ; a spectrogram image is not signal data")
    with _bounded_npz(path) as data:
        if "power_db" in data:
            return Spectrogram(np.array(data["power_db"], dtype=np.float32),
                               float(data["time_step"]), np.array(data["frequencies"], dtype=float),
                               float(data["offset"]) if "offset" in data else 0.0, path)
        samples = np.array(data["samples"], dtype=np.float32)
        if samples.ndim == 1:
            samples = samples[:, None]
        channels = samples.shape[1] if samples.ndim == 2 else 0
        labels = tuple(str(v) for v in data["labels"]) if "labels" in data else tuple(f"CH {i+1}" for i in range(channels))
        units = tuple(str(v) for v in data["units"]) if "units" in data else ("",) * channels
        return Recording(samples, float(data["sample_rate"]), labels, units, path)


def read_edf(path: Path) -> Recording:
    with path.open("rb") as stream:
        header = stream.read(256)
        def field(offset, length):
            return header[offset:offset+length].decode("ascii").strip()
        if len(header) != 256 or field(0, 8) != "0" or field(192, 44).startswith("EDF+"):
            raise ValueError("Only plain EDF is supported; EDF+/BDF require a dedicated importer")
        channels, records = int(field(252, 4)), int(field(236, 8))
        duration, header_size = float(field(244, 8)), int(field(184, 8))
        if not 1 <= channels <= 256 or records < 1 or header_size != 256 * (channels+1) or not math.isfinite(duration) or duration <= 0:
            raise ValueError("Invalid EDF dimensions")
        signal_header = stream.read(channels * 256)
        if len(signal_header) != channels * 256:
            raise ValueError("Truncated EDF header")
        def fields(offset, size, cast=str):
            return [cast(signal_header[channels*offset+i*size:channels*offset+(i+1)*size].decode("ascii").strip()) for i in range(channels)]
        labels, units = fields(0, 16), fields(96, 8)
        pmin, pmax = np.array(fields(104, 8, float)), np.array(fields(112, 8, float))
        dmin, dmax = np.array(fields(120, 8, int)), np.array(fields(128, 8, int))
        counts = fields(216, 8, int)
        if (len(set(counts)) != 1 or counts[0] < 1 or "EDF Annotations" in labels
                or counts[0]*records*channels > MAX_VALUES
                or not np.isfinite([pmin, pmax]).all() or not (pmax > pmin).all()
                or not (dmax > dmin).all() or (dmin < -32768).any() or (dmax > 32767).any()):
            raise ValueError("Invalid calibration or unsupported mixed-rate EDF")
        expected = counts[0]*records*channels
        if path.stat().st_size != header_size + expected*2:
            raise ValueError("EDF payload length does not match records")
    digital = np.memmap(path, dtype="<i2", mode="r", offset=header_size,
                        shape=(records, channels, counts[0]))
    values = np.empty((records*counts[0], channels), dtype=np.float32)
    scale = (pmax-pmin)/(dmax-dmin)
    for record in range(records):
        values[record*counts[0]:(record+1)*counts[0]] = (digital[record].T-dmin)*scale+pmin
    return Recording(values, counts[0]/duration, tuple(labels), tuple(units), path)


def compute_spectrum(recording: Recording, channel: int, size: int = 512) -> Spectrogram:
    """Bounded preview STFT, with explicit decimation for long recordings."""
    if size not in (128, 256, 512, 1024, 2048):
        raise ValueError("Unsupported FFT window")
    signal = recording.samples[:, channel]
    hop = max(size // 4, math.ceil(max(1, len(signal)-size) / 4096))
    starts = range(0, max(1, len(signal)-size+1), hop)
    window = np.hanning(size)
    rows = []
    for start in starts:
        block = np.zeros(size)
        part = signal[start:start+size]
        block[:len(part)] = part
        block -= block.mean()
        power = abs(np.fft.rfft(block*window))**2 / (recording.rate*(window**2).sum())
        if size > 2:
            power[1:-1] *= 2
        rows.append(10*np.log10(np.maximum(power, 1e-20)))
    # Time coordinate is the FFT window centre, not its start. The heatmap
    # cells span centre +/- hop/2; don't claim exact whole-record coverage.
    offset = size/2/recording.rate
    return Spectrogram(np.asarray(rows, dtype=np.float32), hop/recording.rate,
                       np.fft.rfftfreq(size, 1/recording.rate), offset)


def demo() -> Recording:
    rate = 256.0
    t = np.arange(256*90)/rate
    rng = np.random.default_rng(42)
    channels = [20*np.sin(2*np.pi*(8+i*.7)*t) + 8*np.sin(2*np.pi*20*t)
                + rng.normal(0, 3, len(t)) for i in range(8)]
    return Recording(np.asarray(channels, dtype=np.float32).T, rate,
                     ("Fp1", "Fp2", "C3", "C4", "P3", "P4", "O1", "O2"), ("uV",)*8)
