#!/usr/bin/env python3
"""Build a complete module set in staging, publish only after smoke tests.

The module owns dist/, not the engine's builds/<VERSION> snapshots. Build with
the interpreter containing build-requirements.txt. No shell or runtime downloads.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MODULE = Path(__file__).resolve().parent


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def build(output):
    if sys.platform != "linux" or os.uname().machine != "x86_64":
        raise RuntimeError("This build script targets Linux x86_64 only")
    manifest = json.loads((MODULE / "manifest.json").read_text())
    version = manifest["version"]
    tool = ROOT / "tools/appimagetool-x86_64.AppImage"
    appimagetool = shutil.which("appimagetool") or (str(tool) if tool.is_file() else None)
    if not appimagetool:
        raise RuntimeError("appimagetool is missing; install it or build the engine once first")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".eternalcortex-build-", dir=output.parent) as temporary:
        work = Path(temporary)
        staged = work / "published"
        staged.mkdir()
        run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--onedir",
             "--name", "EternalCortex", "--distpath", work / "frozen", "--workpath", work / "build",
             "--specpath", work, "--exclude-module", "PySide6.QtWebEngineCore",
             "--exclude-module", "PySide6.QtWebEngineWidgets", MODULE / "payload/main.py"])
        # qmod installations deliberately forbid archive symlinks. Freeze once,
        # dereference all library symlinks into ordinary package-owned files.
        bundle = staged / "EternalCortex"
        shutil.copytree(work / "frozen/EternalCortex", bundle, symlinks=False)
        shutil.copyfile(MODULE / "README.md", bundle / "README.md")
        for license_file in ("LICENSE", "THIRD_PARTY.md"):
            if (MODULE / license_file).is_file():
                shutil.copyfile(MODULE / license_file, bundle / license_file)
        env = {**os.environ, "QT_QPA_PLATFORM": "offscreen"}
        run([bundle / "EternalCortex", "--smoke"], env=env, timeout=30)
        tar = staged / f"EternalCortex-{version}-linux-x64.tar.gz"
        with tarfile.open(tar, "w:gz") as archive:
            archive.add(bundle, arcname="EternalCortex")

        package = work / "qmod-project"
        payload = package / "payload"
        payload.mkdir(parents=True)
        shutil.copytree(bundle, payload / "bin")
        manifest["platform"] = "linux-x64"
        manifest["launch"] = {"executable": "bin/EternalCortex", "arguments": ["--qualia"]}
        (package / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
        run([sys.executable, ROOT / "app/assets/module_sdk/qmod.py", "pack", package])
        shutil.copyfile(package / "dist" / f"eternal-cortex-{version}.qmod",
                        staged / f"eternal-cortex-{version}-linux-x64.qmod")

        appdir = work / "AppDir"
        shutil.copytree(bundle, appdir / "usr/bin")
        shutil.copyfile(ROOT / "app/assets/icons/bci_engine_256.png", appdir / "eternal-cortex.png")
        (appdir / "eternal-cortex.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=EternalCortex\n"
            "Exec=EternalCortex\nIcon=eternal-cortex\nCategories=Science;Education;\n")
        apprun = appdir / "AppRun"
        apprun.write_text('#!/bin/sh\nHERE="$(dirname "$(readlink -f "$0")")"\nexec "$HERE/usr/bin/EternalCortex" "$@"\n')
        apprun.chmod(0o755)
        image = staged / f"EternalCortex-{version}-x86_64.AppImage"
        run([appimagetool, "--appimage-extract-and-run", appdir, image],
            env={**os.environ, "ARCH": "x86_64"})
        run([image, "--appimage-extract-and-run", "--smoke"], env=env, timeout=30)
        sums = []
        for path in sorted(staged.rglob("*")):
            if path.is_file():
                with path.open("rb") as stream:
                    digest = hashlib.file_digest(stream, "sha256").hexdigest()
                sums.append(f"{digest}  {path.relative_to(staged).as_posix()}\n")
        (staged / "SHA256SUMS").write_text("".join(sums))
        # Only replace this module's well-known output, never an arbitrary tree.
        if output.exists():
            if output != MODULE / "dist" or output.is_symlink():
                raise RuntimeError(f"Refusing to replace a non-module output: {output}")
            os.replace(output, work / "previous-dist")
        try:
            os.replace(staged, output)
        except OSError:
            if (work / "previous-dist").exists():
                os.replace(work / "previous-dist", output)
            raise
    print(f"Published EternalCortex {version}: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=MODULE / "dist")
    args = parser.parse_args()
    build(args.output.absolute())
