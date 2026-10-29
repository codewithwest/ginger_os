# GingerOS Telemetry Contract v1 (proposal)

This is a UI-neutral, read-only contract for local system status. It is separate from the existing host-side build API documented in `docs/web_architecture.md`.

## Requirements

- No network listener and no background daemon in the first implementation.
- No root privileges required for ordinary metrics.
- No AI, display server, browser, or new third-party runtime dependency.
- Output is one JSON object per invocation; stdout contains JSON only, errors go to stderr.
- Missing metrics are `null`, not fabricated zero values.
- Version changes are explicit; clients must ignore unknown fields.

## Proposed schema

```json
{
  "schema_version": 1,
  "hostname": "gingeros",
  "uptime_seconds": 12345,
  "cpu": {
    "logical_count": 4,
    "load_1m": 0.42,
    "load_5m": 0.37,
    "load_15m": 0.31
  },
  "memory": {
    "total_bytes": 16777216000,
    "available_bytes": 12582912000
  },
  "filesystems": [
    {
      "mount": "/",
      "total_bytes": 32000000000,
      "available_bytes": 21000000000
    }
  ],
  "network": {
    "interfaces": [
      { "name": "eth0", "operstate": "up" }
    ]
  }
}
```

All numeric values use base units (seconds, bytes, logical CPUs). The sample values above are illustrative only.

## Field behavior

- `schema_version`: integer, currently `1`.
- `hostname`: system hostname, or `null` if unavailable.
- `uptime_seconds`: seconds since boot from `/proc/uptime`.
- `cpu.logical_count`: online logical CPU count from `/sys/devices/system/cpu/online` or a standard utility; unavailable becomes `null`.
- `cpu.load_*`: values from `/proc/loadavg`; unavailable becomes `null`.
- `memory.total_bytes` and `available_bytes`: parsed from `/proc/meminfo`, converting kB to bytes.
- `filesystems`: initially the root filesystem only; capacity values must come from a filesystem query and not an assumed image size.
- `network.interfaces`: interface names and operational state from `/sys/class/net`; loopback may be omitted. No packet contents, IP addresses, or external network probes are collected by default.

## Compatibility and security

This is a local status snapshot, not an authorization mechanism. Do not add privileged actions to this schema. Any future service transport (Unix socket or restricted HTTP) requires a separate design covering permissions, authentication/authorization, request limits, and lifecycle. Remote access must not be enabled by default.

Future clients—including terminal, native graphical, web, or custom shell UIs—consume this contract without owning the collectors. Presentation-specific state and styling do not belong here.

## Implementation and validation gate

Before wiring this into the installed image:
1. Implement the collector with no new runtime dependencies.
2. Test parsers with fixtures and test missing/malformed inputs.
3. Verify JSON schema shape and stable null behavior.
4. Confirm ordinary users can run it and that it has no side effects.
5. Build a fresh ISO and validate in QEMU; confirm terminal login, network/DNS, reboot, and failed-unit status.
6. Record idle resource overhead before considering periodic sampling or a daemon.
