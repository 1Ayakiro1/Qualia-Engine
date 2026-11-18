#!/usr/bin/env python3
"""Publish one complete artifact set; prune only recognized generated builds.

The default destination is builds/<VERSION>. A custom --output is an exact
destination (as with DIST_OUT); its siblings are never pruned. Source archives
from older snapshots are deliberately not carried into a new build.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
PACKAGE = re.compile(rf"(?:Qualia-Engine|Ayakiro_BCI_Engine)-{VERSION_PATTERN}-(?:x86_64\.AppImage|linux-x64\.tar\.gz|windows-x64\.zip|macos\.zip|source\.(?:zip|tar\.gz))")


def managed(path: Path) -> bool:
    """Recognize build outputs by name, without following symlinks."""
    if path.is_symlink():
        return False
    if path.is_file():
        return bool(PACKAGE.fullmatch(path.name))
    return path.is_dir() and (
        bool(re.fullmatch(VERSION_PATTERN, path.name))
        or path.name == "binary"
        or bool(re.fullmatch(r"binary-previous-\d{8}-\d{6}", path.name))
    )


def publish(source: Path, output: Path, version: str, platform: str,
            builds_root: Path = ROOT / "builds") -> None:
    if not re.fullmatch(VERSION_PATTERN, version):
        raise ValueError("Invalid build version")
    # Check the path itself before resolving it: symlinks are not output folders.
    if source.is_symlink() or output.is_symlink():
        raise ValueError("Build source/output must not be symlinks")
    source, output, builds_root = source.resolve(), output.resolve(), builds_root.resolve()
    if not source.is_dir() or source == output or source in output.parents or output in source.parents:
        raise ValueError("Build source and output must be separate directories")
    if output == builds_root or output == ROOT or output in ROOT.parents:
        raise ValueError("Output must be a dedicated artifact directory, not the builds/repository root")
    if output.parent == builds_root and output.name != version:
        raise ValueError("The managed build directory must be named after VERSION")
    prefix = f"Qualia-Engine-{version}"
    required = {
        "linux": {f"{prefix}-x86_64.AppImage", f"{prefix}-linux-x64.tar.gz", "binary"},
        "windows": {f"{prefix}-windows-x64.zip"},
        "macos": {f"{prefix}-macos.zip"},
    }[platform]
    entries = {p.name for p in source.iterdir()}
    if entries != required:
        raise ValueError(f"Expected exactly {sorted(required)}; got {sorted(entries)}")
    for path in source.iterdir():
        if path.is_symlink() or (path.name != "binary" and (not path.is_file() or not path.stat().st_size)):
            raise ValueError(f"Invalid build artifact: {path}")
    if platform == "linux" and not (source / "binary/bci_engine").is_file():
        raise ValueError("Linux bundle has no executable")
    if output.exists():
        if not output.is_dir() or any(
            not managed(p) and p.name not in {"SHA256SUMS", "VERIFICATION.md"}
            for p in output.iterdir()
        ):
            raise ValueError(f"Refusing to replace an output containing unknown files: {output}")

    output.parent.mkdir(parents=True, exist_ok=True)
    # Same filesystem as the destination; rollback data stays outside builds/.
    with tempfile.TemporaryDirectory(prefix=".build-publish-", dir=output.parent.parent) as work:
        work = Path(work)
        prepared = work / "prepared"
        shutil.copytree(source, prepared, symlinks=True)
        sums = []
        for path in sorted(prepared.rglob("*")):
            if path.is_file() and not path.is_symlink():
                with path.open("rb") as stream:
                    checksum = hashlib.file_digest(stream, "sha256").hexdigest()
                sums.append(f"{checksum}  {path.relative_to(prepared).as_posix()}\n")
        (prepared / "SHA256SUMS").write_text("".join(sums), encoding="utf-8")
        old = []
        if output.exists():
            old.append(output)
        if output.parent == builds_root:
            old.extend(p for p in builds_root.iterdir() if p != output and managed(p))
        moved: list[tuple[Path, Path]] = []
        try:
            for index, path in enumerate(old):
                backup = work / f"previous-{index}"
                os.replace(path, backup)
                moved.append((path, backup))
            os.replace(prepared, output)
        except OSError:
            for path, backup in reversed(moved):
                os.replace(backup, path)
            raise
    print(f"Published {platform} {version}: {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--platform", choices=["linux", "windows", "macos"], required=True)
    args = parser.parse_args()
    version = (ROOT / "VERSION").read_text().strip()
    try:
        publish(args.source, args.output or ROOT / "builds" / version, version, args.platform)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Build publication failed: {exc}\n")


if __name__ == "__main__":
    main()
