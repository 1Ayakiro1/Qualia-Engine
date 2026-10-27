#!/usr/bin/env python3
"""Validate the engine/API/dependency version lock."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")


def fail(message: str) -> None:
    print(f"[versions] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    try:
        lock = json.loads((ROOT / "qualia.lock.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read qualia.lock.json: {exc}")
    if lock.get("format") != "qualia-lock" or lock.get("lockVersion") != 1:
        fail("unsupported lock format")
    if lock.get("engine", {}).get("version") != version:
        fail("lock engine version differs from VERSION")
    if not SEMVER.match(version):
        fail(f"invalid engine version: {version}")
    contracts = lock.get("contracts", {})
    expected = {"moduleSchema": 1, "moduleProtocol": 1, "workspacePackage": 1, "coreAbi": 3}
    for name, value in expected.items():
        if contracts.get(name) != value:
            fail(f"contracts.{name} must be {value}")
    dependencies = lock.get("dependencies")
    if not isinstance(dependencies, dict) or not dependencies.get("application") or not dependencies.get("plugins"):
        fail("lock must contain application and plugins dependency snapshots")
    for group in dependencies.values():
        if not isinstance(group, dict):
            fail("dependency groups must be objects")
        for name, entry in group.items():
            if not isinstance(name, str) or not isinstance(entry, dict) or not entry.get("version"):
                fail(f"invalid dependency entry: {name}")
    print(f"[versions] lock coherent: {version}; dependencies={sum(len(g) for g in dependencies.values())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
