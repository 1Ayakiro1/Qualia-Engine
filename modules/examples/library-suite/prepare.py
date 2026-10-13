#!/usr/bin/env python3
"""Build library integration fixtures; downloads nothing. Linux x64 build host.

Requires C/C++ compiler, Go and NumPy on the BUILD machine only. Copies runtime
and dependencies into the Python fixture. These are test artifacts, not curated
redistributable runtimes; review licensing/OS baseline before redistribution.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import sysconfig

import numpy

root = pathlib.Path(__file__).resolve().parents[3]
source = pathlib.Path(__file__).resolve().parent
output = pathlib.Path(sys.argv[1]).resolve()
sdk = root / "app/assets/module_sdk/qmod.py"
output.mkdir(parents=True, exist_ok=True)
library = output / "libqualia_math.so"
subprocess.run(["cc", "-shared", "-fPIC", "-O2", str(source / "math.c"), "-lm", "-o", str(library)], check=True)
schema = {"type":"object", "properties":{"mean":{"type":"number"}}, "required":["mean"]}

def manifest(name, language, launch):
    return {"format":"qualia-module", "schemaVersion":1, "id":name, "name":name,
            "version":"0.1.0", "runtime":"process-v1", "platform":"linux-x64",
            "languages":[language], "launch":launch,
            "ports":{"inputs":["input"], "outputs":["output"]},
            "portSchemas":{"inputs":{"input":schema}, "outputs":{"output":schema}},
            "ui":[{"id":"result", "type":"label", "label":"Result"},
                  {"id":"run", "type":"button", "label":"Run"},
                  {"id":"crash", "type":"button", "label":"Crash fixture"},
                  {"id":"badOutput", "type":"button", "label":"Invalid output fixture"},
                  {"id":"numpyVersion", "type":"label", "label":"NumPy"}]}

for language in ("cpp", "python", "go"):
    project = output / language
    payload = project / "payload"
    (payload / "bin").mkdir(parents=True, exist_ok=True)
    (payload / "lib").mkdir(exist_ok=True)
    if language in ("cpp", "python"):
        shutil.copyfile(library, payload / "lib/libqualia_math.so")
    m = manifest("library-" + language, language, {"executable":"bin/module", "arguments":[]})
    if language == "cpp":
        subprocess.run(["c++", "-std=c++17", "-O2", str(source / "cpp.cpp"),
            "-I" + str(root / "app/assets/module_sdk/include"), "-L" + str(payload / "lib"),
            "-lqualia_math", "-Wl,-rpath,$ORIGIN/../lib", "-o", str(payload / "bin/module")], check=True)
    elif language == "go":
        import os
        subprocess.run(["go", "build", "-trimpath", "-o", str(payload / "bin/module"), str(source / "go.go")],
            env={**os.environ, "CGO_ENABLED":"0", "GOOS":"linux", "GOARCH":"amd64"}, check=True)
        m["portSchemas"]["outputs"]["output"] = {"type":"object", "properties":{"digest":{"type":"string"}}, "required":["digest"]}
    else:
        subprocess.run([sys.executable, str(root / "modules/examples/python/prepare_demo.py"), str(project)], check=True)
        m["launch"] = json.loads((project / "manifest.json").read_text())["launch"]
        shutil.copyfile(source / "python.py", payload / "src/main.py")
        runtime = payload / "runtime"
        dynload = runtime / sys.platlibdir / f"python{sys.version_info.major}.{sys.version_info.minor}" / "lib-dynload"
        shutil.copytree(sysconfig.get_config_var("DESTSHARED"), dynload, dirs_exist_ok=True)
        site = runtime / "site-packages"
        site.mkdir(exist_ok=True)
        numpy_path = pathlib.Path(numpy.__file__).parent
        shutil.copytree(numpy_path, site / "numpy", dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "tests", "test"))
        for extra in numpy_path.parent.glob("numpy.libs"):
            shutil.copytree(extra, site / extra.name, dirs_exist_ok=True)
        # Recursively bundle every ldd-resolved native dependency (incl. OpenBLAS/FFI).
        todo = list(runtime.rglob("*.so")) + list(runtime.rglob("*.so.*"))
        seen = set()
        while todo:
            binary = todo.pop()
            if binary.resolve() in seen: continue
            seen.add(binary.resolve())
            result = subprocess.run(["ldd", str(binary)], text=True, capture_output=True)
            if "not found" in result.stdout: raise RuntimeError(result.stdout)
            for dependency in re.findall(r"=> (/[^\s()]+)", result.stdout):
                dest = runtime / "lib" / pathlib.Path(dependency).name
                if not dest.exists():
                    shutil.copyfile(dependency, dest)
                    todo.append(dest)
        # Symlinks are forbidden in qmod. Materialize runtime aliases.
        for path in list(runtime.rglob("*")):
            if path.is_symlink():
                data = path.read_bytes()
                path.unlink()
                path.write_bytes(data)
    (project / "manifest.json").write_text(json.dumps(m, indent=2))
    subprocess.run([sys.executable, str(sdk), "pack", str(project)], check=True)
print(output)
