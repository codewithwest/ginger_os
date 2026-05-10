import { useState, useEffect, useRef } from 'react';

interface Step {
  id: string;
  name: string;
  phase: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress: number;
  duration: number;
}

interface Status {
  status: string;
  running: boolean;
  current_pkg: string;
  executing_step: number | null;
  steps: Step[];
  cores: number;
  max_cores: number;
  storage: {
    lfs: number;
    host: number;
  };
}

interface LogEntry {
  msg: string;
  style: string;
}

function App() {
  const [status, setStatus] = useState<Status | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [chatHistory, setChatHistory] = useState<{msg: string, sender: 'ai' | 'user'}[]>([
    { msg: "Neural interface initialized. All systems nominal.", sender: 'ai' }
  ]);
  const [chatInput, setChatInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);

  const logEndRef = useRef<HTMLDivElement>(null);
  const logSocket = useRef<WebSocket | null>(null);
  const chatSocket = useRef<WebSocket | null>(null);

  useEffect(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;

    const connectLogs = () => {
      logSocket.current = new WebSocket(`${protocol}//${host}/ws/logs`);
      logSocket.current.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.ping) return;
        setLogs(prev => [...prev.slice(-1000), { msg: data.msg, style: data.style }]);
      };
      logSocket.current.onclose = () => setTimeout(connectLogs, 2000);
    };

    const connectChat = () => {
      chatSocket.current = new WebSocket(`${protocol}//${host}/ws/chat`);
      chatSocket.current.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.status === 'thinking') setIsThinking(true);
        else if (data.status === 'complete') {
          setIsThinking(false);
          setChatHistory(prev => [...prev, { msg: data.answer, sender: 'ai' }]);
        }
      };
      chatSocket.current.onclose = () => setTimeout(connectChat, 2000);
    };

    connectLogs();
    connectChat();

    const interval = setInterval(async () => {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        if (data.status === 'ok') setStatus(data);
      } catch (e) { console.error(e); }
    }, 1000);

    return () => {
      clearInterval(interval);
      logSocket.current?.close();
      chatSocket.current?.close();
    };
  }, []);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  const controlAction = (action: string) => fetch(`/api/control/${action}`, { method: 'POST' });
  const runStep = (idx: number) => fetch(`/api/step/${idx}/run`, { method: 'POST' });

  const sendChat = () => {
    if (!chatInput.trim() || !chatSocket.current) return;
    setChatHistory(prev => [...prev, { msg: chatInput, sender: 'user' }]);
    chatSocket.current.send(JSON.stringify({ question: chatInput }));
    setChatInput("");
  };

  const getLogStyle = (style: string) => {
    let classes = "";
    if (style.includes('green')) classes += " text-accent-green";
    if (style.includes('cyan')) classes += " text-accent-cyan";
    if (style.includes('red')) classes += " text-accent-red";
    if (style.includes('yellow')) classes += " text-yellow-400";
    if (style.includes('bold')) classes += " font-bold";
    return classes;
  };

  const completedSteps = status?.steps.filter(s => s.status === 'completed').length || 0;
  const totalProgress = status ? Math.round((completedSteps / status.steps.length) * 100) : 0;

  const updateCoreCount = (count: number) => {
    fetch(`/api/control/cores/${count}`, { method: 'POST' });
  };

  return (
    <div className="flex flex-col h-screen bg-bg-deep text-text-main font-sans selection:bg-accent-cyan/30">
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&family=JetBrains+Mono:wght@300;500&display=swap" rel="stylesheet" />
      
      {/* HEADER */}
      <header className="h-16 glass z-50 flex items-center justify-between px-8">
        <div className="flex items-center gap-6">
          <div className="flex flex-col">
            <h1 className="text-lg font-bold tracking-tight text-accent-cyan uppercase glow-cyan">Ginger // <span className="text-white">Matrix</span></h1>
            <div className="text-[10px] text-text-dim tracking-[0.2em] uppercase font-semibold">Neural Ops Console v9.4</div>
          </div>
          <div className="h-6 w-[1px] bg-white/10" />
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-accent-green animate-pulse shadow-[0_0_8px_#00ff88]" />
            <span className="text-[10px] font-bold tracking-widest text-accent-green uppercase">Link Active</span>
          </div>
        </div>
        
        <div className="flex items-center gap-4">
          <div className="flex flex-col items-end mr-4">
            <div className="text-[10px] text-text-dim uppercase font-bold">Uptime</div>
            <div className="text-xs font-mono">02:14:55:09</div>
          </div>
          <button onClick={() => controlAction('auto')} className="px-5 py-2 glass glass-hover text-[10px] font-bold uppercase tracking-widest text-accent-cyan hover:text-white transition-all">
            Auto Protocol
          </button>
          <button onClick={() => controlAction('abort')} className="px-5 py-2 border border-accent-red/30 bg-accent-red/10 text-accent-red text-[10px] font-bold uppercase tracking-widest hover:bg-accent-red hover:text-white transition-all">
            Kill Module
          </button>
        </div>
      </header>

      {/* MAIN CONTENT */}
      <main className="flex-1 flex overflow-hidden p-4 gap-4">
        
        {/* LEFT: PIPELINE */}
        <section className="w-80 flex flex-col gap-4">
          <div className="glass p-4 rounded-xl flex flex-col h-full overflow-hidden">
            <div className="flex items-center justify-between mb-4 px-1">
              <h2 className="text-[10px] font-bold text-text-dim uppercase tracking-[0.2em]">Deployment Pipeline</h2>
              <span className="text-[10px] font-mono text-accent-cyan">{completedSteps}/{status?.steps.length}</span>
            </div>
            <div className="flex-1 overflow-y-auto space-y-2 pr-2">
              {status?.steps.map((step, idx) => (
                <button 
                  key={step.id}
                  onClick={() => runStep(idx)}
                  className={`w-full text-left p-3 rounded-lg border transition-all duration-300 group ${
                    status.executing_step === idx 
                      ? 'bg-accent-cyan/10 border-accent-cyan/40 shadow-[0_0_15px_rgba(0,210,255,0.1)]' 
                      : 'bg-white/5 border-white/5 hover:bg-white/10 hover:border-white/20'
                  }`}
                >
                  <div className="flex justify-between items-start mb-1">
                    <span className="text-xs font-semibold truncate pr-2">{step.name}</span>
                    <span className={`text-[9px] font-bold uppercase ${
                      step.status === 'completed' ? 'text-accent-green' : 
                      step.status === 'running' ? 'text-accent-cyan animate-pulse' : 
                      'text-text-dim'
                    }`}>{step.status}</span>
                  </div>
                  <div className="text-[9px] text-text-dim uppercase tracking-tighter">{step.phase}</div>
                </button>
              ))}
            </div>
          </div>
        </section>

        {/* CENTER: LOGS */}
        <section className="flex-1 flex flex-col gap-4 overflow-hidden">
          <div className="glass rounded-xl flex-1 flex flex-col overflow-hidden relative scanline">
            <div className="p-4 border-b border-white/10 bg-white/5 flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-1.5 h-1.5 rounded-full bg-accent-cyan" />
                <h2 className="text-[10px] font-bold text-text-dim uppercase tracking-[0.2em]">Neural Stream</h2>
              </div>
              <div className="text-[10px] font-mono text-accent-cyan bg-accent-cyan/10 px-3 py-1 rounded-full border border-accent-cyan/20">
                {status?.current_pkg || (status?.running ? 'Broadcasting...' : 'Core_Standby')}
              </div>
            </div>
            <div className="flex-1 bg-black/40 p-6 overflow-y-auto font-mono text-[13px] leading-relaxed selection:bg-accent-cyan/40">
              {logs.map((log, i) => (
                <div key={i} className={`mb-1 opacity-90 hover:opacity-100 transition-opacity ${getLogStyle(log.style)}`}>
                  <span className="text-[10px] opacity-40 mr-3">[{new Date().toLocaleTimeString([], {hour12: false})}]</span>
                  {log.msg}
                </div>
              ))}
              <div ref={logEndRef} />
            </div>
          </div>
        </section>

        {/* RIGHT: SYSTEMS */}
        <section className="w-80 flex flex-col gap-4">
          {/* TELEMETRY */}
          <div className="glass p-5 rounded-xl space-y-6">
            <h2 className="text-[10px] font-bold text-text-dim uppercase tracking-[0.2em] mb-4">Core Telemetry</h2>
            
            <div className="space-y-2">
              <div className="flex justify-between text-[11px] font-semibold">
                <span>LFS Mount Capacity</span>
                <span className="text-accent-cyan">{Math.round(status?.storage.lfs || 0)}%</span>
              </div>
              <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                <div 
                  className="h-full progress-gradient transition-all duration-1000 shadow-[0_0_10px_rgba(0,210,255,0.5)]" 
                  style={{ width: `${status?.storage.lfs || 0}%` }}
                />
              </div>
            </div>

            <div className="space-y-3 bg-white/5 p-4 border-l-2 border-accent-cyan">
              <div className="flex justify-between items-center">
                <div className="text-[10px] text-text-dim uppercase font-bold">Core Allocation</div>
                <div className="text-xs font-mono text-accent-cyan">{status?.cores} / {status?.max_cores}</div>
              </div>
              <input 
                type="range" 
                min="1" 
                max={status?.max_cores || 1} 
                value={status?.cores || 1}
                onChange={(e) => updateCoreCount(parseInt(e.target.value))}
                className="w-full h-1 bg-white/10 rounded-full appearance-none cursor-pointer accent-accent-cyan"
              />
              <div className="flex justify-between text-[8px] text-text-dim uppercase font-bold px-1">
                <span>Power_Save</span>
                <span>Max_Perf</span>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex justify-between text-[11px] font-semibold">
                <span>Host Disk Load</span>
                <span className="text-accent-blue">{Math.round(status?.storage.host || 0)}%</span>
              </div>
              <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-accent-blue transition-all duration-1000 shadow-[0_0_10px_rgba(58,123,213,0.5)]" 
                  style={{ width: `${status?.storage.host || 0}%` }}
                />
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex justify-between text-[11px] font-semibold">
                <span>Deployment Sync</span>
                <span className="text-accent-green">{totalProgress}%</span>
              </div>
              <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-accent-green transition-all duration-1000 shadow-[0_0_10px_rgba(0,255,136,0.5)]" 
                  style={{ width: `${totalProgress}%` }}
                />
              </div>
            </div>
          </div>

          {/* AI BRAIN */}
          <div className="glass p-5 rounded-xl flex-1 flex flex-col overflow-hidden">
            <h2 className="text-[10px] font-bold text-text-dim uppercase tracking-[0.2em] mb-4">Neural Interface</h2>
            <div className="flex-1 overflow-y-auto space-y-4 pr-2 mb-4 scrollbar-none">
              {chatHistory.map((chat, i) => (
                <div 
                  key={i} 
                  className={`p-3 rounded-lg text-xs leading-relaxed ${
                    chat.sender === 'user' 
                      ? 'bg-accent-cyan/10 border border-accent-cyan/20 ml-4' 
                      : 'bg-white/5 border border-white/5 mr-4'
                  }`}
                >
                  <div className="text-[9px] uppercase font-bold mb-1 opacity-40">{chat.sender}</div>
                  {chat.msg}
                </div>
              ))}
              {isThinking && (
                <div className="bg-white/5 border border-white/5 p-3 rounded-lg text-[10px] animate-pulse text-text-dim">
                  Synchronizing brain waves...
                </div>
              )}
            </div>
            <div className="relative">
              <input 
                type="text" 
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendChat()}
                placeholder="Query system..."
                className="w-full bg-black/40 border border-white/10 rounded-lg px-4 py-3 text-xs focus:border-accent-cyan/50 focus:bg-black/60 outline-none transition-all pr-12"
              />
              <button onClick={sendChat} className="absolute right-2 top-2 p-1.5 text-accent-cyan hover:text-white transition-colors">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>
              </button>
            </div>
          </div>
        </section>

      </main>
    </div>
  );
}

export default App;
