#!/usr/bin/env python3
"""Offline Qualia process SDK. Language-neutral pack/check plus C++ build helper."""
import argparse
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import zipfile

TARGETS = {f"{os}-{arch}" for os in ("linux", "windows", "macos") for arch in ("x64", "arm64")}

def launches(m):
    if "targets" in m:
        assert m["runtime"] == "process-v1" and not any(k in m for k in ("platform", "launch", "entrypoint")), "Ambiguous targets"
        assert isinstance(m["targets"], dict) and m["targets"] and set(m["targets"]) <= TARGETS, "Invalid targets"
        return m["targets"]
    assert m["platform"] in TARGETS, "Unsupported platform"
    return {m["platform"]: m["launch"] if m["runtime"] == "process-v1" else {"executable":"bin/module", "arguments":[]}}

def matches(binary, target):
    arm = target.endswith("arm64")
    def u(offset, size=4, endian="little"):
        return int.from_bytes(binary[offset:offset+size], endian)
    if target.startswith("linux-"):
        return len(binary) >= 20 and binary[:6] == b"\x7fELF\x02\x01" and u(16, 2) in (2, 3) and u(18, 2) == (183 if arm else 62)
    if target.startswith("windows-"):
        if len(binary) < 64 or binary[:2] != b"MZ": return False
        pe = u(60)
        return pe >= 64 and pe+26 <= len(binary) and binary[pe:pe+4] == b"PE\0\0" and u(pe+4, 2) == (0xaa64 if arm else 0x8664) and u(pe+24, 2) == 0x20b and not (u(pe+22, 2) & 0x2000)
    cpu = 0x0100000c if arm else 0x01000007
    if len(binary) < 32: return False
    if u(0) == 0xfeedfacf: return u(4) == cpu and u(12) == 2
    fat = u(0, endian="big")
    if fat not in (0xcafebabe, 0xcafebabf): return False
    count = u(4, endian="big")
    stride = 32 if fat == 0xcafebabf else 20
    if not 1 <= count <= 16 or 8 + count*stride > len(binary): return False
    for i in range(count):
        o = 8 + i*stride
        if u(o, endian="big") != cpu: continue
        size_bytes = 8 if stride == 32 else 4
        offset = u(o+8, size_bytes, "big")
        size = u(o+8+size_bytes, size_bytes, "big")
        return size >= 32 and offset >= 8+count*stride and offset+size <= len(binary) and matches(binary[offset:offset+size], target)
    return False


def check(project):
    m = json.loads((project / "manifest.json").read_text())
    assert m.get("format") == "qualia-module" and m.get("schemaVersion") == 1, "Invalid format"
    assert re.fullmatch(r"[a-z][a-z0-9-]{1,63}", m["id"]), "Invalid ID"
    assert re.fullmatch(r"\d+\.\d+\.\d+", m["version"]), "Invalid version"
    assert isinstance(m["name"], str) and 0 < len(m["name"].strip()) <= 80, "Invalid name"
    assert m["runtime"] in ["native-process-v1", "process-v1"], "Unsupported process"
    if m["runtime"] == "native-process-v1":
        assert m["entrypoint"] == "bin/module" and m["platform"] == "linux-x64" and "targets" not in m, "Invalid legacy entrypoint/platform"
    for launch in launches(m).values():
        assert isinstance(launch, dict) and set(launch) == {"executable", "arguments"}, "Invalid launch"
        assert safe_path(launch["executable"]), "Executable must be package-relative"
        assert isinstance(launch["arguments"], list) and len(launch["arguments"]) <= 32
        assert all(isinstance(a, str) and len(a) <= 4096 and "\0" not in a for a in launch["arguments"])
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
    schemas = m.get("portSchemas", {})
    assert isinstance(schemas, dict) and set(schemas) <= {"inputs", "outputs"}
    for direction, entries in schemas.items():
        assert isinstance(entries, dict) and set(entries) <= set(m["ports"][direction])
        for schema in entries.values():
            validate_schema(schema)
    assert "uiLayout" not in m or isinstance(m["uiLayout"], dict), "Invalid custom UI layout"
    if "uiLayout" in m:
        validate_layout(m["uiLayout"], ids)
    return m


