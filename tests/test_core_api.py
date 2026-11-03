#!/usr/bin/env python3
"""Tests for the local Ginger core API protocol and safe failure behavior."""

import importlib.util
import json
import pathlib
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "lfs" / "phase3-system" / "ginger-core-api.py"
SPEC = importlib.util.spec_from_file_location("ginger_core_api", SCRIPT)
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)


class CoreApiTests(unittest.TestCase):
    def test_rejects_unknown_operation(self):
        self.assertEqual(api.response_for({"op": "exec"}), {
            "schema_version": 1, "status": "error", "error": "unsupported_request"
        })

    def test_rejects_non_object_request(self):
        self.assertEqual(api.response_for([])["error"], "unsupported_request")

    @patch.object(api.subprocess, "run")
    def test_returns_versioned_telemetry(self, run):
        run.return_value.returncode = 0
        run.return_value.stdout = b'{"schema_version":1,"cpu":{"logical_count":2}}\n'
        self.assertEqual(api.response_for({"op": "status"}), {
            "schema_version": 1, "status": "ok",
            "telemetry": {"schema_version": 1, "cpu": {"logical_count": 2}}
        })
        self.assertEqual(run.call_args.args[0], ["/usr/bin/ginger-telemetry"])
        self.assertEqual(run.call_args.kwargs["timeout"], api.CLIENT_TIMEOUT_SECONDS)

    @patch.object(api.subprocess, "run")
    def test_collector_failure_is_generic(self, run):
        run.side_effect = OSError("private detail")
        self.assertEqual(api.response_for({"op": "status"}), {
            "schema_version": 1, "status": "error", "error": "status_unavailable"
        })

    @patch.object(api.subprocess, "run")
    def test_rejects_bad_collector_schema(self, run):
        run.return_value.returncode = 0
        run.return_value.stdout = b'{"schema_version":99}'
        self.assertEqual(api.response_for({"op": "status"})["status"], "error")

    def test_request_handler_rejects_oversized_unterminated_input(self):
        import socket
        server, client = socket.socketpair()
        try:
            client.sendall(b"x" * (api.MAX_REQUEST_BYTES + 1))
            client.shutdown(socket.SHUT_WR)
            api.handle_client(server)
            result = json.loads(client.recv(1024))
            self.assertEqual(result["error"], "invalid_request")
        finally:
            server.close()
            client.close()


if __name__ == "__main__":
    unittest.main()
