#!/usr/bin/env python3
"""Export tracked source files at a revision, excluding generated build outputs.

GitHub's automatic archives contain historical tracked binaries. This provides
an additional clean source-only tarball/zip without removing any repository files.
"""
import argparse
import io
import pathlib
import subprocess
import tarfile
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--revision", default="HEAD")
parser.add_argument("--output", type=pathlib.Path, required=True)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parent.parent
revision = subprocess.check_output(["git", "rev-parse", "--verify", args.revision + "^{commit}"], cwd=root, text=True).strip()
archive_bytes = subprocess.check_output(["git", "archive", "--format=tar", revision], cwd=root)
archive = tarfile.open(fileobj=io.BytesIO(archive_bytes))
version_file = archive.extractfile("VERSION")
version = version_file.read().decode().strip()
prefix = f"Qualia-Engine-{version}-source"
args.output.mkdir(parents=True, exist_ok=True)
excluded = ("build/", "builds/", "core/build/", "tools/")
with tarfile.open(args.output / (prefix + ".tar.gz"), "w:gz") as tar, zipfile.ZipFile(args.output / (prefix + ".zip"), "w", compression=zipfile.ZIP_DEFLATED) as zip:
    for entry in archive:
        if entry.name.startswith(excluded):
            continue
        data = archive.extractfile(entry).read() if entry.isfile() else None
        relative = entry.name
        entry.name = prefix + "/" + relative
        tar.addfile(entry, io.BytesIO(data) if data is not None else None)
        if data is not None:
            info = zipfile.ZipInfo(entry.name)
            info.external_attr = (0o100000 | entry.mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            zip.writestr(info, data)
    data = (revision + "\n").encode()
    info = tarfile.TarInfo(prefix + "/SOURCE_COMMIT")
    info.size = len(data)
    info.mode = 0o644
    tar.addfile(info, io.BytesIO(data))
    zip.writestr(prefix + "/SOURCE_COMMIT", data)
print(f"Source archives: {args.output}, revision {revision}")
