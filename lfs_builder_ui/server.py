import os
import json
import asyncio
import queue
import threading
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from typing import List
import logging

logging.getLogger("uvicorn.error").setLevel(logging.ERROR)

app = FastAPI()

engine = None
tui = None

# Thread-safe queue for log messages from engine thread → async broadcast
_log_queue: queue.Queue = queue.Queue()
_broadcast_task = None

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        dead = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                dead.append(connection)
        for d in dead:
            self.disconnect(d)

manager = ConnectionManager()

# Background task that drains the queue and broadcasts to all WS clients
async def _broadcast_worker():
    """Continuously drain the log queue and broadcast to connected WebSocket clients."""
    while True:
        try:
            msg = _log_queue.get_nowait()
            await manager.broadcast(msg)
        except queue.Empty:
            await asyncio.sleep(0.02)
        except Exception as e:
            await asyncio.sleep(0.05)

@app.on_event("startup")
async def startup_event():
    global _broadcast_task
    _broadcast_task = asyncio.create_task(_broadcast_worker())

@app.get("/api/status")
async def get_status():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    return {
        "running": engine.is_running,
        "aborted": engine.aborted,
        "current_pkg": engine.current_pkg or "",
        "executing_step": tui.executing_step if tui else None,
        "auto_all": tui.auto_all if tui else False,
        "steps": [
            {
                "id": s.id,
                "name": s.name,
                "phase": s.phase,
                "status": s.status if not engine._should_skip(s) or s.status == "running"
                          else "completed",
                "progress": s.progress,
                "duration": round(s.duration(), 1)
            } for s in engine.steps
        ],
        "storage": engine.storage_stats
    }

@app.post("/api/step/{step_idx}/run")
async def run_step(step_idx: int):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if step_idx < 0 or step_idx >= len(engine.steps):
        return {"status": "error", "message": "Invalid step index"}
    tui.selected_step = step_idx
    tui.run_step(step_idx, force=False)
    return {"status": "ok", "step": engine.steps[step_idx].name}

@app.post("/api/step/{step_idx}/force")
async def force_step(step_idx: int):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if step_idx < 0 or step_idx >= len(engine.steps):
        return {"status": "error", "message": "Invalid step index"}
    tui.run_step(step_idx, force=True)
    return {"status": "ok", "step": engine.steps[step_idx].name}

@app.post("/api/step/{step_idx}/reset")
async def reset_step(step_idx: int):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if step_idx < 0 or step_idx >= len(engine.steps):
        return {"status": "error", "message": "Invalid step index"}
    tui.delete_marker(step_idx)
    engine.steps[step_idx].status = "pending"
    return {"status": "ok", "step": engine.steps[step_idx].name}

@app.post("/api/control/{action}")
async def control_build(action: str):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if action == "auto":
        tui.run_all_pending()
    elif action == "abort":
        engine.abort()
        tui.auto_all = False
        tui.executing_step = None
    elif action == "resume":
        engine.resume_package()
    return {"status": "ok", "action": action}

@app.websocket("/ws/logs")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        # Send existing logs on connect
        if engine:
            for log_entry, style in list(engine.logs):
                await websocket.send_text(json.dumps({"msg": log_entry, "style": style or ""}))
        # Keep connection alive, ping every 5s
        while True:
            await asyncio.sleep(5)
            await websocket.send_text(json.dumps({"ping": True}))
    except (WebSocketDisconnect, Exception):
        manager.disconnect(websocket)

@app.get("/api/snapshots")
async def list_snapshots():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    return {"snapshots": engine.list_snapshots()}

@app.post("/api/snapshots/take")
async def take_snapshot(label: str = "manual"):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    import threading
    threading.Thread(target=lambda: engine.take_snapshot(label), daemon=True).start()
    return {"status": "ok", "message": f"Snapshot '{label}' started"}

@app.post("/api/snapshots/restore/{snap_name}")
async def restore_snapshot(snap_name: str):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    import threading
    threading.Thread(target=lambda: engine.restore_snapshot(snap_name), daemon=True).start()
    return {"status": "ok", "message": f"Restore from '{snap_name}' started"}

# Get the directory where this server.py file is located
_UI_DIR = os.path.dirname(os.path.abspath(__file__))
_INDEX_PATH = os.path.join(_UI_DIR, "index.html")

@app.get("/", response_class=HTMLResponse)
async def get_index():
    if os.path.exists(_INDEX_PATH):
        with open(_INDEX_PATH, "r") as f:
            return f.read()
    return "<h1>UI not found</h1>"

loop = None

def broadcast_log(msg, style):
    """Called from engine thread — puts message into thread-safe queue."""
    _log_queue.put(json.dumps({"msg": msg, "style": style or ""}))

def start_server(engine_instance, tui_instance, host="127.0.0.1", port=8000):
    global engine, tui
    engine = engine_instance
    tui = tui_instance
    engine.on_log_callbacks.append(broadcast_log)

    import uvicorn
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex((host, port)) == 0:
            engine.log(f"SYSTEM_WARNING: Port {port} already in use. Web UI disabled.", "yellow")
            return

    try:
        config = uvicorn.Config(app, host=host, port=port, log_level="error")
        server = uvicorn.Server(config)
        engine.log(f"NEURAL_LINK: Dashboard active at http://{host}:{port}", "bold green")
        asyncio.run(server.serve())
    except Exception as e:
        engine.log(f"SYSTEM_WARNING: Web UI failed to start: {str(e)}", "yellow")
