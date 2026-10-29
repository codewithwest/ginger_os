#!/usr/bin/env python3
"""Emit a read-only, UI-neutral GingerOS system telemetry snapshot as JSON."""

from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path
from typing import Any


PROC = Path("/proc")
SYS = Path("/sys")
ROOT = Path("/")


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return None


def parse_cpu_count(online: str | None) -> int | None:
    if not online:
        return os.cpu_count()
    try:
        total = 0
        for part in online.split(","):
            bounds = part.split("-", 1)
            start = int(bounds[0])
            end = int(bounds[1]) if len(bounds) == 2 else start
            if start < 0 or end < start:
                return None
            total += end - start + 1
        return total
    except (ValueError, TypeError):
        return None


def parse_loadavg(value: str | None) -> tuple[float | None, float | None, float | None]:
    if not value:
        return None, None, None
    try:
        fields = value.split()
        return float(fields[0]), float(fields[1]), float(fields[2])
    except (ValueError, IndexError):
        return None, None, None


def parse_meminfo(value: str | None) -> dict[str, int | None]:
    values: dict[str, int] = {}
    if value:
        for line in value.splitlines():
            key, sep, rest = line.partition(":")
            if not sep:
                continue
            fields = rest.split()
            if not fields:
                continue
            try:
                amount = int(fields[0])
                unit = fields[1] if len(fields) > 1 else ""
                values[key] = amount * 1024 if unit == "kB" else amount
            except ValueError:
                continue
    return {
        "total_bytes": values.get("MemTotal"),
        "available_bytes": values.get("MemAvailable"),
    }


def filesystem_snapshot(path: Path = ROOT) -> dict[str, Any]:
    try:
        stats = os.statvfs(path)
        block_size = stats.f_frsize or stats.f_bsize
        return {
            "mount": str(path),
            "total_bytes": stats.f_blocks * block_size,
            "available_bytes": stats.f_bavail * block_size,
        }
    except OSError:
        return {
            "mount": str(path),
            "total_bytes": None,
            "available_bytes": None,
        }


def network_interfaces(sys_class_net: Path = SYS / "class" / "net") -> list[dict[str, str | None]]:
    interfaces: list[dict[str, str | None]] = []
    try:
        names = sorted(p.name for p in sys_class_net.iterdir() if p.name != "lo")
    except OSError:
        return interfaces
    for name in names:
        interfaces.append(
            {"name": name, "operstate": read_text(sys_class_net / name / "operstate")}
        )
    return interfaces


def collect_snapshot(
    proc: Path = PROC,
    sys_root: Path = SYS,
    root: Path = ROOT,
) -> dict[str, Any]:
    uptime_text = read_text(proc / "uptime")
    uptime: int | None = None
    if uptime_text:
        try:
            uptime = max(0, int(float(uptime_text.split()[0])))
        except (ValueError, IndexError):
            uptime = None

    load_1m, load_5m, load_15m = parse_loadavg(read_text(proc / "loadavg"))
    memory = parse_meminfo(read_text(proc / "meminfo"))
    try:
        hostname: str | None = socket.gethostname() or None
    except OSError:
        hostname = None

    return {
        "schema_version": 1,
        "hostname": hostname,
        "uptime_seconds": uptime,
        "cpu": {
            "logical_count": parse_cpu_count(read_text(sys_root / "devices" / "system" / "cpu" / "online")),
            "load_1m": load_1m,
            "load_5m": load_5m,
            "load_15m": load_15m,
        },
        "memory": memory,
        "filesystems": [filesystem_snapshot(root)],
        "network": {
            "interfaces": network_interfaces(sys_root / "class" / "net")
        },
    }


def main() -> int:
    try:
        json.dump(collect_snapshot(), sys.stdout, sort_keys=True, separators=(",", ":"))
        sys.stdout.write("\n")
        return 0
    except (KeyboardInterrupt, BrokenPipeError):
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
