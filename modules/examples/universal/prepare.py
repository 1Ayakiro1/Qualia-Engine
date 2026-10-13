#!/usr/bin/env python3
"""Offline Go cross-build: one .qmod with all six desktop OS/ABI payloads."""
import json
import os
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[3]
project = pathlib.Path(sys.argv[1]).resolve()
project.mkdir(parents=True, exist_ok=True)
manifest = {
    "format":"qualia-module", "schemaVersion":1, "runtime":"process-v1",
    "id":"universal-go", "name":"Universal Go", "version":"0.1.0", "languages":["Go"],
    "targets":{}, "ports":{"inputs":["input"], "outputs":["output"]},
    "portSchemas":{"inputs":{"input":{"type":"object"}}, "outputs":{"output":{"type":"object"}}},
    "ui":[{"id":"result", "type":"label", "label":"Result"}],
}
for system in ("linux", "windows", "macos"):
    for arch in ("x64", "arm64"):
        target = f"{system}-{arch}"
        executable = f"targets/{target}/module" + (".exe" if system == "windows" else "")
        output = project / "payload" / executable
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["go", "build", "-trimpath", "-ldflags=-s -w", "-o", str(output),
                        str(root / "modules/examples/library-suite/go.go")], check=True,
            env={**os.environ, "CGO_ENABLED":"0", "GOOS":"darwin" if system == "macos" else system,
                 "GOARCH":"amd64" if arch == "x64" else "arm64"})
        manifest["targets"][target] = {"executable":executable, "arguments":[]}
(project / "manifest.json").write_text(json.dumps(manifest, indent=2))
subprocess.run([sys.executable, str(root / "app/assets/module_sdk/qmod.py"), "pack", str(project)], check=True)
