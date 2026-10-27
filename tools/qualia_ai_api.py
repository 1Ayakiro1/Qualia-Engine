#!/usr/bin/env python3
"""Deterministic JSON-RPC 2.0 API for AI-assisted Qualia development.

The service validates declarative contracts and returns reproducible plans and
forks. It never executes model-provided code, installs packages, starts a
module, writes the repository, or uses the network.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

API_VERSION = "1.0.0"
JSONRPC = "2.0"
LOCK_FORMAT = "qualia-lock"
LOCK_VERSION = 1
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
SAFE_ID = re.compile(r"^[a-z][a-z0-9-]{1,63}$")
PROTECTED = (".git/", "build/", "builds/", ".env", "secrets/")


class ApiError(Exception):
    def __init__(self, code: int, message: str, data: Any = None):
        super().__init__(message)
        self.code, self.message, self.data = code, message, data


def canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def load_lock(root: Path) -> dict[str, Any]:
    try:
        lock = json.loads((root / "qualia.lock.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ApiError(-32001, "Version lock is unavailable", str(exc)) from exc
    if lock.get("format") != LOCK_FORMAT or lock.get("lockVersion") != LOCK_VERSION:
        raise ApiError(-32001, "Unsupported version lock format")
    return lock


def diagnostic(message: str, path: str | None = None, code: str = "invalid") -> dict[str, Any]:
    item = {"severity": "error", "code": code, "message": message}
    if path:
        item["path"] = path
    return item


def result(items: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    return {"ok": not items, "diagnostics": items, **extra}


def validate_manifest(manifest: Any) -> dict[str, Any]:
    """Use the same offline SDK validator as module packaging."""
    if not isinstance(manifest, dict):
        return result([diagnostic("Manifest must be a JSON object.")])
    sdk_path = Path(__file__).resolve().parents[1] / "app/assets/module_sdk/qmod.py"
    spec = importlib.util.spec_from_file_location("qualia_qmod_sdk", sdk_path)
    if spec is None or spec.loader is None:
        return result([diagnostic("Module SDK cannot be loaded.", code="sdk_unavailable")])
    sdk = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sdk)
    with tempfile.TemporaryDirectory(prefix="qualia-ai-manifest-") as directory:
        project = Path(directory)
        (project / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        try:
            checked = sdk.check(project)
        except Exception as exc:
            return result([diagnostic(str(exc), code="manifest_invalid")])
    return result([], identity={"id": checked["id"], "version": checked["version"]}, schemaVersion=1)


def validate_workspace(package: Any) -> dict[str, Any]:
    items: list[dict[str, Any]] = []
    if not isinstance(package, dict):
        return result([diagnostic("Workspace package must be a JSON object.")])
    if package.get("format") != "qualia-workspace":
        items.append(diagnostic("Unsupported workspace package format.", "format"))
    if package.get("version") != 1:
        items.append(diagnostic("Only workspace package version 1 is supported.", "version"))
    project = package.get("project")
    if not isinstance(project, dict):
        return result(items + [diagnostic("package.project must be an object.", "project")])
    nodes, links = project.get("nodes", []), project.get("links", [])
    if not isinstance(nodes, list) or len(nodes) > 500:
        items.append(diagnostic("Workspace must contain at most 500 nodes.", "project.nodes")); nodes = []
    if not isinstance(links, list) or len(links) > 8000:
        items.append(diagnostic("Workspace must contain at most 8000 links.", "project.links")); links = []
    node_ids: set[str] = set()
    ports: dict[str, tuple[set[str], set[str]]] = {}
    for index, node in enumerate(nodes):
        path = f"project.nodes[{index}]"
        if not isinstance(node, dict) or not isinstance(node.get("id"), str):
            items.append(diagnostic("Each node needs a string id.", path)); continue
        node_id = node["id"]
        if node_id in node_ids:
            items.append(diagnostic("Node IDs must be unique.", path + ".id", "duplicate_id"))
        node_ids.add(node_id)
        if node.get("kind", "module") == "logic":
            ports[node_id] = ({"input"}, {"output"}); continue
        module = node.get("module")
        if not isinstance(module, dict):
            items.append(diagnostic("Module nodes need an embedded module reference.", path + ".module")); continue
        manifest = module.get("manifest")
        data = manifest.get("ports", {}) if isinstance(manifest, dict) else {}
        ports[node_id] = (
            set(data.get("inputs", [])) if isinstance(data, dict) else set(node.get("inputs", [])),
            set(data.get("outputs", [])) if isinstance(data, dict) else set(node.get("outputs", [])),
        )
        version = module.get("version")
        if isinstance(version, str) and not SEMVER.match(version):
            items.append(diagnostic("Module version must be SemVer.", path + ".module.version"))
    for index, link in enumerate(links):
        path = f"project.links[{index}]"
        if not isinstance(link, dict):
            items.append(diagnostic("Links must be objects.", path)); continue
        source, target = link.get("source"), link.get("target")
        if source not in node_ids or target not in node_ids:
            items.append(diagnostic("Link references a missing node.", path, "missing_node")); continue
        if source == target:
            items.append(diagnostic("A node cannot connect to itself.", path, "cycle"))
        if link.get("output") not in ports.get(source, (set(), set()))[1]:
            items.append(diagnostic("Link output port is not declared.", path + ".output", "missing_port"))
        if link.get("input") not in ports.get(target, (set(), set()))[0]:
            items.append(diagnostic("Link input port is not declared.", path + ".input", "missing_port"))
    dependencies = package.get("dependencies", [])
    if not isinstance(dependencies, list):
        items.append(diagnostic("dependencies must be an array.", "dependencies")); dependencies = []
    return result(items, revision=package.get("revision"), dependencyCount=len(dependencies), nodeCount=len(nodes), linkCount=len(links))


def engine_context(root: Path) -> dict[str, Any]:
    lock = load_lock(root)
    return {
        "api": {"name": "qualia-ai", "version": API_VERSION, "jsonrpc": JSONRPC},
        "engine": lock["engine"], "contracts": lock["contracts"], "dependencies": lock["dependencies"],
        "capabilities": ["engine.context", "engine.plan_change", "module.validate", "workspace.validate", "workspace.fork", "version.compare"],
        "safety": {"executesModelCode": False, "writesRepository": False, "installsDependencies": False, "networkAccess": False},
    }


def plan_change(params: dict[str, Any]) -> dict[str, Any]:
    kind, summary, files = params.get("kind"), params.get("summary"), params.get("files", [])
    allowed = {"module", "ui", "core", "dependency", "plugin", "documentation"}
    items: list[dict[str, Any]] = []
    if kind not in allowed: items.append(diagnostic(f"kind must be one of: {', '.join(sorted(allowed))}.", "kind"))
    if not isinstance(summary, str) or not summary.strip(): items.append(diagnostic("summary is required.", "summary"))
    if not isinstance(files, list) or len(files) > 128 or any(not isinstance(f, str) for f in files):
        items.append(diagnostic("files must contain at most 128 path strings.", "files")); files = []
    for index, file in enumerate(files):
        normalized = file.replace("\\", "/")
        if normalized.startswith("/") or ".." in normalized.split("/") or any(normalized == p or normalized.startswith(p) for p in PROTECTED):
            items.append(diagnostic("Path is outside the supported source surface.", f"files[{index}]", "protected_path"))
    bump = {"module": "patch", "ui": "patch", "documentation": "patch", "dependency": "minor", "plugin": "minor", "core": "minor"}.get(kind, "patch")
    return result(items, plan={"kind": kind, "summary": summary, "files": files, "versionBump": bump, "requiresReview": kind in {"core", "dependency", "plugin"}, "requiredChecks": ["scripts/check_version.sh", "scripts/check_versions.py", "scripts/analyze.sh"]})


def fork_workspace(params: dict[str, Any]) -> dict[str, Any]:
    package = copy.deepcopy(params.get("package")); checked = validate_workspace(package)
    if not checked["ok"]: raise ApiError(-32602, "Cannot fork an invalid workspace", checked)
    fork_id = params.get("forkId")
    if not isinstance(fork_id, str) or not SAFE_ID.match(fork_id): raise ApiError(-32602, "forkId must match ^[a-z][a-z0-9-]{1,63}$")
    project = package["project"]; parent = package.get("revision", {}).get("revision") if isinstance(package.get("revision"), dict) else None
    project["id"] = fork_id; project["name"] = params.get("name") or f"{project.get('name', 'Workspace')} (fork)"
    if "description" in params: project["description"] = params["description"]
    package["revision"] = {"revision": f"fork-{fork_id}-{digest(package)[:12]}", "parentRevision": parent, "parentDigest": digest(params.get("package")), "kind": "fork"}
    package["packageDigest"] = digest({k: v for k, v in package.items() if k != "packageDigest"})
    return {"package": package, "revision": package["revision"], "digest": package["packageDigest"]}


def semver_key(value: str) -> tuple[Any, ...]:
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$", value)
    if not match: raise ApiError(-32602, "Invalid SemVer")
    if match.group(4) is None:
        prerelease = (1,)
    else:
        identifiers = []
        for item in match.group(4).split('.'):
            identifiers.append((0, int(item)) if item.isdigit() else (1, item))
        prerelease = (0, *identifiers)
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)), prerelease)


def dispatch(method: str, params: Any, root: Path) -> Any:
    params = params if isinstance(params, dict) else {}
    if method in {"initialize", "engine.context"}: return engine_context(root)
    if method == "module.validate": return validate_manifest(params.get("manifest"))
    if method == "workspace.validate": return validate_workspace(params.get("package"))
    if method == "workspace.fork": return fork_workspace(params)
    if method == "engine.plan_change": return plan_change(params)
    if method == "version.compare":
        left, right = params.get("left"), params.get("right")
        if not isinstance(left, str) or not isinstance(right, str): raise ApiError(-32602, "left and right must be SemVer strings")
        a, b = semver_key(left), semver_key(right)
        return {"left": left, "right": right, "comparison": -1 if a < b else 1 if a > b else 0}
    raise ApiError(-32601, f"Method not found: {method}")


def handle(request: Any, root: Path) -> dict[str, Any] | None:
    if not isinstance(request, dict) or request.get("jsonrpc") != JSONRPC or not isinstance(request.get("method"), str): raise ApiError(-32600, "Invalid JSON-RPC request")
    if "id" not in request: dispatch(request["method"], request.get("params"), root); return None
    try: return {"jsonrpc": JSONRPC, "id": request.get("id"), "result": dispatch(request["method"], request.get("params"), root)}
    except ApiError as exc:
        error = {"code": exc.code, "message": exc.message};
        if exc.data is not None: error["data"] = exc.data
        return {"jsonrpc": JSONRPC, "id": request.get("id"), "error": error}
    except Exception as exc: return {"jsonrpc": JSONRPC, "id": request.get("id"), "error": {"code": -32603, "message": "Internal API error", "data": str(exc)}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1]); root = parser.parse_args().root.resolve()
    for line in sys.stdin:
        try:
            response = handle(json.loads(line), root)
        except ApiError as exc: response = {"jsonrpc": JSONRPC, "id": None, "error": {"code": exc.code, "message": exc.message}}
        except json.JSONDecodeError as exc: response = {"jsonrpc": JSONRPC, "id": None, "error": {"code": -32700, "message": "Parse error", "data": str(exc)}}
        if response is not None: print(json.dumps(response, ensure_ascii=False, separators=(",", ":")), flush=True)
    return 0


if __name__ == "__main__": raise SystemExit(main())
