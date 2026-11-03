#!/usr/bin/env python3
"""Small client for Ginger's local read-only core API."""

from __future__ import annotations

import json
import socket
import sys

SOCKET_PATH = "/run/ginger/core.sock"
TIMEOUT_SECONDS = 3.0
MAX_RESPONSE_BYTES = 65536


def main() -> int:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(TIMEOUT_SECONDS)
            client.connect(SOCKET_PATH)
            client.sendall(b'{"op":"status"}\n')
            data = bytearray()
            while len(data) <= MAX_RESPONSE_BYTES:
                chunk = client.recv(min(4096, MAX_RESPONSE_BYTES + 1 - len(data)))
                if not chunk:
                    break
                data.extend(chunk)
                if b"\n" in data:
                    break
        if len(data) > MAX_RESPONSE_BYTES or b"\n" not in data:
            raise ValueError("invalid response")
        payload = json.loads(bytes(data).split(b"\n", 1)[0].decode("utf-8"))
        if not isinstance(payload, dict) or payload.get("schema_version") != 1:
            raise ValueError("unsupported response schema")
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0 if payload.get("status") == "ok" else 1
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ginger-core: local API unavailable or invalid: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
