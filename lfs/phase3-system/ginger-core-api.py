#!/usr/bin/env python3
"""Local read-only Ginger status API over a Unix domain socket."""

from __future__ import annotations

import json
import os
import signal
import socket
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any

SOCKET_PATH = Path("/run/ginger/core.sock")
TELEMETRY_COMMAND = "/usr/bin/ginger-telemetry"
MAX_REQUEST_BYTES = 4096
MAX_RESPONSE_BYTES = 65536
CLIENT_TIMEOUT_SECONDS = 2.0


def response_for(request: Any) -> dict[str, Any]:
    if not isinstance(request, dict) or request.get("op") != "status":
        return {"schema_version": 1, "status": "error", "error": "unsupported_request"}
    try:
        result = subprocess.run(
            [TELEMETRY_COMMAND],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=CLIENT_TIMEOUT_SECONDS,
            close_fds=True,
            env={"PATH": "/usr/bin:/bin", "LANG": "C"},
        )
        if result.returncode != 0 or len(result.stdout) > MAX_RESPONSE_BYTES:
            raise ValueError("collector_failed")
        telemetry = json.loads(result.stdout)
        if not isinstance(telemetry, dict) or telemetry.get("schema_version") != 1:
            raise ValueError("invalid_collector_response")
        return {"schema_version": 1, "status": "ok", "telemetry": telemetry}
    except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError):
        return {"schema_version": 1, "status": "error", "error": "status_unavailable"}


def handle_client(conn: socket.socket) -> None:
    conn.settimeout(CLIENT_TIMEOUT_SECONDS)
    data = bytearray()
    while len(data) <= MAX_REQUEST_BYTES:
        chunk = conn.recv(min(1024, MAX_REQUEST_BYTES + 1 - len(data)))
        if not chunk:
            break
        data.extend(chunk)
        if b"\n" in data:
            break
    if len(data) > MAX_REQUEST_BYTES or b"\n" not in data:
        payload = {"schema_version": 1, "status": "error", "error": "invalid_request"}
    else:
        try:
            line, _rest = bytes(data).split(b"\n", 1)
            payload = response_for(json.loads(line.decode("utf-8")))
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            payload = {"schema_version": 1, "status": "error", "error": "invalid_request"}
    encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8") + b"\n"
    conn.sendall(encoded[:MAX_RESPONSE_BYTES])


def main() -> int:
    SOCKET_PATH.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    try:
        current = SOCKET_PATH.lstat()
        if not stat.S_ISSOCK(current.st_mode):
            print("refusing to replace non-socket path", file=sys.stderr)
            return 1
        SOCKET_PATH.unlink()
    except FileNotFoundError:
        pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(str(SOCKET_PATH))
        os.chmod(SOCKET_PATH, 0o666)
        server.listen(8)
        server.settimeout(1.0)

        def stop(_signum: int, _frame: Any) -> None:
            raise KeyboardInterrupt

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        while True:
            try:
                conn, _ = server.accept()
            except socket.timeout:
                continue
            with conn:
                try:
                    handle_client(conn)
                except (OSError, TimeoutError):
                    continue
    except KeyboardInterrupt:
        return 0
    finally:
        server.close()
        try:
            SOCKET_PATH.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
