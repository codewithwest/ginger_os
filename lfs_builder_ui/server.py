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

@app.post("/api/control/{action}")
async def control_build(action: str):
    if not engine:
        return {"status": "error", "message": "Engine not initialized"}
    
    if action == "pause":
        engine.toggle_pause()
    elif action == "resume":
        engine.toggle_pause() # It's a toggle in engine
    elif action == "skip":
        engine.skip_current_step()
    elif action == "abort":
        engine.abort()
    
    return {"status": "ok", "action": action}

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
    <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; }
        .terminal { 
            background: #020617; 
            color: #d1d5db; 
            font-family: 'Fira Code', monospace;
            box-shadow: inset 0 0 20px rgba(0,0,0,0.5);
        }
        .line-green { color: #4ade80; }
        .line-yellow { color: #facc15; }
        .line-red { color: #f87171; }
        .line-cyan { color: #22d3ee; }
        
        .glow-text { text-shadow: 0 0 10px rgba(34, 211, 238, 0.5); }
        .ginger-blue { color: #00e5ff; }
        
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: #1e293b; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: #475569; }

        @keyframes pulse-soft {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        .animate-pulse-soft { animation: pulse-soft 2s cubic-bezier(0.4, 0, 0.6, 1) infinite; }
    </style>
</head>
<body class="bg-slate-950 text-slate-200 min-h-screen">
    <div class="container mx-auto p-4 lg:p-8">
        <header class="flex flex-col md:flex-row justify-between items-center mb-8 gap-4 border-b border-slate-800 pb-6">
            <div class="flex items-center gap-4">
                <div class="bg-cyan-500/20 p-2 rounded-xl border border-cyan-500/30">
                    <span class="text-3xl">🌶️</span>
                </div>
                <div>
                    <h1 class="text-3xl font-extrabold tracking-tight glow-text ginger-blue">GingerOS</h1>
                    <p class="text-xs text-slate-500 font-medium uppercase tracking-widest">Build Dashboard v1.1.0</p>
                </div>
            </div>
            <div class="flex items-center gap-3">
                <div id="build-status-badge" class="flex items-center gap-2 px-4 py-1.5 rounded-full bg-slate-900 border border-slate-700 text-sm">
                    <span id="status-dot" class="w-2 h-2 rounded-full bg-slate-500"></span>
                    <span id="build-status-text" class="font-bold text-xs uppercase tracking-tighter">Initializing</span>
                </div>
            </div>
        </header>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
            <!-- Left Column: Steps -->
            <div class="lg:col-span-4 space-y-6">
                <div class="bg-slate-900/50 rounded-2xl border border-slate-800 overflow-hidden shadow-2xl backdrop-blur-sm">
                    <div class="bg-slate-900 px-5 py-3 border-b border-slate-800 flex justify-between items-center">
                        <h2 class="text-sm font-bold uppercase tracking-wider text-slate-400">Build Pipeline</h2>
                        <span id="step-count" class="text-[10px] bg-slate-800 px-2 py-0.5 rounded text-slate-500 font-mono">0/0</span>
                    </div>
                    <div id="steps-list" class="p-4 space-y-3 max-h-[500px] overflow-y-auto">
                        <!-- Steps injected here -->
                    </div>
                </div>

                <!-- Stats Controls Center -->
                <div class="bg-slate-900/50 rounded-2xl border border-slate-800 p-6 shadow-2xl space-y-6 backdrop-blur-sm">
                    <div class="space-y-1">
                        <span class="text-[10px] uppercase font-bold text-slate-500 tracking-widest">Active Focus</span>
                        <div id="current-pkg" class="text-xl font-bold text-white truncate">Idle</div>
                    </div>
                    
                    <div class="grid grid-cols-2 gap-3">
                        <button onclick="control('pause')" id="btn-pause" class="flex flex-col items-center justify-center gap-1 p-3 rounded-xl bg-slate-800 border border-slate-700 hover:bg-slate-700 transition-all active:scale-95 group">
                            <span class="text-lg group-hover:scale-110 transition-transform">⏸</span>
                            <span class="text-[10px] font-bold uppercase tracking-tighter">Pause</span>
                        </button>
                        <button onclick="control('skip')" class="flex flex-col items-center justify-center gap-1 p-3 rounded-xl bg-slate-800 border border-slate-700 hover:bg-slate-700 transition-all active:scale-95 group">
                            <span class="text-lg group-hover:scale-110 transition-transform">⏭</span>
                            <span class="text-[10px] font-bold uppercase tracking-tighter">Skip</span>
                        </button>
                    </div>

                    <div id="storage-stats" class="grid grid-cols-2 gap-4 py-4 border-y border-slate-800/50">
                        <!-- Storage info here -->
                    </div>

                    <button onclick="control('abort')" class="w-full py-3 rounded-xl border border-red-900/30 text-red-500 hover:bg-red-500/10 transition-colors text-[10px] font-bold uppercase tracking-widest">
                        System Termination
                    </button>
                </div>
            </div>

            <!-- Right Column: Console -->
            <div class="lg:col-span-8">
                <div class="bg-slate-900 rounded-2xl border border-slate-800 overflow-hidden shadow-2xl flex flex-col h-full min-h-[700px]">
                    <div class="bg-slate-800/50 px-5 py-2.5 border-b border-slate-800 flex justify-between items-center">
                        <div class="flex items-center gap-2">
                            <div class="flex gap-1.5">
                                <div class="w-2.5 h-2.5 rounded-full bg-red-500/50"></div>
                                <div class="w-2.5 h-2.5 rounded-full bg-yellow-500/50"></div>
                                <div class="w-2.5 h-2.5 rounded-full bg-green-500/50"></div>
                            </div>
                            <span class="ml-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">ginger_output.log</span>
                        </div>
                        <div class="flex items-center gap-3">
                            <span id="log-count" class="text-[10px] font-mono text-slate-600">0 LNS</span>
                            <div class="w-px h-3 bg-slate-700"></div>
                            <span class="text-[10px] text-cyan-500/70 font-bold animate-pulse-soft">LIVE STREAMING</span>
                        </div>
                    </div>
                    <div id="terminal" class="terminal flex-grow p-6 text-[13px] leading-relaxed overflow-y-auto">
                        <!-- Logs injected here -->
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const terminal = document.getElementById('terminal');
        const stepsList = document.getElementById('steps-list');
        const statusBadge = document.getElementById('build-status-badge');
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('build-status-text');
        const currentPkg = document.getElementById('current-pkg');
        const storageStats = document.getElementById('storage-stats');
        const stepCount = document.getElementById('step-count');
        
        let lineCount = 0;

        // WebSocket for live logs
        const ws = new WebSocket(`ws://${location.host}/ws/logs`);
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            const line = document.createElement('div');
            line.className = 'mb-0.5 whitespace-pre-wrap';
            
            if (data.style) {
                if (data.style.includes('red')) line.classList.add('line-red');
                else if (data.style.includes('yellow')) line.classList.add('line-yellow');
                else if (data.style.includes('green')) line.classList.add('line-green');
                else if (data.style.includes('cyan')) line.classList.add('line-cyan');
            }
            
            line.textContent = data.msg;
            terminal.appendChild(line);
            
            lineCount++;
            document.getElementById('log-count').textContent = `${lineCount} LNS`;
            
            // Auto-scroll
            terminal.scrollTop = terminal.scrollHeight;
            
            // Limit DOM size
            if (terminal.children.length > 1000) {
                terminal.removeChild(terminal.firstChild);
            }
        };

        async function control(action) {
            try {
                await fetch(`/api/control/${action}`, { method: 'POST' });
                updateStatus();
            } catch (e) { console.error(e); }
        }

        async function updateStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                
                // Update Badge
                if (data.running) {
                    statusDot.className = 'w-2 h-2 rounded-full bg-cyan-400 shadow-[0_0_8px_rgba(34,211,238,0.8)]';
                    statusText.textContent = 'RUNNING';
                    statusText.className = 'font-bold text-xs uppercase tracking-tighter text-cyan-400 animate-pulse';
                } else if (data.aborted) {
                    statusDot.className = 'w-2 h-2 rounded-full bg-red-500';
                    statusText.textContent = 'ABORTED';
                    statusText.className = 'font-bold text-xs uppercase tracking-tighter text-red-500';
                } else {
                    statusDot.className = 'w-2 h-2 rounded-full bg-slate-500';
                    statusText.textContent = 'IDLE';
                    statusText.className = 'font-bold text-xs uppercase tracking-tighter text-slate-500';
                }
                
                currentPkg.textContent = data.current_pkg || 'Standby';

                // Update Steps
                stepCount.textContent = `${data.steps.filter(s => s.status === 'completed').length}/${data.steps.length}`;
                stepsList.innerHTML = data.steps.map(s => `
                    <div class="group relative bg-slate-900 border border-slate-800/50 p-3 rounded-xl transition-all ${s.status === 'running' ? 'border-cyan-500/30 bg-slate-800/50 ring-1 ring-cyan-500/20' : ''}">
                        <div class="flex items-center justify-between mb-2">
                            <span class="text-xs font-semibold truncate pr-2 ${s.status === 'completed' ? 'text-green-500' : (s.status === 'failed' ? 'text-red-500' : 'text-slate-300')}">
                                ${s.status === 'completed' ? '✓' : (s.status === 'failed' ? '✗' : '·')} ${s.name}
                            </span>
                            <span class="text-[10px] font-mono text-slate-500">${s.progress}%</span>
                        </div>
                        <div class="w-full bg-slate-950 h-1.5 rounded-full overflow-hidden border border-slate-800/50">
                            <div class="h-full rounded-full transition-all duration-500 ${s.status === 'completed' ? 'bg-green-500' : (s.status === 'failed' ? 'bg-red-500' : 'bg-cyan-500')}" style="width: ${s.progress}%"></div>
                        </div>
                    </div>
                `).join('');

                // Storage
                storageStats.innerHTML = Object.entries(data.storage).map(([k, v]) => `
                    <div class="flex flex-col gap-0.5">
                        <span class="text-[9px] uppercase font-bold text-slate-600 tracking-wider">${k}</span>
                        <span class="font-mono text-xs text-slate-400">${(v/1024).toFixed(1)} GB</span>
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
