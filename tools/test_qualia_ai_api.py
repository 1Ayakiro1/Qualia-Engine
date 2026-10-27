#!/usr/bin/env python3
import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API = ROOT / "tools/qualia_ai_api.py"


def call(method, params=None):
    request = {"jsonrpc": "2.0", "id": 1, "method": method}
    if params is not None:
        request["params"] = params
    completed = subprocess.run(
        ["python3", str(API)],
        input=json.dumps(request) + "\n",
        text=True,
        capture_output=True,
        check=True,
        cwd=ROOT,
    )
    return json.loads(completed.stdout)


class AiApiTests(unittest.TestCase):
    def test_context_exposes_contracts_and_safety_boundary(self):
        result = call("engine.context")["result"]
        self.assertEqual(result["contracts"]["moduleSchema"], 1)
        self.assertFalse(result["safety"]["executesModelCode"])
        self.assertIn("workspace.fork", result["capabilities"])

    def test_fork_preserves_parent_digest_and_creates_new_revision(self):
        package = {
            "format": "qualia-workspace",
            "version": 1,
            "project": {"id": "source", "name": "Source", "nodes": [], "links": []},
            "revision": {"revision": "r1"},
            "dependencies": [],
        }
        result = call("workspace.fork", {"package": package, "forkId": "child-fork"})["result"]
        self.assertEqual(result["revision"]["parentRevision"], "r1")
        self.assertNotEqual(result["package"]["project"]["id"], package["project"]["id"])
        self.assertNotEqual(result["digest"], "")

    def test_invalid_plan_is_reported_without_writing(self):
        result = call(
            "engine.plan_change",
            {"kind": "core", "summary": "test", "files": ["build/private"]},
        )["result"]
        self.assertFalse(result["ok"])
        self.assertEqual(result["diagnostics"][0]["code"], "protected_path")

    def test_semver_prerelease_numeric_order(self):
        result = call(
            "version.compare",
            {"left": "1.0.0-alpha.2", "right": "1.0.0-alpha.10"},
        )["result"]
        self.assertEqual(result["comparison"], -1)


if __name__ == "__main__":
    unittest.main()
