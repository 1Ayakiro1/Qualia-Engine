#!/usr/bin/env python3
"""Offline Qualia native module SDK. Python standard library + CMake + C++17."""
import argparse
import json
import pathlib
import re
import shutil
import subprocess
import zipfile


def check(project):
    m = json.loads((project / "manifest.json").read_text())
    assert m.get("format") == "qualia-module" and m.get("schemaVersion") == 1, "Invalid format"
    assert re.fullmatch(r"[a-z][a-z0-9-]{1,63}", m["id"]), "Invalid ID"
    assert re.fullmatch(r"\d+\.\d+\.\d+", m["version"]), "Invalid version"
    assert isinstance(m["name"], str) and 0 < len(m["name"].strip()) <= 80, "Invalid name"
    assert m["runtime"] == "native-process-v1" and m["platform"] == "linux-x64", "Unsupported runtime"
    assert m["entrypoint"] == "bin/module", "Invalid entrypoint"
    assert len(m["ui"]) <= 64, "Too many UI fields"
    ids = set()
    for field in m["ui"]:
        assert re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]{0,63}", field["id"]), "Invalid field ID"
        assert field["id"] not in ids, "Duplicate field"
        ids.add(field["id"])
        assert field["id"] not in ["enabled", "label"], "Reserved host field ID"
        assert field["type"] in ["slider", "toggle", "select", "text", "number", "button", "label"]
    for direction in ["inputs", "outputs"]:
        ports = m["ports"][direction]
        assert len(ports) <= 16 and len(set(ports)) == len(ports), "Invalid ports"
        assert all(re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]{0,63}", p) for p in ports), "Invalid port ID"
    return m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["create", "check", "build"])
    parser.add_argument("project", type=pathlib.Path)
    args = parser.parse_args()
    project = args.project.resolve()
    if args.command == "create":
        assert not project.exists() or not any(project.iterdir()), "Choose an empty directory"
        project.mkdir(parents=True, exist_ok=True)
        sdk = pathlib.Path(__file__).resolve().parent
        template = sdk / "template" if (sdk / "template").is_dir() else sdk
        for name in ["manifest.json", "CMakeLists.txt", "main.cpp"]:
            shutil.copyfile(template / name, project / name)
        shutil.copytree(sdk / "include", project / "include")
        shutil.copyfile(__file__, project / "qmod.py")
        return
    manifest = check(project)
    if args.command == "check":
        print("Manifest OK")
        return
    build = project / "build"
    subprocess.run(["cmake", "-S", str(project), "-B", str(build), "-DCMAKE_BUILD_TYPE=Release"], check=True)
    subprocess.run(["cmake", "--build", str(build), "--parallel", "2"], check=True)
    out = project / "dist"
    out.mkdir(exist_ok=True)
    package = out / f'{manifest["id"]}-{manifest["version"]}.qmod'
    entries = [(project / "manifest.json", "manifest.json"), (build / "module", "bin/module")]
    assets = project / "assets"
    if assets.exists():
        for file in sorted(assets.rglob("*")):
            assert not file.is_symlink(), "Asset symlinks are not allowed"
            if file.is_file():
                entries.append((file, file.relative_to(project).as_posix()))
    assert len(entries) <= 256 and sum(f.stat().st_size for f, _ in entries) <= 64 * 1024 * 1024
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_STORED) as archive:
        for file, name in entries:
            archive.write(file, name)
    print(package)


if __name__ == "__main__":
    main()
