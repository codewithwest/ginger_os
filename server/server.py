import os
import json
import asyncio
import queue
import threading
import logging
from typing import List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from llm.chatbot import chatbot

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
            except Exception:
                dead.append(connection)
        for d in dead:
            self.disconnect(d)


manager = ConnectionManager()


# Background task that drains the queue and broadcasts to all WS clients
async def _broadcast_worker():
    """Continuously drain the log queue and broadcast to connected WebSocket clients."""
    loop = asyncio.get_running_loop()
    while True:
        try:
            # Use run_in_executor to avoid blocking the event loop on the thread-safe queue
            msg = await loop.run_in_executor(None, _log_queue.get)
            await manager.broadcast(msg)
        except Exception as e:
            await asyncio.sleep(0.1)


@app.on_event("startup")
async def startup_event():
    global _broadcast_task
    _broadcast_task = asyncio.create_task(_broadcast_worker())


@app.get("/api/status")
async def get_status():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    try:
        return {
            "status": "ok",
            "running": engine.is_running,
            "aborted": engine.aborted,
            "current_pkg": engine.current_pkg or "",
            "executing_step": tui.state.executing_step if tui else None,
            "auto_all": tui.state.auto_all if tui else False,
            "steps": [
                {
                    "id": s.id,
                    "name": s.name,
                    "phase": s.phase,
                    "status": s.status
                    if not engine._should_skip(s) or s.status == "running"
                    else "completed",
                    "progress": s.progress,
                    "duration": round(s.duration(), 1),
                }
                for s in engine.steps
            ],
            "storage": engine.storage_stats,
            "cores": getattr(engine, "cores", 1),
            "max_cores": os.cpu_count() or 1,
            "timers": {
                "package": round(time.time() - engine.pkg_start_time, 1) if engine.pkg_start_time else 0,
                "phase": round(time.time() - engine.phase_start_time, 1) if engine.phase_start_time else 0,
                "overall": round(time.time() - engine.overall_start_time, 1) if engine.overall_start_time else 0,
            }
        }
    except Exception as e:
        import traceback
        logging.error(f"STATUS_ERROR: {str(e)}\n{traceback.format_exc()}")
        return {"status": "error", "message": str(e)}


@app.post("/api/step/{step_idx}/run")
async def run_step(step_idx: int):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if step_idx < 0 or step_idx >= len(engine.steps):
        return {"status": "error", "message": "Invalid step index"}
    tui.selected_step = step_idx
    tui.run_selected_step(force=False)
    return {"status": "ok", "step": engine.steps[step_idx].name}


@app.post("/api/step/{step_idx}/force")
async def force_step(step_idx: int):
    if not tui:
        return {"status": "error", "message": "TUI not initialized"}
    if step_idx < 0 or step_idx >= len(engine.steps):
        return {"status": "error", "message": "Invalid step index"}
    tui.selected_step = step_idx
    tui.run_selected_step(force=True)
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


@app.post("/api/control/cores/{count}")
async def set_cores(count: int):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    
    max_c = os.cpu_count() or 1
    if count < 1 or count > max_c:
        return {"status": "error", "message": f"Invalid core count. Range: 1-{max_c}"}
    
    engine.cores = count
    engine.log(f"SYSTEM_CONFIG :: CPU_CORES set to {count}", "bold cyan")
    return {"status": "ok", "cores": count}


@app.post("/api/control/rebuild_ui")
async def rebuild_ui():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    
    def run_build():
        engine.log("SYSTEM_MAINTENANCE :: Starting UI rebuild...", "bold cyan")
        try:
            res = subprocess.run(
                "npm run build", 
                shell=True, 
                cwd=os.path.join(_GINGER_ROOT, "ui", "web"),
                capture_output=True,
                text=True
            )
            if res.returncode == 0:
                engine.log("SYSTEM_MAINTENANCE :: UI rebuild complete.", "bold green")
            else:
                engine.log(f"SYSTEM_ERROR :: UI rebuild failed: {res.stderr}", "bold red")
        except Exception as e:
            engine.log(f"SYSTEM_ERROR :: UI rebuild exception: {str(e)}", "bold red")

    threading.Thread(target=run_build, daemon=True).start()
    return {"status": "ok", "message": "Rebuild sequence initiated"}


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


