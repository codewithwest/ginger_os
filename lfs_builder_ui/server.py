import os
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from typing import List

app = FastAPI()

engine = None
tui = None  # Reference to GingerTUI for step control

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
        if engine:
            for log_entry, style in engine.logs:
                await websocket.send_text(json.dumps({"msg": log_entry, "style": style or ""}))
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

INDEX_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>GingerOS Build Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background: #020617; }
        .terminal { font-family: 'Fira Code', monospace; }
        .line-red    { color: #f87171; }
        .line-yellow { color: #facc15; }
        .line-green  { color: #4ade80; }
        .line-cyan   { color: #22d3ee; }
        .line-white  { color: #e2e8f0; }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-track { background: #0f172a; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 2px; }
        .step-row { cursor: pointer; transition: background 0.15s; }
        .step-row:hover { background: #1e293b; }
        .step-running { background: #0c1a2e; border-left: 2px solid #22d3ee; }
        .step-completed { border-left: 2px solid #4ade80; }
        .step-failed { border-left: 2px solid #f87171; }
        .step-pending { border-left: 2px solid #334155; }
        @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.4} }
        .pulsing { animation: pulse 1.5s infinite; }
    </style>
</head>
<body class="text-slate-200 min-h-screen">
<div class="flex h-screen overflow-hidden">

    <!-- Left Panel: Steps -->
    <div class="w-80 flex-shrink-0 border-r border-slate-800 flex flex-col">
        <div class="p-4 border-b border-slate-800 flex items-center justify-between">
            <div class="flex items-center gap-2">
                <span class="text-xl">🌶️</span>
                <span class="font-bold text-cyan-400 tracking-tight">GingerOS</span>
            </div>
            <div id="status-badge" class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-full bg-slate-800">
                <span id="status-dot" class="w-1.5 h-1.5 rounded-full bg-slate-500"></span>
                <span id="status-text">IDLE</span>
            </div>
        </div>

        <!-- Controls -->
        <div class="p-3 border-b border-slate-800 flex gap-2">
            <button onclick="controlBuild('auto')" id="btn-auto"
                class="flex-1 py-2 rounded-lg bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-[11px] font-bold uppercase tracking-wider hover:bg-cyan-500/20 transition-all">
                ▶ Auto Run
            </button>
            <button onclick="controlBuild('abort')"
                class="flex-1 py-2 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-[11px] font-bold uppercase tracking-wider hover:bg-red-500/20 transition-all">
                ■ Abort
            </button>
        </div>

        <!-- Step List -->
        <div id="steps-list" class="flex-1 overflow-y-auto py-1">
        </div>

        <!-- Storage -->
        <div class="p-3 border-t border-slate-800">
            <div class="text-[9px] uppercase font-bold text-slate-600 tracking-wider mb-2">Storage</div>
            <div id="storage" class="grid grid-cols-2 gap-2"></div>
        </div>
    </div>

    <!-- Right Panel: Terminal + Info -->
    <div class="flex-1 flex flex-col overflow-hidden">

        <!-- Top bar: current step info -->
        <div class="px-5 py-3 border-b border-slate-800 flex items-center justify-between bg-slate-900/50">
            <div>
                <div class="text-[10px] uppercase text-slate-500 font-bold tracking-wider">Active Package</div>
                <div id="current-pkg" class="text-sm font-bold text-white mt-0.5">—</div>
            </div>
            <div id="step-counter" class="text-[11px] font-mono text-slate-500">0 / 0</div>
        </div>

        <!-- Terminal -->
        <div class="flex-1 overflow-hidden flex flex-col">
            <div class="px-4 py-2 border-b border-slate-800 flex items-center justify-between bg-slate-900/30">
                <div class="flex items-center gap-2">
                    <div class="flex gap-1">
                        <div class="w-2 h-2 rounded-full bg-red-500/40"></div>
                        <div class="w-2 h-2 rounded-full bg-yellow-500/40"></div>
                        <div class="w-2 h-2 rounded-full bg-green-500/40"></div>
                    </div>
                    <span class="text-[10px] font-bold uppercase tracking-widest text-slate-500 ml-2">Live Output</span>
                </div>
                <div class="flex items-center gap-3">
                    <span id="log-count" class="text-[10px] font-mono text-slate-600">0 lines</span>
                    <span id="ws-status" class="text-[10px] font-bold text-slate-600">CONNECTING</span>
                    <button onclick="clearTerminal()" class="text-[10px] text-slate-600 hover:text-slate-400 uppercase tracking-wider">Clear</button>
                </div>
            </div>
            <div id="terminal" class="terminal flex-1 overflow-y-auto p-4 text-[12px] leading-5 bg-slate-950"></div>
        </div>
    </div>
</div>

<script>
    const terminal = document.getElementById('terminal');
    let lineCount = 0;
    let autoScroll = true;
    let lastStepsJson = '';

    // WebSocket
    const ws = new WebSocket(`ws://${location.host}/ws/logs`);
    ws.onopen = () => {
        document.getElementById('ws-status').textContent = 'LIVE';
        document.getElementById('ws-status').className = 'text-[10px] font-bold text-cyan-500 pulsing';
    };
    ws.onclose = () => {
        document.getElementById('ws-status').textContent = 'DISCONNECTED';
        document.getElementById('ws-status').className = 'text-[10px] font-bold text-red-500';
    };
    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        appendLog(data.msg, data.style);
    };

    function appendLog(msg, style) {
        const line = document.createElement('div');
        line.className = 'leading-5 whitespace-pre-wrap';
        if (style) {
            if (style.includes('red'))    line.classList.add('line-red');
            else if (style.includes('yellow')) line.classList.add('line-yellow');
            else if (style.includes('green'))  line.classList.add('line-green');
            else if (style.includes('cyan'))   line.classList.add('line-cyan');
            else line.classList.add('line-white');
        } else {
            line.classList.add('line-white');
        }
        line.textContent = msg;
        terminal.appendChild(line);
        lineCount++;
        document.getElementById('log-count').textContent = `${lineCount} lines`;
        if (autoScroll) terminal.scrollTop = terminal.scrollHeight;
        if (terminal.children.length > 2000) terminal.removeChild(terminal.firstChild);
    }

    terminal.addEventListener('scroll', () => {
        autoScroll = terminal.scrollTop + terminal.clientHeight >= terminal.scrollHeight - 20;
    });

    function clearTerminal() {
        terminal.innerHTML = '';
        lineCount = 0;
        document.getElementById('log-count').textContent = '0 lines';
    }

    async function controlBuild(action) {
        await fetch(`/api/control/${action}`, { method: 'POST' });
    }

    async function runStep(idx, force=false) {
        const endpoint = force ? `/api/step/${idx}/force` : `/api/step/${idx}/run`;
        const res = await fetch(endpoint, { method: 'POST' });
        const data = await res.json();
        if (data.status === 'ok') appendLog(`→ Triggered: ${data.step}`, 'cyan');
    }

    async function resetStep(idx) {
        await fetch(`/api/step/${idx}/reset`, { method: 'POST' });
        appendLog(`→ Marker deleted for step ${idx + 1}`, 'yellow');
    }

    function renderSteps(steps, executingStep, autoAll) {
        const json = JSON.stringify(steps.map(s => s.status));
        if (json === lastStepsJson) return;
        lastStepsJson = json;

        const container = document.getElementById('steps-list');
        const completed = steps.filter(s => s.status === 'completed').length;
        document.getElementById('step-counter').textContent = `${completed} / ${steps.length}`;

        container.innerHTML = steps.map((s, i) => {
            const isRunning = s.status === 'running';
            const rowClass = isRunning ? 'step-running' : `step-${s.status}`;
            const icon = s.status === 'completed' ? '✓'
                       : s.status === 'failed'    ? '✗'
                       : s.status === 'running'   ? '▶'
                       : '·';
            const iconColor = s.status === 'completed' ? 'text-green-500'
                            : s.status === 'failed'    ? 'text-red-500'
                            : s.status === 'running'   ? 'text-cyan-400 pulsing'
                            : 'text-slate-600';
            return `
            <div class="step-row ${rowClass} px-3 py-2.5 mx-1 my-0.5 rounded-lg" data-idx="${i}">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2 min-w-0">
                        <span class="text-xs font-bold ${iconColor} w-3 flex-shrink-0">${icon}</span>
                        <span class="text-[11px] font-medium truncate ${isRunning ? 'text-cyan-300' : 'text-slate-300'}">${s.name}</span>
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0 ml-2">
                        ${s.duration > 0 ? `<span class="text-[9px] font-mono text-slate-600">${formatDuration(s.duration)}</span>` : ''}
                        <button onclick="event.stopPropagation(); runStep(${i})"
                            class="text-[9px] px-1.5 py-0.5 rounded bg-slate-800 hover:bg-cyan-500/20 hover:text-cyan-400 text-slate-500 transition-all"
                            title="Run">▶</button>
                        <button onclick="event.stopPropagation(); runStep(${i}, true)"
                            class="text-[9px] px-1.5 py-0.5 rounded bg-slate-800 hover:bg-yellow-500/20 hover:text-yellow-400 text-slate-500 transition-all"
                            title="Force">↺</button>
                        <button onclick="event.stopPropagation(); resetStep(${i})"
                            class="text-[9px] px-1.5 py-0.5 rounded bg-slate-800 hover:bg-red-500/20 hover:text-red-400 text-slate-500 transition-all"
                            title="Reset marker">✕</button>
                    </div>
                </div>
                ${isRunning ? `
                <div class="mt-1.5 w-full bg-slate-900 h-0.5 rounded-full overflow-hidden">
                    <div class="h-full bg-cyan-500 pulsing" style="width: ${s.progress}%"></div>
                </div>` : ''}
            </div>`;
        }).join('');
    }

    function formatDuration(secs) {
        if (secs < 60) return `${secs.toFixed(0)}s`;
        return `${Math.floor(secs/60)}m${(secs%60).toFixed(0)}s`;
    }

    async function updateStatus() {
        try {
            const res = await fetch('/api/status');
            const data = await res.json();
            if (data.status === 'error') return;

            // Status badge
            const dot = document.getElementById('status-dot');
            const text = document.getElementById('status-text');
            const btnAuto = document.getElementById('btn-auto');
            if (data.running) {
                dot.className = 'w-1.5 h-1.5 rounded-full bg-cyan-400 pulsing';
                text.textContent = 'RUNNING';
                text.className = 'text-cyan-400';
            } else if (data.aborted) {
                dot.className = 'w-1.5 h-1.5 rounded-full bg-red-500';
                text.textContent = 'ABORTED';
                text.className = 'text-red-400';
            } else {
                dot.className = 'w-1.5 h-1.5 rounded-full bg-slate-500';
                text.textContent = 'IDLE';
                text.className = 'text-slate-400';
            }

            btnAuto.textContent = data.auto_all ? '⏸ Stop Auto' : '▶ Auto Run';
            btnAuto.className = data.auto_all
                ? 'flex-1 py-2 rounded-lg bg-yellow-500/10 border border-yellow-500/30 text-yellow-400 text-[11px] font-bold uppercase tracking-wider hover:bg-yellow-500/20 transition-all'
                : 'flex-1 py-2 rounded-lg bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-[11px] font-bold uppercase tracking-wider hover:bg-cyan-500/20 transition-all';

            document.getElementById('current-pkg').textContent = data.current_pkg || '—';

            renderSteps(data.steps, data.executing_step, data.auto_all);

            // Storage
            document.getElementById('storage').innerHTML = Object.entries(data.storage).map(([k, v]) => `
                <div>
                    <div class="text-[9px] uppercase text-slate-600 font-bold">${k}</div>
                    <div class="text-xs font-mono ${v > 90 ? 'text-red-400' : v > 75 ? 'text-yellow-400' : 'text-slate-400'}">${parseFloat(v).toFixed(1)}%</div>
                    <div class="mt-1 w-full bg-slate-800 h-0.5 rounded-full">
                        <div class="h-full rounded-full ${v > 90 ? 'bg-red-500' : v > 75 ? 'bg-yellow-500' : 'bg-cyan-500'}" style="width:${Math.min(v,100)}%"></div>
                    </div>
                </div>`).join('');
        } catch(e) {}
    }

    setInterval(updateStatus, 1000);
    updateStatus();
</script>
</body>
</html>"""

@app.get("/", response_class=HTMLResponse)
async def get_index():
    return INDEX_HTML

loop = None

def broadcast_log(msg, style):
    if loop and manager.active_connections:
        asyncio.run_coroutine_threadsafe(
            manager.broadcast(json.dumps({"msg": msg, "style": style or ""})),
            loop
        )

def start_server(engine_instance, tui_instance, host="127.0.0.1", port=8000):
    global engine, tui, loop
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
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        engine.log(f"NEURAL_LINK: Dashboard active at http://{host}:{port}", "bold green")
        loop.run_until_complete(server.serve())
    except Exception as e:
        engine.log(f"SYSTEM_WARNING: Web UI failed to start: {str(e)}", "yellow")
