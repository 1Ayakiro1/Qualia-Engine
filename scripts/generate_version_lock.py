#!/usr/bin/env python3
"""Generate qualia.lock.json from VERSION, pubspec and pubspec.lock."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def direct_dependencies(pubspec: str) -> set[str]:
    result: set[str] = set()
    section = None
    for line in pubspec.splitlines():
        if line and not line.startswith(" "):
            section = line.rstrip(":")
        if section == "dependencies" and re.match(r"^  [a-zA-Z0-9_]+:", line):
            result.add(line.strip().split(":", 1)[0])
    return result


def resolved_packages(lock: str) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    blocks = re.split(r"(?m)^  (?=[a-zA-Z0-9_]+:\n)", lock)[1:]
    for block in blocks:
        lines = block.splitlines()
        name = lines[0].rstrip(":")
        version = next((line.split(":", 1)[1].strip().strip('"') for line in lines if line.strip().startswith("version:")), None)
        source = next((line.split(":", 1)[1].strip().strip('"') for line in lines if line.strip().startswith("source:")), "unknown")
        sha = next((line.split(":", 1)[1].strip().strip('"') for line in lines if line.strip().startswith("sha256:")), None)
        if version:
            entry = {"version": version, "source": source}
            if sha:
                entry["sha256"] = sha
            result[name] = entry
    return result


def main() -> int:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    packages = resolved_packages((ROOT / "app/pubspec.lock").read_text(encoding="utf-8"))
    direct = direct_dependencies((ROOT / "app/pubspec.yaml").read_text(encoding="utf-8"))
    application = {name: packages[name] for name in sorted(direct) if name in packages}
    plugin_names = {name for name in packages if any(token in name for token in ("_linux", "_windows", "_macos", "_android", "_ios", "_platform_interface"))}
    plugins = {name: packages[name] for name in sorted(plugin_names)}
    lock = {
        "format": "qualia-lock", "lockVersion": 1,
        "generatedBy": "scripts/generate_version_lock.py",
        "engine": {"name": "Qualia Engine", "version": version, "coreVersion": version, "coreAbi": 3, "apiVersion": "1.0.0"},
        "contracts": {"moduleSchema": 1, "moduleProtocol": 1, "workspacePackage": 1, "coreAbi": 3, "supportedTargets": ["linux-x64", "linux-arm64", "windows-x64", "windows-arm64", "macos-x64", "macos-arm64"]},
        "toolchain": {"flutter": "3.47.5", "dart": ">=3.13.4 <4.0.0", "cmake": ">=3.21", "python": "3.12", "go": "1.23.6"},
        "dependencies": {"application": application, "plugins": plugins, "resolved": {name: packages[name] for name in sorted(packages)}, "native": {"catch2": {"version": "2.13.10", "sha256": "3725c0f0a75f376a5005dde31ead0feb8f7da7507644c201b814443de8355170"}}},
    }
    (ROOT / "qualia.lock.json").write_text(json.dumps(lock, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(ROOT / "qualia.lock.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