@app.post("/api/teardown")
async def full_teardown():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    import subprocess
    import threading

    def run_teardown():
        try:
            # Run the full teardown script
            script_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "lfs",
                "image",
                "full-teardown.sh",
            )
            result = subprocess.run(
                ["sudo", script_path],
                capture_output=True,
                text=True,
                cwd=os.path.dirname(os.path.dirname(__file__)),
            )
            if result.returncode == 0:
                engine.log("Full teardown completed successfully", "green")
            else:
                engine.log(f"Full teardown failed: {result.stderr}", "red")
        except Exception as e:
            engine.log(f"Full teardown error: {str(e)}", "red")

    threading.Thread(target=run_teardown, daemon=True).start()
    return {"status": "ok", "message": "Full teardown started"}


@app.websocket("/ws/logs")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        # Send existing logs on connect
        if engine:
            for log_entry, style in list(engine.logs):
                await websocket.send_text(
                    json.dumps({"msg": log_entry, "style": style or ""})
                )
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


@app.websocket("/ws/chat")
async def chat_websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            try:
                payload = json.loads(data)
                question = payload.get("question", "")
            except json.JSONDecodeError:
                continue

            if not question:
                continue

            await websocket.send_text(
                json.dumps(
                    {"status": "thinking", "msg": "Searching knowledge base..."})
            )

            # Run the blocking chatbot answer in a thread to avoid blocking the event loop
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(None, chatbot.answer, question)

            await websocket.send_text(
                json.dumps(
                    {
                        "status": "complete",
                        "answer": response["answer"],
                        "sources": response["sources"],
                    }
                )
            )
    except (WebSocketDisconnect, Exception):
        pass


@app.post("/api/snapshots/take")
async def take_snapshot(label: str = "manual"):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}

    threading.Thread(target=lambda: engine.take_snapshot(
        label), daemon=True).start()
    return {"status": "ok", "message": f"Snapshot '{label}' started"}


@app.post("/api/snapshots/restore/{snap_name}")
async def restore_snapshot(snap_name: str):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}

    threading.Thread(
        target=lambda: engine.restore_snapshot(snap_name), daemon=True
    ).start()
    return {"status": "ok", "message": f"Restore from '{snap_name}' started"}


# Server-side setup will be initialized in start_server()
_SERVER_DIR = os.path.dirname(os.path.abspath(__file__))
_GINGER_ROOT = os.path.dirname(_SERVER_DIR)
_UI_DIST = os.path.join(_GINGER_ROOT, "ui", "web", "dist")

loop = None


def broadcast_log(msg, style):
    """Called from engine thread — puts message into thread-safe queue."""
    _log_queue.put(json.dumps({"msg": msg, "style": style or ""}))


def start_server(engine_instance, tui_instance, host="127.0.0.1", port=8000):
    global engine, tui
    try:
        engine = engine_instance
        tui = tui_instance
        engine.on_log_callbacks.append(broadcast_log)

        # Mount static files AFTER all API routes are defined
        if os.path.exists(_UI_DIST):
            app.mount("/", StaticFiles(directory=_UI_DIST, html=True), name="static")
        else:
            @app.get("/", response_class=HTMLResponse)
            async def get_index():
                return "<h1>UI dist not found. Please run 'npm run build' in ui/web.</h1>"

        import uvicorn
        import socket

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex((host, port)) == 0:
                engine.log(
                    f"SYSTEM_WARNING: Port {port} already in use. Web UI disabled.",
                    "yellow",
                )
                return

        engine.log(
            f"NEURAL_LINK: Starting dashboard on http://{host}:{port}", "bold green"
        )

        # Create new event loop for this thread
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        try:
            config = uvicorn.Config(
                app, host=host, port=port, log_level="error")
            server = uvicorn.Server(config)
            engine.log(
                f"NEURAL_LINK: Dashboard active at http://{host}:{port}", "bold green"
            )
            
            # Periodically check if engine was aborted to stop the server
            async def check_abort():
                while not engine.aborted:
                    await asyncio.sleep(1)
                server.should_exit = True

            loop.create_task(check_abort())
            loop.run_until_complete(server.serve())
        except Exception as e:
            engine.log(
                f"SYSTEM_WARNING: Web UI server error: {str(e)}", "yellow")
        finally:
            loop.close()

    except Exception as e:
        engine.log(
            f"SYSTEM_WARNING: Web UI initialization failed: {str(e)}", "yellow")
