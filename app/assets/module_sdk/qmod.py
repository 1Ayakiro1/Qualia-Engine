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
    assert "ui" not in m or isinstance(m["ui"], list), "Invalid UI fields"
    ui = m.get("ui", [])
    assert isinstance(ui, list) and len(ui) <= 64, "Invalid UI fields"
    ids = set()
    for field in ui:
        assert re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]{0,63}", field["id"]), "Invalid field ID"
        assert field["id"] not in ids, "Duplicate field"
        ids.add(field["id"])
        assert field["id"] not in ["enabled", "label"], "Reserved host field ID"
        assert field["type"] in ["slider", "toggle", "select", "text", "number", "button", "label"]
    for direction in ["inputs", "outputs"]:
        ports = m["ports"][direction]
        assert len(ports) <= 16 and len(set(ports)) == len(ports), "Invalid ports"
        assert all(re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]{0,63}", p) for p in ports), "Invalid port ID"
    assert "uiLayout" not in m or isinstance(m["uiLayout"], dict), "Invalid custom UI layout"
    if "uiLayout" in m:
        validate_layout(m["uiLayout"], ids)
    return m


def validate_layout(node, field_ids, depth=0, seen=None, node_count=None):
    seen = set() if seen is None else seen
    node_count = [0] if node_count is None else node_count
    node_count[0] += 1
    assert depth <= 12 and node_count[0] <= 512, "Custom UI is too deep or large"
    assert isinstance(node, dict), "Custom UI element must be an object"
    containers = {"column", "row", "card"}
    leaves = {"text", "value", "button", "input", "chart", "divider", "spacer"}
    assert node.get("type") in containers | leaves, "Unsupported custom UI element"
    interactive = {"input", "button"}
    state_elements = {"value", "chart"}
    if "id" in node:
        assert re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]{0,63}", str(node["id"])), "Invalid custom UI ID"
        assert node["type"] not in interactive or node["id"] in field_ids, "Custom UI references an unknown field"
        seen.add(node["id"])
    assert node["type"] not in interactive | state_elements or isinstance(node.get("id"), str), "Custom UI element needs an ID"
    for key in ["label", "title", "text"]:
        if key in node:
            assert isinstance(node[key], str) and len(node[key]) <= 1000, "Invalid custom UI text"
    if "gap" in node:
        assert isinstance(node["gap"], (int, float)) and 0 <= node["gap"] <= 96, "Invalid custom UI gap"
    if node.get("type") == "input":
        assert node.get("inputType") in ["number", "text"], "Invalid custom UI input type"
    if node.get("type") == "spacer":
        assert isinstance(node.get("height"), (int, float)) and 0 <= node["height"] <= 240, "Invalid spacer height"
    children = node.get("children")
    if children is not None:
        assert node["type"] in containers and isinstance(children, list) and len(children) <= 64, "Invalid custom UI children"
        for child in children:
            validate_layout(child, field_ids, depth + 1, seen, node_count)
    else:
        assert node["type"] not in containers, "Custom UI container needs children"


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
    libraries = project / "lib"
    if libraries.exists():
        for file in sorted(libraries.rglob("*")):
            assert not file.is_symlink() and file.is_file(), "Library symlinks are not allowed"
            assert re.search(r"\.so(?:\.\d+)*$", file.name), "Only .so libraries are allowed"
            entries.append((file, file.relative_to(project).as_posix()))
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
