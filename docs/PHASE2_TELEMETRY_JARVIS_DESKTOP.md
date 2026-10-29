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

## Display-stack evaluation

Openbox + X.Org is a candidate for a first prototype, not an architectural requirement. Evaluate it against at least one lightweight Wayland option (for example labwc) using the actual LFS 13.0 dependency graph, input/graphics support, package build cost, session startup, and memory/CPU measurements. Do not select a stack based on screenshots or assumptions alone.

The first prototype should be a replaceable session adapter. The launcher and service contracts must not assume X11 or Wayland, so the display stack can change later.

## Proposed milestones

### A. Repository and dependency audit

- Inspect the current build phases, package recipes, kernel config, graphics/input support, D-Bus, logind, existing Go TUI, and React/FastAPI UI.
- Identify existing components that can be reused.
- Compare candidate display stacks and document required dependencies and licenses.
- Record a baseline build and runtime footprint before adding packages.

**Acceptance:** architecture decision record with dependency graph, build implications, alternatives, and rollback plan.

### B. Telemetry contract

- Define a versioned, local-only status interface and a JSON schema for CPU, memory, storage, network, and service health.
- Keep sampling intervals and history bounded and configurable.
- Restrict sensitive data and avoid collecting command arguments, credentials, or arbitrary user content.
- Ensure telemetry remains available independently of graphical sessions.

**Acceptance:** unit tests for schema and provider; a terminal client can read status while no graphical session is running.

### C. On-demand display-session prototype

- Implement a launcher/adapter that can start and stop a selected graphical session without coupling to telemetry.
- Do not enable graphical autologin by default.
- Preserve the text console and provide actionable logs on failure.
- Start with a simple test window or existing app rather than building the full Ginger shell immediately.

**Acceptance:** on a fresh QEMU install, start the graphical session from the console, open a test app, exit back to console, and repeat after reboot.

### D. UI client proof of concept

- Build one small visual telemetry view against the public service contract.
- Keep layout, theme, interaction design, assets, and framework choices replaceable.
- Do not treat the prototype as the final Ginger design system.

**Acceptance:** visual client displays live status and can be removed/replaced without changing telemetry service code.

### E. Local-first assistant integration

- Expose explicit, permission-checked actions through the same UI-neutral service boundary.
- Keep local model runtime optional and independently managed.
- Require confirmation for destructive or privileged actions; do not equate natural-language intent with shell authorization.

**Acceptance:** assistant is unavailable gracefully when stopped or no model is installed; core desktop and telemetry still work.

## QEMU validation gate

For each meaningful increment:

1. Build/package a fresh ISO using the documented repository workflow.
2. Install to a disposable fresh virtual disk.
3. Verify text-console login and recovery.
4. Verify networking and DNS using the existing regression checks.
5. Verify telemetry works with no graphical session.
6. Start and stop the graphical session; confirm services continue running and no orphaned session processes remain.
7. Reboot and repeat.
8. Record guest CPU/RAM usage, startup time, logs, and test results.

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
