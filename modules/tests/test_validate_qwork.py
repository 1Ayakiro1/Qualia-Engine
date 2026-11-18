import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "tools" / "validate_qwork.py"


def package(project=None):
    return {
        "format": "qualia-workspace-folder",
        "version": 1,
        "schemaVersion": 1,
        "workspaceId": "demo",
        "name": "Demo",
        "files": {
            "project": "workspace/project.json",
            "entities": "workspace/entities.json",
            "variables": "workspace/variables.json",
            "state": "workspace/state.json",
        },
    }, {
        "format": "qualia-workspace",
        "version": 1,
        "project": project or {
            "id": "demo",
            "name": "Demo",
            "description": "",
            "nodes": [{
                "id": "node-a",
                "kind": "module",
                "module": {"slug": "demo", "version": "1.0.0", "manifest": {
                    "ports": {"inputs": ["input"], "outputs": ["output"]}
                }},
                "inputs": ["input"],
                "outputs": ["output"],
            }],
            "links": [],
            "annotations": [],
        },
        "dependencies": [],
    }


class ValidateQworkTests(unittest.TestCase):
    def run_validator(self, archive):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--json", str(archive)],
            check=False,
            capture_output=True,
            text=True,
        )
        return result.returncode, json.loads(result.stdout)

    def write_archive(self, root, manifest, project, **extra):
        archive = root / "workspace.qwork"
        with zipfile.ZipFile(archive, "w") as output:
            files = {
                "manifest.json": manifest,
                "workspace/project.json": project,
                "workspace/entities.json": [],
                "workspace/variables.json": [],
                "workspace/state.json": {},
                **extra,
            }
            for name, value in files.items():
                output.writestr(name, json.dumps(value))
        return archive

    def test_valid_package(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, project = package()
            code, result = self.run_validator(
                self.write_archive(Path(directory), manifest, project)
            )
            self.assertEqual(code, 0)
            self.assertTrue(result["ok"])

    def test_missing_port_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, project = package()
            project["project"]["links"] = [{
                "source": "node-a", "output": "missing",
                "target": "node-a", "input": "input",
            }]
            code, result = self.run_validator(
                self.write_archive(Path(directory), manifest, project)
            )
            self.assertEqual(code, 1)
            self.assertFalse(result["ok"])
            self.assertTrue(result["diagnostics"])

    def test_state_file_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, project = package()
            archive = Path(directory) / "workspace.qwork"
            with zipfile.ZipFile(archive, "w") as output:
                for name, value in {
                    "manifest.json": manifest,
                    "workspace/project.json": project,
                    "workspace/entities.json": [],
                    "workspace/variables.json": [],
                }.items():
                    output.writestr(name, json.dumps(value))
            code, result = self.run_validator(archive)
            self.assertEqual(code, 1)
            self.assertFalse(result["ok"])


if __name__ == "__main__":
    unittest.main()
