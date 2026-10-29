# Phase 2: Telemetry Jarvis Desktop Architecture

## Status

Proposal and implementation plan. This document does not add a desktop dependency or change the boot path.

## Goal

Make Ginger OS terminal-first by default, with a rich graphical UI that can be started on demand and stopped without stopping telemetry or assistant services. Keep LFS 13.0 as the base, target systems with 2+ CPU cores and 16 GB RAM, and validate every boot-critical change in QEMU.

## Non-goals for the first increment

- Do not commit Ginger OS to a single UI toolkit, framework, rendering engine, or visual design.
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

The first pass reviewed the current `master` tree and the existing interfaces. This is a source audit, not a build or runtime test.

### Existing components worth reusing

- The Go terminal UI at `ui/gotui` already uses Bubble Tea and Lip Gloss, and talks to the Python FastAPI server over HTTP and WebSocket.
- `server/server.py` currently exposes `GET /api/status` with build-engine status, CPU usage, storage, cores, and timers, plus build-control endpoints and `/ws/logs`.
- The React/Vite dashboard at `ui/web` is a separate client, but its current dependencies and design are dashboard-specific. It should remain one optional client, not become the platform API or a design constraint.
- The base system enables systemd-networkd, systemd-resolved, systemd-timesyncd, and `getty@tty1`. The current system configuration is compatible with a text-console-first approach.

### Important boundary

The existing FastAPI service is the **host-side build orchestrator**: its status schema is coupled to `GingerEngine`, and its documented actions can run/abort build steps, change build configuration, and manipulate snapshots. It is not yet a suitable always-on GingerOS runtime telemetry/assistant daemon. Do not install or repurpose it as a privileged in-OS service.

The Go TUI's hard-coded `localhost:8087` endpoints likewise target that build server. Reuse its interaction patterns where useful, but do not silently redirect it to a new OS API with incompatible semantics.

### Desktop dependency findings

The reviewed `lfs/phase3-system` directory has no existing X.Org, Wayland compositor, Mesa, or desktop-session recipe by those names. A display stack would therefore be a new LFS dependency surface and needs an explicit dependency/build-order audit. The first prototype should not add a compositor or X server yet.

### Next implementation increment

Create a UI-neutral **read-only telemetry contract/prototype** before adding display packages or AI runtime dependencies. It should:

- expose only non-privileged system facts such as uptime, CPU count/load, memory, filesystem capacity, and network link state;
- provide stable versioned JSON output and a documented schema;
- read from standard Linux interfaces and degrade gracefully when a metric is unavailable;
- avoid build-engine controls, network listeners, background daemons, and new third-party dependencies in the first slice;
- include deterministic tests using injected fixture data where practical;
- be runnable manually from the console and leave boot targets unchanged.

After this contract is reviewed, a separate change can decide whether to expose it through a local Unix socket, a restricted HTTP service, or CLI-only access. Do not bind a new service to the network by default.

## Display-stack evaluation

Openbox + X.Org is a candidate for a first prototype, not an architectural requirement. Evaluate it again only after the telemetry contract and build/dependency audit. Compare it with a lightweight Wayland option such as labwc using actual dependency count, build complexity, idle memory, startup latency, graphics compatibility, and recovery behavior.

No display stack is selected in this phase.

## Validation gates

For each meaningful implementation change:

1. Run focused unit/static checks for the changed component.
2. Build the relevant LFS recipes from a clean or documented cache state.
3. Build the ISO and test install/boot in QEMU when the change affects the installed system or boot path.
4. Verify console login, networking/DNS, clean shutdown/reboot, and `systemctl --failed --no-pager`.
5. Record measurements rather than asserting resource goals without evidence.

Do not claim performance targets are met until measurements are recorded. Do not treat host-side unit tests as a substitute for QEMU install/boot validation.

## Resource policy

- No graphical session or AI model is loaded automatically at boot in the initial design.
- Avoid unbounded polling, logging, and metric history.
- Use existing system interfaces where possible instead of duplicate collectors.
- Measure idle and active usage for each candidate.
- Keep the system useful when the graphical UI or AI service is absent.

## Git workflow

- Feature branch: `phase-2-telemetry-jarvis-desktop`
- Keep each increment reviewable and testable.
- Add tests and documentation with implementation changes.
- Open a draft PR for review; do not merge to `master` without explicit user approval.
