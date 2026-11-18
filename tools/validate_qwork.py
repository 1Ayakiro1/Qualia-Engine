#!/usr/bin/env python3
"""Validate a portable Qualia .qwork workspace package without Flutter.

The validator is intentionally read-only and deterministic: it checks the
public archive manifest, JSON documents, graph limits, IDs, links and schema
version. It never installs modules or executes package-provided code.
"""
from __future__ import annotations

import argparse
import json
import sys
import zipfile
from pathlib import Path
from typing import Any

FORMAT = "qualia-workspace-folder"
VERSION = 1
MAX_NODES = 500
MAX_LINKS = 8000
MAX_ANNOTATIONS = 200
MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_ENTRIES = 32
REQUIRED = {
    "manifest.json",
    "workspace/project.json",
    "workspace/entities.json",
    "workspace/variables.json",
    "workspace/state.json",
}


def error(message: str, path: str = "") -> dict[str, str]:
    result = {"severity": "error", "message": message}
    if path:
        result["path"] = path
    return result


def read_json(archive: zipfile.ZipFile, name: str) -> Any:
    try:
        info = archive.getinfo(name)
        if info.file_size > MAX_FILE_BYTES:
            raise ValueError("file is too large")
        return json.loads(archive.read(info).decode("utf-8"))
    except (KeyError, OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise ValueError(f"invalid JSON in {name}: {exc}") from exc


def validate(path: Path) -> list[dict[str, str]]:
    diagnostics: list[dict[str, str]] = []
    if path.stat().st_size > MAX_FILE_BYTES:
        return [error(".qwork archive is too large")]
    try:
        with zipfile.ZipFile(path) as archive:
            if len(archive.infolist()) > MAX_ENTRIES:
                return [error(f"archive contains more than {MAX_ENTRIES} files")]
            total_uncompressed = 0
            for info in archive.infolist():
                if info.filename.startswith("/") or ".." in Path(info.filename).parts:
                    diagnostics.append(error("archive contains an unsafe path", info.filename))
                total_uncompressed += info.file_size
            if total_uncompressed > MAX_FILE_BYTES:
                return [error(".qwork contents are too large")]
            names = set(archive.namelist())
            missing = sorted(REQUIRED - names)
            if missing:
                return [error(f"archive lacks {item}") for item in missing]
            manifest = read_json(archive, "manifest.json")
            if not isinstance(manifest, dict) or manifest.get("format") != FORMAT:
                diagnostics.append(error("unsupported workspace format", "manifest.format"))
            if not isinstance(manifest, dict) or manifest.get("version") != VERSION:
                diagnostics.append(error("only workspace format version 1 is supported", "manifest.version"))
            package = read_json(archive, "workspace/project.json")
            entities = read_json(archive, "workspace/entities.json")
            variables = read_json(archive, "workspace/variables.json")
    except (OSError, zipfile.BadZipFile, ValueError) as exc:
        return [error(str(exc))]

    if not isinstance(package, dict) or package.get("format") != "qualia-workspace" or package.get("version") != 1:
        diagnostics.append(error("project.json must be a version 1 qualia-workspace package", "workspace/project.json"))
        return diagnostics
    project = package.get("project")
    if not isinstance(project, dict):
        diagnostics.append(error("project.json must contain a project object", "workspace/project.json.project"))
        return diagnostics
    nodes = project.get("nodes", [])
    links = project.get("links", [])
    annotations = project.get("annotations", [])
    if not isinstance(nodes, list) or len(nodes) > MAX_NODES:
        diagnostics.append(error(f"project.nodes must contain at most {MAX_NODES} items", "project.nodes"))
        nodes = []
    if not isinstance(links, list) or len(links) > MAX_LINKS:
        diagnostics.append(error(f"project.links must contain at most {MAX_LINKS} items", "project.links"))
        links = []
    if not isinstance(annotations, list) or len(annotations) > MAX_ANNOTATIONS:
        diagnostics.append(error(f"project.annotations must contain at most {MAX_ANNOTATIONS} items", "project.annotations"))
    ids: set[str] = set()
    ports: dict[str, tuple[set[str], set[str]]] = {}
    for index, node in enumerate(nodes):
        path_name = f"project.nodes[{index}]"
        if not isinstance(node, dict) or not isinstance(node.get("id"), str) or not node["id"]:
            diagnostics.append(error("node needs a non-empty string id", path_name))
            continue
        node_id = node["id"]
        if node_id in ids:
            diagnostics.append(error("node IDs must be unique", path_name + ".id"))
        ids.add(node_id)
        if node.get("kind", "module") == "logic":
            logic_outputs = {
                "condition": {"true", "false"},
                "validate": {"valid", "invalid"},
                "script": {"output", "true", "false", "valid", "invalid"},
            }
            ports[node_id] = ({"input"}, logic_outputs.get(node.get("logicType"), {"output"}))
        else:
            module = node.get("module")
            manifest = module.get("manifest", {}) if isinstance(module, dict) else {}
            declared = manifest.get("ports", {}) if isinstance(manifest, dict) else {}
            ports[node_id] = (
                set(declared.get("inputs", node.get("inputs", ["input"]))) if isinstance(declared, dict) else set(node.get("inputs", ["input"])),
                set(declared.get("outputs", node.get("outputs", ["output"]))) if isinstance(declared, dict) else set(node.get("outputs", ["output"])),
            )
    for index, link in enumerate(links):
        path_name = f"project.links[{index}]"
        if not isinstance(link, dict):
            diagnostics.append(error("link must be an object", path_name))
            continue
        source, target = link.get("source"), link.get("target")
        if source not in ids or target not in ids:
            diagnostics.append(error("link references a missing node", path_name))
            continue
        if source == target:
            diagnostics.append(error("a node cannot connect to itself", path_name))
        if link.get("output") not in ports[source][1]:
            diagnostics.append(error("link output port is not declared", path_name + ".output"))
        if link.get("input") not in ports[target][0]:
            diagnostics.append(error("link input port is not declared", path_name + ".input"))
    if not isinstance(entities, list) or not isinstance(variables, list):
        diagnostics.append(error("entities.json and variables.json must be arrays"))
    return diagnostics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help=".qwork archive to validate")
    parser.add_argument("--json", action="store_true", help="emit machine-readable diagnostics")
    args = parser.parse_args()
    try:
        diagnostics = validate(args.path.resolve())
    except OSError as exc:
        diagnostics = [error(str(exc))]
    result = {"ok": not diagnostics, "format": FORMAT, "version": VERSION, "diagnostics": diagnostics}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print("OK: valid .qwork workspace" if result["ok"] else "INVALID: .qwork workspace")
        for item in diagnostics:
            print(f"- {item.get('path', 'document')}: {item['message']}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
