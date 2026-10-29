#!/usr/bin/env python3
"""Unit tests for the dependency-free GingerOS telemetry collector."""

import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "lfs" / "phase3-system" / "ginger-telemetry.py"
SPEC = importlib.util.spec_from_file_location("ginger_telemetry", SCRIPT)
telemetry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(telemetry)


class TelemetryParserTests(unittest.TestCase):
    def test_cpu_ranges(self):
        self.assertEqual(telemetry.parse_cpu_count("0-3,5,7-8"), 7)
        self.assertEqual(telemetry.parse_cpu_count("0"), 1)
        self.assertIsNone(telemetry.parse_cpu_count("4-2"))
        self.assertIsNone(telemetry.parse_cpu_count("invalid"))

    def test_load_average(self):
        self.assertEqual(telemetry.parse_loadavg("0.42 0.37 0.31 1/90 123"), (0.42, 0.37, 0.31))
        self.assertEqual(telemetry.parse_loadavg("bad"), (None, None, None))
        self.assertEqual(telemetry.parse_loadavg(None), (None, None, None))

    def test_meminfo_converts_kilobytes_to_bytes(self):
        parsed = telemetry.parse_meminfo(
            "MemTotal:       16384 kB\nMemAvailable:    8192 kB\nBuffers: 12 kB\n"
        )
        self.assertEqual(parsed, {"total_bytes": 16 * 1024 * 1024, "available_bytes": 8 * 1024 * 1024})

    def test_missing_memory_is_null(self):
        self.assertEqual(telemetry.parse_meminfo(None), {"total_bytes": None, "available_bytes": None})

    def test_snapshot_uses_null_for_missing_proc_data(self):
        with tempfile.TemporaryDirectory() as temp:
            base = pathlib.Path(temp)
            proc = base / "proc"
            sys_root = base / "sys"
            root = base / "root"
            proc.mkdir()
            sys_root.mkdir()
            root.mkdir()
            result = telemetry.collect_snapshot(proc=proc, sys_root=sys_root, root=root)
        self.assertEqual(result["schema_version"], 1)
        self.assertIsNone(result["uptime_seconds"])
        self.assertIsNone(result["cpu"]["load_1m"])
        self.assertEqual(result["memory"]["total_bytes"], None)
        self.assertEqual(result["network"]["interfaces"], [])
        self.assertEqual(result["filesystems"][0]["mount"], str(root))

    def test_main_outputs_one_json_object(self):
        payload = {"schema_version": 1}
        with patch.object(telemetry, "collect_snapshot", return_value=payload):
            from io import StringIO
            output = StringIO()
            with patch.object(telemetry.sys, "stdout", output):
                self.assertEqual(telemetry.main(), 0)
        self.assertEqual(json.loads(output.getvalue()), payload)
        self.assertTrue(output.getvalue().endswith("\n"))


if __name__ == "__main__":
    unittest.main()
