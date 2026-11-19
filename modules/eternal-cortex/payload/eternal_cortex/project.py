"""Self-contained projects: numeric data and annotations, never pickle or code."""
from dataclasses import asdict
import json
import os
from pathlib import Path
import tempfile

import numpy as np

from .recording import Recording, load
from .timeline import Annotation, Annotations


def save_project(path, source, annotations, channel, fft_size, selection):
    metadata = {"format": "eternal-cortex-project", "version": 1,
                "annotations": [asdict(a) for a in annotations], "channel": channel,
                "fft_size": fft_size, "selection": list(selection)}
    values = {"project": np.array(json.dumps(metadata, ensure_ascii=False))}
    if isinstance(source, Recording):
        values.update(samples=source.samples, sample_rate=source.rate,
                      labels=np.array(source.labels), units=np.array(source.units))
    else:
        values.update(power_db=source.db, time_step=source.step,
                      frequencies=source.frequencies, offset=source.offset)
    path = Path(path)
    # Replacement is atomic; a failed write never destroys the previous project.
    fd, temporary = tempfile.mkstemp(prefix=".eternalcortex-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            np.savez_compressed(stream, **values)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def open_project(path):
    source = load(path)
    # load() already checked total uncompressed NPZ size, before NumPy access.
    with np.load(path, allow_pickle=False) as archive:
        raw = str(archive["project"])
    if len(raw) > 4_000_000:
        raise ValueError("Project metadata too large")
    metadata = json.loads(raw)
    if metadata.get("format") != "eternal-cortex-project" or metadata.get("version") != 1:
        raise ValueError("Unsupported EternalCortex project version")
    entries = metadata.get("annotations", [])
    if not isinstance(entries, list) or len(entries) > 10000:
        raise ValueError("Invalid annotations")
    annotations = Annotations(source.duration)
    annotations.replace([Annotation(**entry) for entry in entries])
    channel = metadata.get("channel", 0)
    channels = source.samples.shape[1] if isinstance(source, Recording) else 1
    if type(channel) is not int or not 0 <= channel < channels:
        raise ValueError("Invalid project channel")
    fft = metadata.get("fft_size", 512)
    if fft not in (128, 256, 512, 1024, 2048):
        raise ValueError("Invalid project FFT size")
    selection = metadata.get("selection", [0., min(5., source.duration)])
    if (not isinstance(selection, list) or len(selection) != 2
            or not all(isinstance(v, (int, float)) and np.isfinite(v) and 0 <= v <= source.duration for v in selection)):
        raise ValueError("Invalid project selection")
    return source, annotations.items, channel, fft, tuple(sorted(selection))


def export_annotations(path, annotations):
    import csv
    with Path(path).open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["start_seconds", "end_seconds", "label", "category"])
        for item in annotations:
            # Spreadsheet formula injection must not turn labels into code.
            def safe(value):
                return "'" + value if value.lstrip().startswith(("=", "+", "-", "@")) else value
            writer.writerow([item.start, item.end, safe(item.label), safe(item.category)])
