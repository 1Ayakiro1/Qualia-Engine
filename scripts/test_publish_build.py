#!/usr/bin/env python3
"""Publication regression tests, using fake artifacts and isolated directories."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.publish_build import publish


class PublishBuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="qualia-publish-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.builds = self.root / "builds"
        self.builds.mkdir()
        (self.builds / "README.md").write_text("Keep instructions")
        self.version = "0.5.2-dev.1"
        self.output = self.builds / self.version
        self.source = self.root / "stage"
        self.source.mkdir()
        for suffix in ["x86_64.AppImage", "linux-x64.tar.gz"]:
            (self.source / f"Qualia-Engine-{self.version}-{suffix}").write_bytes(b"new build")
        (self.source / "binary/lib").mkdir(parents=True)
        (self.source / "binary/bci_engine").write_bytes(b"executable")
        (self.source / "binary/lib/core.so").write_bytes(b"library")
        (self.source / "binary/lib/core.so.3").symlink_to("core.so")

    def run_publish(self, output=None):
        publish(self.source, output or self.output, self.version, "linux", self.builds)

    def test_only_current_version_remains_and_checksums_cover_bundle(self):
        (self.builds / "0.5.1").mkdir()
        (self.builds / "binary-previous-20261015-150013").mkdir()
        (self.builds / "Qualia-Engine-0.5.1-x86_64.AppImage").write_text("old")
        (self.builds / "notes.txt").write_text("user file")
        self.run_publish()
        self.assertEqual({p.name for p in self.builds.iterdir()},
                         {self.version, "README.md", "notes.txt"})
        for line in (self.output / "SHA256SUMS").read_text().splitlines():
            checksum, name = line.split("  ")
            self.assertEqual(checksum, hashlib.sha256((self.output / name).read_bytes()).hexdigest())
        self.assertTrue((self.output / "binary/lib/core.so.3").is_symlink())

    def test_repeated_publish_replaces_snapshot_without_backups_or_stale_sources(self):
        self.run_publish()
        (self.output / f"Qualia-Engine-{self.version}-source.zip").write_bytes(b"stale sources")
        (self.output / "VERIFICATION.md").write_text("stale checks")
        (self.source / "binary/bci_engine").write_bytes(b"updated")
        self.run_publish()
        self.assertEqual((self.output / "binary/bci_engine").read_bytes(), b"updated")
        self.assertFalse((self.output / "VERIFICATION.md").exists())
        self.assertEqual(len(list(self.builds.iterdir())), 2)
        self.assertFalse(list(self.root.glob(".build-publish-*")))

    def test_missing_format_leaves_previous_build_intact(self):
        self.run_publish()
        (self.source / f"Qualia-Engine-{self.version}-x86_64.AppImage").unlink()
        with self.assertRaises(ValueError):
            self.run_publish()
        self.assertEqual((self.output / "binary/bci_engine").read_bytes(), b"executable")

    def test_unknown_output_files_are_not_discarded(self):
        self.output.mkdir()
        (self.output / "my-notes.txt").write_text("user work")
        with self.assertRaises(ValueError):
            self.run_publish()
        self.assertTrue((self.output / "my-notes.txt").exists())

    def test_custom_output_does_not_prune_siblings_or_local_builds(self):
        custom = self.root / "ci-dist"
        (self.builds / "0.5.1").mkdir()
        self.run_publish(custom)
        self.assertTrue((custom / "SHA256SUMS").is_file())
        self.assertTrue((self.builds / "0.5.1").is_dir())

    def test_publication_failure_restores_previous_directory(self):
        self.run_publish()
        from scripts import publish_build
        original_replace = publish_build.os.replace

        def fail_install(source, target):
            if Path(source).name == "prepared":
                raise OSError("simulated installation error")
            original_replace(source, target)

        with patch.object(publish_build.os, "replace", side_effect=fail_install):
            with self.assertRaises(OSError):
                self.run_publish()
        self.assertEqual((self.output / "binary/bci_engine").read_bytes(), b"executable")

    def test_refuses_builds_root_and_symlink_destination(self):
        with self.assertRaises(ValueError):
            self.run_publish(self.builds)
        self.output.symlink_to(self.source, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.run_publish()


if __name__ == "__main__":
    unittest.main()
