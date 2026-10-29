#!/usr/bin/env python3
"""Regression tests for the rootfs archive validator used by the ISO builder."""
import pathlib
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "lfs" / "iso" / "purge-rootfs.py"
REQUIRED = (
    "etc/passwd",
    "etc/group",
    "etc/os-release",
    "usr/bin/bash",
    "usr/bin/sh",
    "usr/lib/systemd/systemd",
    "usr/lib/systemd/system/multi-user.target",
)


def create_archive(path, entries):
    with tarfile.open(path, "w:gz") as archive:
        for name in entries:
            info = tarfile.TarInfo(name)
            info.size = 0
            archive.addfile(info)


class RootfsValidationTests(unittest.TestCase):
    def run_check(self, archive):
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--check", str(archive)],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_accepts_required_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = pathlib.Path(tmp) / "valid.tar.gz"
            create_archive(archive, REQUIRED)
            result = self.run_check(archive)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_missing_systemd(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = pathlib.Path(tmp) / "missing-systemd.tar.gz"
            create_archive(archive, [p for p in REQUIRED if p != "usr/lib/systemd/systemd"])
            result = self.run_check(archive)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("usr/lib/systemd/systemd", result.stderr)

    def test_rejects_build_tree_contamination(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = pathlib.Path(tmp) / "contaminated.tar.gz"
            create_archive(archive, [*REQUIRED, "sources/"])
            result = self.run_check(archive)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("forbidden", result.stderr)

    def test_rejects_invalid_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = pathlib.Path(tmp) / "invalid.tar.gz"
            archive.write_text("not a tarball", encoding="utf-8")
            result = self.run_check(archive)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("cannot read rootfs archive", result.stderr)


if __name__ == "__main__":
    unittest.main()
