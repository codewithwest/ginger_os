# GingerOS Web UI Architecture

To enable remote monitoring and control of the build process, a lightweight Web UI will be implemented as an optional layer over the current `GingerEngine`.

## Technical Stack

- **Backend**: FastAPI (Python)
- **Real-time Communication**: WebSockets (specifically for live logs and status updates)
- **Frontend**: Vanilla HTML/JS with Tailwind CSS (CDN-based for zero-install portability)
- **Concurrency**: `uvicorn` as the ASGI server, running in a separate thread from the Engine.

## core Components

### [FastAPI Server]
A new module `lfs_builder_ui/server.py` will host the API.

#### API Endpoints
- `GET /api/status`: Returns current build status, progress, and storage stats.
- `GET /api/steps`: Returns the list of all build steps with their status.
- `POST /api/build/toggle`: Resume or pause the build.
- `POST /api/build/abort`: Abort the current build.
- `WS /ws/logs`: Streaming log output (broadcast from the Engine's `log` method).

### [Engine Integration]
The `GingerEngine` will be updated to support an optional callback or event-based notification system to push updates to the Web Server without tightly coupling the two.

## User Interface Design

The UI will replicate the TUI's terminal-inspired aesthetic but with enhanced data visualization:
- **Progress Bars**: Smooth, animated bars for current phase and overall build.
- **Log Viewer**: A high-performance terminal emulator component (e.g., `xterm.js`) for the build output.
- **Remote Controls**: Floating action buttons for Build/Pause/Abort.

## Security Considerations

Since GingerOS builds often run with `sudo` or as restricted users, the Web UI should:
- Bind to `localhost` by default.
- Support basic token-based authentication if exposed to a network.
- Use read-only mode by default for monitoring-only users.
