#!/usr/bin/env python3
"""Build a real C++ -> C shared library fixture on each desktop build host."""
import json
import pathlib
import platform
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[3]
project = pathlib.Path(sys.argv[1]).resolve()
system = {"Linux":"linux", "Windows":"windows", "Darwin":"macos"}[platform.system()]
arch = "arm64" if platform.machine().lower() in ("arm64", "aarch64") else "x64"
target = f"{system}-{arch}"
payload = project / "payload"
subprocess.run(["cmake", "-S", str(pathlib.Path(__file__).parent), "-B", str(project / "build"),
                "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_INSTALL_PREFIX=" + str(payload)], check=True)
subprocess.run(["cmake", "--build", str(project / "build"), "--config", "Release", "--parallel", "2"], check=True)
subprocess.run(["cmake", "--install", str(project / "build"), "--config", "Release"], check=True)
if system == "macos":
    for path in (payload / "bin").iterdir():
        subprocess.run(["codesign", "--force", "--sign", "-", str(path)], check=True)
manifest = {
    "format":"qualia-module", "schemaVersion":1, "runtime":"process-v1",
    "id":"native-library", "name":"Native shared library", "version":"0.1.0",
    "languages":["C++", "C"],
    "targets":{target:{"executable":"bin/module.exe" if system == "windows" else "bin/module", "arguments":[]}},
    "ports":{"inputs":["input"], "outputs":["output"]},
    "portSchemas":{"inputs":{"input":{"type":"object"}}, "outputs":{"output":{"type":"object"}}},
    "ui":[{"id":"result", "type":"label", "label":"Result"}],
}
(project / "manifest.json").write_text(json.dumps(manifest, indent=2))
subprocess.run([sys.executable, str(root / "app/assets/module_sdk/qmod.py"), "pack", str(project)], check=True)
