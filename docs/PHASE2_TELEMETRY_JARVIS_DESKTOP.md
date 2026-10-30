# Phase 2: Telemetry Jarvis Desktop Architecture

## Status

The initial architecture proposal and the first read-only telemetry CLI implementation are on the feature branch. This remains a staged implementation: no graphical stack, always-on telemetry daemon, or AI runtime is installed by this increment.

## Goal

Make GingerOS terminal-first by default, with a rich graphical UI that can be started on demand and stopped without stopping telemetry or assistant services. Keep LFS 13.0 as the base. The reference target is 2+ CPU cores and 16 GB RAM, but this is not a minimum requirement: GingerOS must remain useful on lower-end systems. Validate boot-critical changes in QEMU at both a lightweight profile and the target profile where practical.

## Non-goals for the first increment

- Do not commit GingerOS to a single UI toolkit, framework, rendering engine, or visual design.
- Do not make a browser, compositor, window manager, or local AI model mandatory at boot.
- Do not replace the existing terminal UI or web dashboard before evaluating what can be reused.
- Do not introduce a custom package manager or a large desktop environment without a demonstrated need.
- Do not change `master` directly; work on a feature branch and merge only after explicit approval.

## Architecture principles

### 1. Separate system services from presentation

The core owns system operations and exposes documented, versioned interfaces. User interfaces are clients of those interfaces; they do not own telemetry collection or privileged system actions.

Proposed logical layers:

1. **Ginger Core** — existing OS services and a small local service/API for status and permitted actions.
2. **Telemetry provider** — collects a small, explicit set of metrics (CPU, memory, disk, network, service state) with bounded sampling and retention.
3. **Assistant provider** — optional local-first Jarvis service. It must remain independently startable/stoppable and must not be required for boot or desktop use.
4. **Presentation clients** — terminal UI, future native graphical UI, future web UI, and possible third-party interfaces. Any client can be replaced without changing core service contracts.
5. **Display-session launcher** — starts a chosen graphical session on request and exits it cleanly. It must not be the owner of telemetry or assistant state.

### 2. Preserve future UI freedom

The backend contract must be UI-neutral. Prefer a small versioned local API and/or stable CLI/JSON interface with documented schemas. Do not expose internal implementation details as the public contract.

Potential clients may include a native toolkit, a web-based dashboard, a custom compositor/shell, remote clients, or future visual designs. No choice is made among these in this proposal.

UI-specific code, styles, components, and assets must remain outside the core telemetry/assistant packages. Design tokens and reusable components may be adopted later without changing the service API.

### 3. Terminal-first, graphical on demand

- Default boot remains a usable text console and current services.
- A user command (eventually `ginger desktop`) starts the selected graphical session.
- Exiting the graphical session returns to the terminal.
- A `status` command reports whether the graphical session is running.
- A stop command requests a graceful session shutdown; it must not kill unrelated processes.
- The graphical stack is optional and must not be a dependency of the base boot target.
- If the graphics stack fails, the text console and SSH/network recovery paths remain usable.

Command names in this document are proposals, not implemented commands.

## Repository audit (2026-10-29)

This is a source audit, not a full image build or runtime test.

### Existing components worth reusing

- The Go terminal UI at `ui/gotui` already uses Bubble Tea and Lip Gloss, and talks to the Python FastAPI server over HTTP and WebSocket.
- `server/server.py` currently exposes `GET /api/status` with build-engine status, CPU usage, storage, cores, and timers, plus build-control endpoints and `/ws/logs`.
- The React/Vite dashboard at `ui/web` is a separate client, but its current dependencies and design are dashboard-specific. It should remain one optional client, not become the platform API or a design constraint.
- The base system enables systemd-networkd, systemd-resolved, systemd-timesyncd, and `getty@tty1`. The current system configuration is compatible with a text-console-first approach.

### Important boundary

The existing FastAPI service is the **host-side build orchestrator**: its status schema is coupled to `GingerEngine`, and its documented actions can run/abort build steps, change build configuration, and manipulate snapshots. It is not yet a suitable always-on GingerOS runtime telemetry/assistant daemon. Do not install or repurpose it as a privileged in-OS service.

The Go TUI's hard-coded `localhost:8087` endpoints likewise target that build server. Reuse its interaction patterns where useful, but do not silently redirect it to a new OS API with incompatible semantics.

### Desktop dependency findings

