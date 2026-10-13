#!/usr/bin/env python3
"""Bundle this build machine's CPython for the JSON-only demo, entirely offline.

Not a universal Python dependency resolver. Production modules must provide a
tested redistributable runtime and all native/third-party dependencies/licenses.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import sysconfig
import zipfile

project = pathlib.Path(sys.argv[1]).resolve()
example = pathlib.Path(__file__).resolve().parent
project.mkdir(parents=True, exist_ok=True)
shutil.copyfile(example / "manifest.json", project / "manifest.json")
payload = project / "payload"
runtime = payload / "runtime"
(runtime / "bin").mkdir(parents=True, exist_ok=True)
(runtime / "lib").mkdir(exist_ok=True)
(payload / "src").mkdir(exist_ok=True)
shutil.copyfile(example / "main.py", payload / "src/main.py")
python = pathlib.Path(sys.executable).resolve()
shutil.copyfile(python, runtime / "bin/python3")
dependencies = subprocess.check_output(["ldd", str(python)], text=True)
paths = re.findall(r"(/[^\s()]+)", dependencies)
loader = next(path for path in paths if "ld-linux-x86-64.so" in path)
shutil.copyfile(loader, runtime / "ld-linux-x86-64.so.2")
(runtime / "ld-linux-x86-64.so.2").chmod(0o700)
(runtime / "bin/python3").chmod(0o700)
for path in set(paths) - {loader}:
    shutil.copyfile(path, runtime / "lib" / pathlib.Path(path).name)
stdlib = pathlib.Path(sysconfig.get_path("stdlib"))
# Match this interpreter's compiled platlibdir (lib or lib64); STORE needs no zlib.
libdir = runtime / sys.platlibdir
libdir.mkdir(exist_ok=True)
with zipfile.ZipFile(libdir / f"python{sys.version_info.major}{sys.version_info.minor}.zip", "w", compression=zipfile.ZIP_STORED) as archive:
    for source in sorted(stdlib.rglob("*.py")):
        relative = source.relative_to(stdlib)
        if any(part in {"site-packages", "lib-dynload", "__pycache__", "test", "tests", "idlelib", "tkinter", "ensurepip", "venv"} for part in relative.parts):
            continue
        archive.write(source, relative.as_posix())
# No host site-packages or native extensions are used by this JSON-only demo.
manifest = json.loads((project / "manifest.json").read_text())
command = [str(payload / manifest["launch"]["executable"]), *manifest["launch"]["arguments"]]
smoke = subprocess.run(command, cwd=payload, env={"PATH": "/nonexistent", "PYTHONHOME": "/nonexistent", "PYTHONPATH": "/nonexistent"}, input='{"type":"init","parameters":{"gain":2}}\n', text=True, capture_output=True, check=True)
assert '"ready"' in smoke.stdout, smoke.stderr
print(project)
