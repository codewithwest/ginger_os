# Phase 3: Local Ginger Core API

## Purpose

Build a small, local-only service boundary that lets terminal, graphical, and future assistant clients read GingerOS runtime status without coupling those clients to Linux internals or the host-side build orchestrator.

This phase follows the read-only `ginger-telemetry` CLI. The CLI remains useful on its own and must continue to work if the service is stopped, unavailable, or not installed.

## Scope for the first implementation

- A read-only local status API that returns a documented, versioned JSON response.
- A service lifecycle managed by systemd, with bounded resource use and clear logs.
- A local Unix-domain socket rather than a network listener.
- A small client command for checking service health and retrieving status.
- Tests for request parsing, schema stability, socket permissions, service failure, and graceful shutdown.
- No UI framework, display server, AI model, remote API, privileged action endpoint, or persistent telemetry database.

Do not implement a general-purpose command execution endpoint. Future system actions require a separate allowlisted design, authorization model, and audit trail.

## Architecture boundary

1. **Collector** — reuse the telemetry provider and Linux read-only interfaces; avoid duplicating metric logic.
2. **Local API service** — unprivileged where possible, serves only defined read-only requests.
3. **Client** — obtains status through the stable API; it does not depend on internal Python module names or process layout.
4. **Presentation** — clients remain replaceable. Terminal, native, web, and future custom UI designs can consume the same schema.
5. **Assistant** — a future optional client/provider, not a prerequisite for the service or boot.

The existing `server/server.py` stays a host-side build orchestrator and is not reused as the in-OS service.

## Proposed transport and contract

- Use a Unix-domain stream socket under `/run/ginger/`, with a dedicated system group or equivalent access policy.
- Do not bind TCP/UDP ports.
- Use a small HTTP-like protocol only if it can be implemented and maintained with existing LFS dependencies; otherwise prefer a documented newline-delimited JSON request/response protocol. Choose one during implementation and test malformed input, request-size limits, timeouts, and disconnects.
- Initial operation: read-only `status` request returning a response envelope containing `schema_version`, `status`, and the telemetry snapshot.
- Keep the existing telemetry fields and their meanings stable. Any new or renamed field requires schema documentation and tests.
- Bound request sizes, connection count, work per request, and logging. Do not continuously sample or store history in this phase.
- Socket permissions must prevent untrusted users from replacing the socket or reaching unintended operations. Do not rely on obscurity of the socket path as authorization.

The exact wire protocol is intentionally not frozen until a small implementation spike confirms what can be built and tested with the project's existing runtime.

## Service lifecycle and resilience

- Service starts on demand or through a lightweight systemd dependency only if measurements show the idle cost is negligible; do not make it a boot-critical dependency.
- Socket/runtime files are recreated safely on restart and cleaned up on shutdown.
- The service must not require networking, DNS, a graphical session, or Jarvis.
- A failed or stopped service must not affect login, shell, telemetry CLI, network recovery, or shutdown.
- Use systemd sandboxing and an unprivileged service account where compatible with the required read-only system interfaces. Avoid broad capabilities and writable host paths.
- Log errors concisely to journald; no unbounded file logs or metric retention.

## Resource and compatibility goals

The 16 GB RAM configuration is a reference target for broader local AI work, not a minimum for this API. The local status service should be small enough to evaluate on a 2 vCPU / 2 GiB RAM guest.

Measure rather than assume:
- idle resident memory and CPU,
- first-request and repeated-request latency,
- behavior with missing `/proc` or `/sys` data,
- operation under low memory,
- behavior when the socket directory is absent or has incorrect permissions.

The collector CLI should remain dependency-free beyond the system's existing Python runtime. Avoid introducing a large framework solely for a tiny local API.

## Security requirements

- Local-only Unix socket; no remote network exposure.
- Read-only status surface; no arbitrary shell, filesystem write, package install, service control, or configuration mutation endpoints.
- Strict request allowlist, input length limits, and bounded response size.
- Safe ownership/mode for runtime directory and socket.
- Avoid returning secrets, environment variables, IP addresses, packet contents, command-line arguments, or process environments in telemetry.
- Tests must verify that malformed or unknown requests fail closed.

## Acceptance criteria

1. Fresh LFS/rootfs build installs the service and client without changing the base LFS version.
2. `ginger-telemetry` continues to emit valid one-object JSON with no service running.
3. Local client can request status and parse the documented versioned response.
4. The socket is not exposed over TCP/UDP; local users can read only the documented non-secret status snapshot.
5. Service restart and shutdown leave no stale socket and do not hang.
6. Missing system metrics return null/empty values rather than crashing the service.
7. No network port is opened, and no UI or model starts at boot.
8. CI tests and ShellCheck pass; a fresh ISO is installed and smoke-tested in QEMU at 2 vCPU / 2 GiB and the reference 4 vCPU / 16 GiB profile when practical.
9. Record service memory/CPU use and response latency; do not claim the low-end goal is met without measurements.

## Implementation sequence

1. Inspect the existing LFS Python, systemd, user/group, and packaging conventions.
2. Prototype the smallest socket server/client and run unit tests outside the image.
3. Add a dedicated service account/group and hardened systemd unit only after confirming permission and lifecycle behavior.
4. Package through Phase 3, with an explicit way to force rebuild when recipe content changes.
5. Run CI, build a fresh ISO, install/boot in QEMU, and test the acceptance criteria.
6. Only after this boundary is stable, design the optional Jarvis provider and the on-demand display-session launcher.

## Branch and review

- Branch: `phase-3-local-core-api`
- Parent feature branch: `phase-2-telemetry-jarvis-desktop`
- Keep this as a draft until implementation and QEMU validation are complete.
- Do not merge to `master` without explicit user approval.
