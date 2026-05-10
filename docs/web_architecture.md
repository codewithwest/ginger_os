# GingerOS Neural Command Matrix Architecture

The **Neural Command Matrix** is the high-fidelity web-based orchestration layer for GingerOS. It provides real-time monitoring, resource management, and remote control over the LFS build pipeline.

## Technical Stack

- **Backend**: FastAPI (Python 3)
- **Real-time Communication**: 
  - **WebSockets**: Asynchronous log streaming via a thread-safe broadcast worker.
  - **REST API**: Polling-based telemetry for system state and storage.
- **Frontend**: React 19 + Vite + Tailwind CSS v4
- **Styling**: High-Tech Glassmorphism Design System
- **Monitoring**: `psutil` for real-time host telemetry.
- **Concurrency**: `uvicorn` ASGI server running in a dedicated background thread.

## Core API & Integration

### Engine-Server Bridge
The `GingerEngine` communicates with the FastAPI server through a thread-safe `queue`.
- Logs are intercepted via `on_log_callbacks` and pushed to the `_log_queue`.
- A dedicated `_broadcast_worker` drains this queue and pushes messages to all connected WebSocket clients.

### API Endpoints
- `GET /api/status`: Granular telemetry (CPU, Storage, Steps, Timers).
- `POST /api/control/auto`: Toggles the "Auto Protocol" for the build.
- `POST /api/control/abort`: Triggers a **Process Group Termination** (`SIGTERM` to the PGID).
- `POST /api/control/cores/{count}`: Dynamically updates CPU core allocation for build steps.
- `POST /api/control/rebuild_ui`: Remotely triggers `npm run build` to update the dashboard.
- `WS /ws/logs`: Live log stream ("Neural Stream").

## Process Management & Safety

To prevent orphaned processes during build abortions or TUI exits, GingerOS employs a **Process Group Isolation** strategy:
1. Every build step is executed as the leader of a new process group.
2. `engine.abort()` sends signals to the entire PGID, cleaning up sub-processes like `tail`, `wget`, or `make` children.
3. The TUI's `on_unmount` hook ensures a mandatory cleanup sequence on application exit.

## Design System

The UI implements a "Glassmorphism" aesthetic defined in `ui/web/src/index.css`:
- **Backdrop Blur**: `backdrop-blur-xl` for all primary panels.
- **Dynamic Gradients**: Progressive color shifts for status indicators and telemetry bars.
- **Typography**: Inter (Sans) for UI/Controls; JetBrains Mono for system data.
- **Atmospheric Effects**: Scanline overlays and glow-cyan accents for a "Command Center" feel.

## Security

- **Host Binding**: Server binds to `127.0.0.1` by default.
- **Isolation**: Build scripts run in a restricted `chroot` or as the `lfs` user, while the UI only triggers predefined orchestrator actions.
