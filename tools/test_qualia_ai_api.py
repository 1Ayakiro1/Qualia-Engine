#!/usr/bin/env python3
import json
import subprocess
import tempfile
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
        self.assertEqual(result["api"]["layer"], "external")
        self.assertEqual(result["api"]["version"], "1.1.0")
        self.assertEqual(result, call("initialize")["result"])

    def test_api_description_matches_sdk_lock_and_context(self):
        description = call("api.describe")["result"]
        sdk = json.loads((ROOT / "app/assets/module_sdk/api_layers.json").read_text())
        lock = json.loads((ROOT / "qualia.lock.json").read_text())
        self.assertEqual(description, sdk)
        self.assertEqual(description, lock["apiLayers"])
        self.assertEqual(description, call("engine.context")["result"]["apiLayers"])
        self.assertEqual(set(description["layers"]), {"internal", "middle", "external"})
        for layer, contract in description["layers"].items():
            with self.subTest(layer=layer):
                self.assertEqual(call("api.describe", {"layer": layer})["result"],
                                 {"layer": layer, **contract})
        ai = description["layers"]["external"]["bindings"]["aiDevelopment"]
        self.assertFalse(ai["runtimeControl"])
        self.assertEqual(ai["version"], lock["engine"]["apiVersion"])
        self.assertEqual(set(ai["methods"]),
                         {"initialize", *call("engine.context")["result"]["capabilities"]})
        self.assertEqual(description["layers"]["internal"]["routing"], "host-owned-links-only")
        self.assertEqual(description["layers"]["middle"]["protocol"], 1)

    def test_api_description_rejects_unknown_layers_and_invalid_params(self):
        for layer in ["core", "Internal", "", 1, [], {}, None]:
            with self.subTest(layer=layer):
                self.assertEqual(call("api.describe", {"layer": layer})["error"]["code"], -32602)
        for params in [[], 1, "internal"]:
            with self.subTest(params=params):
                self.assertEqual(call("api.describe", params)["error"]["code"], -32602)

    def test_discovery_rejects_unsupported_layer_descriptor(self):
        with tempfile.TemporaryDirectory(prefix="qualia-api-lock-") as directory:
            for description in [None, {"format": "qualia-api-layers", "schemaVersion": 2},
                                {"format": "qualia-api-layers", "schemaVersion": 1, "layers": {"core": {}}}]:
                with self.subTest(description=description):
                    lock = {"format": "qualia-lock", "lockVersion": 1, "apiLayers": description}
                    (Path(directory) / "qualia.lock.json").write_text(json.dumps(lock))
                    completed = subprocess.run(
                        ["python3", str(API), "--root", directory],
                        input=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "api.describe"}) + "\n",
                        text=True, capture_output=True, check=True,
                    )
                    self.assertEqual(json.loads(completed.stdout)["error"]["code"], -32001)

    def test_api_layer_change_plans_require_review_and_preserve_legacy_calls(self):
        params = {"kind": "module", "summary": "Change port contract", "files": ["modules/example/manifest.json"]}
        legacy = call("engine.plan_change", params)["result"]
        self.assertTrue(legacy["ok"])
        self.assertEqual(legacy["plan"]["apiLayers"], [])
        self.assertFalse(legacy["plan"]["requiresReview"])
        result = call("engine.plan_change", {**params, "apiLayers": ["middle", "internal", "middle"]})["result"]
        self.assertTrue(result["ok"])
        self.assertEqual(result["plan"]["apiLayers"], ["internal", "middle"])
        self.assertTrue(result["plan"]["requiresReview"])
        for layers in ["internal", ["core"], [1], [[]], None]:
            with self.subTest(layers=layers):
                invalid = call("engine.plan_change", {**params, "apiLayers": layers})["result"]
                self.assertFalse(invalid["ok"])
                self.assertEqual(invalid["diagnostics"][0]["path"], "apiLayers")

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
