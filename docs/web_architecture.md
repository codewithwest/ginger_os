# GingerOS — Web Dashboard Architecture

The **Neural Command Matrix** web dashboard provides real-time monitoring,
resource management, and remote control over the GingerOS build pipeline.

## Technical stack

- **Backend**: FastAPI (Python 3) — `server/server.py`, launched by
  `server/main.py` on port `8087`.
- **Real-time communication**:
  - **WebSockets**: asynchronous log streaming (`/ws/logs`).
  - **REST API**: step control, telemetry, config, snapshots.
- **Frontend**: React + Vite + Tailwind CSS (in `ui/web`, built to
  `ui/web/dist` and served statically by the backend).
- **Monitoring**: `psutil` for real-time host telemetry.
- **Concurrency**: `uvicorn` ASGI server in a dedicated background thread.

## Engine–server bridge

The `GingerEngine` (`server/engine.py`) pushes log events to a thread-safe
queue via `on_log_callbacks`; a broadcast worker drains the queue and streams
messages to all connected WebSocket clients.

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/status` | Granular telemetry (CPU, storage, steps, timers) |
| GET | `/api/step/{idx}/packages` | Package list + built status for a step |
| POST | `/api/step/{idx}/run` | Run a step (`?pkg=` for single package) |
| POST | `/api/step/{idx}/force` | Force-run a step |
| POST | `/api/step/{idx}/reset` | Clear a step marker |
| POST | `/api/control/cores/{count}` | Update CPU cores for `make -jN` |
| GET | `/api/config` | Read `ginger.conf` |
| POST | `/api/config/update` | Update configuration |
| POST | `/api/control/rebuild_ui` | Rebuild the dashboard (`npm run build`) |
| POST | `/api/control/{action}` | auto / abort / pause / resume |
| POST | `/api/teardown` | Full teardown (logs archive + unmount) |
| GET | `/api/snapshots` | List snapshots |
| POST | `/api/snapshots/take` | Take a snapshot |
| POST | `/api/snapshots/restore/{name}` | Restore a snapshot |
| WS | `/ws/logs` | Live "Neural Stream" log feed |
| GET | `/` | Static dashboard (`ui/web/dist`) |

## Process management & safety

Every build step runs as the leader of a new process group. `engine.abort()`
signals the entire PGID (`SIGTERM`), cleaning up `make`/`wget`/`tar`
subprocesses. The server binds to `127.0.0.1` by default.

## Design system

The dashboard uses a "glassmorphism" aesthetic defined in
`ui/web/src/index.css`:

- **Backdrop blur** (`backdrop-blur-xl`) on primary panels.
- **Dynamic gradients** for status indicators and telemetry bars.
- **Typography**: Inter for UI controls, JetBrains Mono for system data.
- **Atmospheric effects**: scanline overlays and cyan glow accents.

## Terminal HUD

The Go HUD (`ui/gotui`) is the companion terminal client, compiled by
`./run.sh` (`go build -o ginger-hud`). See
[docs/USAGE.md](USAGE.md) for its keybindings.
