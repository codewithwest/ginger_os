import os
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from typing import List

app = FastAPI()

# Global reference to the GingerEngine instance
engine = None

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()

@app.get("/api/status")
async def get_status():
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    return {
        "running": engine.executing_step is not None,
        "aborted": engine.aborted,
        "current_pkg": getattr(engine, "current_pkg", "None"),
        "steps": [
            {
                "id": s.id,
                "name": s.name,
                "status": s.status,
                "progress": s.progress
            } for s in engine.steps
        ],
        "storage": engine.storage_stats
    }

@app.websocket("/ws/logs")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        # Send existing logs first
        if engine:
            for log_entry, style in engine.logs:
                await websocket.send_text(json.dumps({"msg": log_entry, "style": style}))
        
        while True:
            await websocket.receive_text() # Keep-alive
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# HTML Dashboard template
INDEX_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>GingerOS Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .terminal { background: #0c0c0c; color: #00ff00; font-family: 'Courier New', monospace; }
        .ginger-blue { color: #00e5ff; }
    </style>
</head>
<body class="bg-slate-900 text-white font-sans">
    <div class="container mx-auto p-4">
        <header class="flex justify-between items-center mb-8 border-b border-slate-700 pb-4">
            <h1 class="text-3xl font-bold ginger-blue">🌶️ GingerOS <span class="text-slate-500 text-sm">v1.1.0 Remote</span></h1>
            <div id="build-status" class="px-3 py-1 rounded-full bg-slate-800 text-sm text-yellow-400">Idle</div>
        </header>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Steps List -->
            <div class="lg:col-span-1 bg-slate-800 rounded-lg p-4 shadow-xl">
                <h2 class="text-xl font-semibold mb-4 border-b border-slate-700 pb-2">Steps</h2>
                <div id="steps-list" class="space-y-2 max-h-[600px] overflow-y-auto pr-2">
                    <!-- Steps injected here -->
                </div>
            </div>

            <!-- Terminal / Logs -->
            <div class="lg:col-span-2 flex flex-col gap-6">
                <div class="bg-black rounded-lg shadow-2xl overflow-hidden flex-grow flex flex-col min-h-[500px]">
                    <div class="bg-slate-700 px-4 py-1 text-xs text-slate-300 flex justify-between">
                        <span>LIVE_BUILD_CONSOLE</span>
                        <span id="log-count">0 lines</span>
                    </div>
                    <div id="terminal" class="terminal flex-grow p-4 text-sm overflow-y-auto h-[480px]">
                        <!-- Logs injected here -->
                    </div>
                </div>

                <!-- Stats -->
                <div class="grid grid-cols-2 gap-4">
                    <div class="bg-slate-800 p-4 rounded-lg flex flex-col items-center">
                        <span class="text-slate-400 text-xs uppercase">Current Package</span>
                        <span id="current-pkg" class="text-xl font-bold text-cyan-400 truncate w-full text-center">None</span>
                    </div>
                    <div id="storage-stats" class="bg-slate-800 p-4 rounded-lg grid grid-cols-2 gap-2 text-xs">
                        <!-- Storage info here -->
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const terminal = document.getElementById('terminal');
        const stepsList = document.getElementById('steps-list');
        const buildStatus = document.getElementById('build-status');
        const currentPkg = document.getElementById('current-pkg');
        const storageStats = document.getElementById('storage-stats');

        // WebSocket for live logs
        const ws = new WebSocket(`ws://${location.host}/ws/logs`);
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            const line = document.createElement('div');
            if (data.style) {
                if (data.style.includes('red')) line.className = 'text-red-500';
                else if (data.style.includes('yellow')) line.className = 'text-yellow-400';
                else if (data.style.includes('green')) line.className = 'text-green-400';
                else if (data.style.includes('cyan')) line.className = 'text-cyan-400';
            }
            line.textContent = data.msg;
            terminal.appendChild(line);
            terminal.scrollTop = terminal.scrollHeight;
        };

        // Status Polling
        async function updateStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                
                // Update Status Badge
                buildStatus.textContent = data.running ? 'RUNNING' : (data.aborted ? 'ABORTED' : 'IDLE');
                buildStatus.className = `px-3 py-1 rounded-full text-sm ${data.running ? 'bg-cyan-900 text-cyan-300 animate-pulse' : 'bg-slate-800 text-slate-400'}`;
                
                currentPkg.textContent = data.current_pkg || 'None';

                // Update Steps
                stepsList.innerHTML = data.steps.map(s => `
                    <div class="flex items-center justify-between p-2 rounded ${s.status === 'running' ? 'bg-slate-700' : 'bg-slate-800'}">
                        <span class="truncate pr-2 ${s.status === 'completed' ? 'text-green-500' : (s.status === 'failed' ? 'text-red-500' : 'text-slate-200')}">
                            ${s.status === 'completed' ? '✓' : (s.status === 'failed' ? '✗' : '·')} ${s.name}
                        </span>
                        <span class="text-[10px] text-slate-500">${s.progress}%</span>
                    </div>
                `).join('');

                // Storage
                storageStats.innerHTML = Object.entries(data.storage).map(([k, v]) => `
                    <div class="flex flex-col">
                        <span class="text-slate-500">${k}</span>
                        <span class="font-mono text-slate-300">${(v/1024).toFixed(1)}GB</span>
                    </div>
                `).join('');

            } catch (e) { console.error(e); }
        }

        setInterval(updateStatus, 1000);
        updateStatus();
    </script>
</body>
</html>
"""

@app.get("/", response_class=HTMLResponse)
async def get_index():
    return INDEX_HTML

loop = None

def broadcast_log(msg, style):
    if loop and manager.active_connections:
        asyncio.run_coroutine_threadsafe(
            manager.broadcast(json.dumps({"msg": msg, "style": style})), 
            loop
        )

def start_server(engine_instance, host="0.0.0.0", port=8000):
    global engine, loop
    engine = engine_instance
    engine.on_log_callbacks.append(broadcast_log)
    
    import uvicorn
    config = uvicorn.Config(app, host=host, port=port, log_level="error")
    server = uvicorn.Server(config)
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(server.serve())