The reviewed `lfs/phase3-system` directory has no existing X.Org, Wayland compositor, Mesa, or desktop-session recipe by those names. A display stack would therefore be a new LFS dependency surface and needs an explicit dependency/build-order audit. This increment does not add a compositor or X server.

## First implementation: read-only telemetry CLI

Added on this feature branch:

- `lfs/phase3-system/ginger-telemetry.py` — dependency-free collector using standard Python and Linux `/proc`, `/sys`, and filesystem interfaces.
- `lfs/phase3-system/92-ginger-telemetry.sh` — installs the command as `/usr/bin/ginger-telemetry` during Phase 3.
- `tests/test_telemetry.py` — unit tests for parsers, missing-data behavior, and JSON output.
- `docs/TELEMETRY_API_V1.md` — versioned output schema and compatibility/security rules.

Run manually with `ginger-telemetry`; output is one JSON snapshot. The command does not start a daemon, open a port, perform external probes, or make privileged changes. Missing values are represented as JSON `null`; the initial filesystem metric covers the root filesystem only. Network reporting includes interface names and operational state, not IP addresses or packet contents.

The first implementation intentionally does not add a transport API. A later change can evaluate a local Unix socket or restricted HTTP service after permission and lifecycle requirements are specified.

## Display-stack evaluation

Openbox + X.Org is a candidate for a first prototype, not an architectural requirement. Evaluate it only after the telemetry contract and build/dependency audit. Compare it with a lightweight Wayland option such as labwc using actual dependency count, build complexity, idle memory, startup latency, graphics compatibility, and recovery behavior.

No display stack is selected in this phase.

## Validation gates

For each meaningful implementation change:

1. Run focused unit/static checks for the changed component.
2. Build the relevant LFS recipes from a clean or documented cache state.
3. Build the ISO and test install/boot in QEMU when the change affects the installed system or boot path.
4. Verify console login, networking/DNS, clean shutdown/reboot, and `systemctl --failed --no-pager`.
5. Record measurements rather than asserting resource goals without evidence.

The source changes have been committed to the feature branch, but host tests, the LFS image build, ISO build, and QEMU validation still need to run before this increment is considered validated. Do not claim performance targets are met until measurements are recorded.

## Resource policy

- **Reference target, not minimum:** 2+ CPU cores and 16 GB RAM is the planning target for a fuller local AI workload, not a hard install or boot requirement.
- **Low-end baseline:** keep the core OS, shell, networking, telemetry CLI, and recovery paths useful on smaller systems (including a 2 GB RAM VM). This is a compatibility goal to test, not yet a certified minimum specification.
- No graphical session or AI model is loaded automatically at boot in the initial design.
- Optional components must be independently startable/stoppable. The core must not require the UI or assistant to be present.
- Assistant/model selection should account for available RAM and CPU, and should fail gracefully or offer a lighter mode instead of exhausting memory or blocking basic OS use.
- Avoid unbounded polling, logging, and metric history.
- Use existing system interfaces where possible instead of duplicate collectors.
- Measure idle and active memory, CPU, startup latency, and disk use for each candidate.
- Do not infer a machine's suitability from one telemetry snapshot; validate sustained workloads and memory pressure.
- Keep the system useful when the graphical UI or AI service is absent.

### Proposed hardware validation matrix

These are test profiles to measure, not promised performance tiers:

| VM profile | Validation focus |
| --- | --- |
| 2 vCPU / 2 GiB RAM | Boot, login, networking, telemetry, shell responsiveness, recovery |
| 2 vCPU / 4 GiB RAM | Core plus lightweight optional services |
| 4 vCPU / 8 GiB RAM | UI prototype and small-model feasibility measurements |
| 4+ vCPU / 16 GiB RAM | Reference profile for broader local assistant evaluation |

Do not download or load a large AI model as part of boot or the low-memory smoke test.

## Next implementation sequence

1. Complete fresh-ISO install/boot validation of the telemetry installer fix and record the QEMU memory/CPU profile used.
2. Keep telemetry as a stable, versioned read-only contract; add or adjust fields only with tests and schema documentation.
3. Design the local assistant/service boundary, lifecycle, permissions, and resource limits before adding a long-running daemon or network listener.
4. Evaluate optional desktop candidates against the same resource matrix before selecting a display stack.
5. Prototype the smallest useful local-first assistant capability separately from UI selection and model size.

## Git workflow

- Feature branch: `phase-2-telemetry-jarvis-desktop`
- Keep each increment reviewable and testable.
- Add tests and documentation with implementation changes.
- Open a draft PR for review; do not merge to `master` without explicit user approval.