def safe_path(name):
    return isinstance(name, str) and 0 < len(name) <= 240 and not name.startswith(("/", ".")) and not re.search(r'[\\:<>"|?*\x00-\x1f]', name) and all(s not in ["", ".", ".."] and not s.endswith((".", " ")) and not re.match(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)', s, re.I) for s in name.split("/"))


def validate_schema(schema, depth=0):
    assert depth <= 8 and isinstance(schema, dict), "Invalid schema depth"
    assert schema.get("type") in ["any", "null", "boolean", "number", "string", "array", "object"]
    assert set(schema) <= {"type", "properties", "required", "additionalProperties", "items"}
    if "properties" in schema:
        assert schema["type"] == "object" and isinstance(schema["properties"], dict) and len(schema["properties"]) <= 64
        for key, child in schema["properties"].items():
            assert isinstance(key, str) and 0 < len(key) <= 64
            validate_schema(child, depth + 1)
    if "required" in schema:
        assert schema["type"] == "object" and isinstance(schema["required"], list) and len(schema["required"]) <= 64
        assert all(isinstance(k, str) and k in schema.get("properties", {}) for k in schema["required"])
    if "additionalProperties" in schema:
        assert schema["type"] == "object" and isinstance(schema["additionalProperties"], bool)
    if "items" in schema:
        assert schema["type"] == "array"
        validate_schema(schema["items"], depth + 1)


def pack(project, manifest, payload):
    """Package an already built, self-contained payload. Never download runtimes."""
    entries = [(project / "manifest.json", "manifest.json")]
    names = {"manifest.json"}
    for file in sorted(payload.rglob("*")):
        assert not file.is_symlink(), "Dereference runtime symlinks before packaging"
        if file.is_file():
            name = file.relative_to(payload).as_posix()
            assert safe_path(name) and name != "manifest.json", "Unsafe/duplicate payload path"
            assert name.lower() not in names, "Case-colliding paths are not portable"
            names.add(name.lower())
            if name.startswith("lib/"):
                assert re.search(r"(\.so(?:\.\d+)*|\.dll|\.dylib)$", name, re.I), "Only shared libraries in lib/"
            entries.append((file, name))
    for target, launch in launches(manifest).items():
        binary = payload / launch["executable"]
        assert binary.is_file(), f"Missing executable for {target}"
        assert matches(binary.read_bytes(), target), f"Wrong executable format/architecture for {target}"
    assert len(entries) <= 4096 and sum(f.stat().st_size for f, _ in entries) <= 256 * 1024 * 1024, "Package too large"
    assert (project / "manifest.json").stat().st_size <= 65536, "Manifest too large"
    out = project / "dist"
    out.mkdir(exist_ok=True)
    package = out / f'{manifest["id"]}-{manifest["version"]}.qmod'
    with tempfile.TemporaryDirectory(dir=out) as staging:
        temporary = pathlib.Path(staging) / "package.qmod"
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED) as archive:
            for file, name in entries:
                archive.write(file, name)
        assert temporary.stat().st_size <= 256 * 1024 * 1024, "ZIP including headers exceeds package limit"
        shutil.move(temporary, package)
    print(package)


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
    parser.add_argument("command", choices=["create", "check", "build", "pack"])
    parser.add_argument("project", type=pathlib.Path)
    parser.add_argument("--payload", type=pathlib.Path, help="Prebuilt self-contained payload directory")
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
    if args.command == "pack":
        pack(project, manifest, (args.payload or project / "payload").resolve())
        return
    assert manifest["runtime"] == "native-process-v1", "Use pack for language-neutral process-v1 payloads"
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
