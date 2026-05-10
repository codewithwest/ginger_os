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
    { msg: "Neural interface initialized. How can I assist with the build?", sender: 'ai' }
  ]);
  const [chatInput, setChatInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);

  const logEndRef = useRef<HTMLDivElement>(null);
  const logSocket = useRef<WebSocket | null>(null);
  const chatSocket = useRef<WebSocket | null>(null);

  // Initialize WebSockets
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

    // Status polling
    const interval = setInterval(async () => {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        if (data.status !== 'error') setStatus(data);
      } catch (e) {
        console.error("Status fetch failed", e);
      }
    }, 1000);

    return () => {
      clearInterval(interval);
      logSocket.current?.close();
      chatSocket.current?.close();
    };
  }, []);

  // Auto-scroll logs
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

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'text-accent-green';
      case 'running': return 'text-accent-cyan animate-pulse';
      case 'failed': return 'text-accent-red';
      default: return 'text-text-dim';
    }
  };

  const getLogStyle = (style: string) => {
    let classes = "";
    if (style.includes('green')) classes += " text-accent-green";
    if (style.includes('cyan')) classes += " text-accent-cyan";
    if (style.includes('red')) classes += " text-accent-red";
    if (style.includes('yellow')) classes += " text-[#ffcc00]";
    if (style.includes('bold')) classes += " font-bold";
    return classes;
  };

  const completedSteps = status?.steps.filter(s => s.status === 'completed').length || 0;
  const totalProgress = status ? Math.round((completedSteps / status.steps.length) * 100) : 0;

  return (
    <div className="flex flex-col h-screen bg-bg-deep text-text-main font-mono">
      {/* HEADER */}
      <header className="h-16 bg-bg-panel border-b border-white/10 flex items-center justify-between px-6 glow-cyan z-50">
        <div className="flex items-center gap-4">
          <h1 className="text-xl font-bold tracking-tighter text-accent-cyan text-glow-cyan">GINGER // MATRIX</h1>
          <div className="px-3 py-1 rounded-full text-xs border border-accent-green bg-accent-green/10 text-accent-green">
            LINK_ACTIVE
          </div>
        </div>
        <div className="flex gap-4">
          <button onClick={() => controlAction('auto')} className="px-4 py-2 border border-accent-cyan text-accent-cyan text-xs font-bold uppercase hover:bg-accent-cyan hover:text-black transition-all">
            Auto Mode
          </button>
          <button onClick={() => controlAction('abort')} className="px-4 py-2 border border-accent-red text-accent-red text-xs font-bold uppercase hover:bg-accent-red hover:text-black transition-all">
            Abort
          </button>
        </div>
      </header>

      {/* MAIN LAYOUT */}
      <main className="flex-1 flex overflow-hidden bg-white/5 gap-[1px]">
        
        {/* LEFT: BUILD PIPELINE */}
        <section className="w-[350px] bg-bg-panel flex flex-col">
          <div className="p-4 border-b border-white/10 bg-white/5">
            <h2 className="text-xs font-bold text-accent-cyan uppercase">Build Pipeline</h2>
          </div>
          <div className="flex-1 overflow-y-auto p-3">
            {status?.steps.map((step, idx) => (
              <div 
                key={step.id}
                onClick={() => runStep(idx)}
                className={`p-3 mb-2 rounded border transition-all cursor-pointer group ${
                  status.executing_step === idx 
                    ? 'border-accent-cyan bg-accent-cyan/10' 
                    : 'border-transparent bg-white/5 hover:border-white/20'
                }`}
              >
                <div className="flex justify-between items-start">
                  <div>
                    <div className="text-sm font-medium">{step.name}</div>
                    <div className="text-[10px] text-text-dim uppercase tracking-widest">{step.phase}</div>
                  </div>
                  <div className={`text-[10px] font-bold ${getStatusColor(step.status)}`}>
                    {step.status.toUpperCase()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* CENTER: LOGS */}
        <section className="flex-1 bg-bg-panel flex flex-col">
          <div className="p-4 border-b border-white/10 bg-white/5 flex justify-between items-center">
            <h2 className="text-xs font-bold text-accent-cyan uppercase">Neural Log Stream</h2>
            <div className="text-[10px] text-accent-cyan flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-accent-cyan animate-pulse"></span>
              {status?.current_pkg || (status?.running ? 'SYNCHRONIZING...' : 'SYSTEM_IDLE')}
            </div>
          </div>
          <div className="flex-1 bg-black p-6 overflow-y-auto font-mono text-sm leading-relaxed scrollbar-thin">
            {logs.map((log, i) => (
              <div key={i} className={`mb-1 break-words ${getLogStyle(log.style)}`}>
                {log.msg}
              </div>
            ))}
            <div ref={logEndRef} />
          </div>
        </section>

        {/* RIGHT: TELEMETRY & CHAT */}
        <section className="w-[350px] bg-bg-panel flex flex-col">
          <div className="p-4 border-b border-white/10 bg-white/5">
            <h2 className="text-xs font-bold text-accent-cyan uppercase">Core Telemetry</h2>
          </div>
          <div className="p-5 flex flex-col gap-6">
            <div className="bg-white/5 p-4 border-l-2 border-accent-cyan">
              <div className="text-[10px] text-text-dim uppercase mb-1">LFS Mount</div>
              <div className="text-lg font-bold">{Math.round(status?.storage.lfs || 0)}% Capacity</div>
              <div className="h-1.5 w-full bg-white/10 mt-2 overflow-hidden rounded-full">
                <div 
                  className="h-full bg-accent-cyan transition-all duration-500 shadow-[0_0_10px_#00f0ff]" 
                  style={{ width: `${status?.storage.lfs || 0}%` }}
                />
              </div>
            </div>
            <div className="bg-white/5 p-4 border-l-2 border-accent-green">
              <div className="text-[10px] text-text-dim uppercase mb-1">Total Build Progress</div>
              <div className="text-lg font-bold">{totalProgress}% Synchronized</div>
              <div className="h-1.5 w-full bg-white/10 mt-2 overflow-hidden rounded-full">
                <div 
                  className="h-full bg-accent-green transition-all duration-500 shadow-[0_0_10px_#00ff88]" 
                  style={{ width: `${totalProgress}%` }}
                />
              </div>
            </div>
          </div>

          <div className="p-4 border-y border-white/10 bg-white/5">
            <h2 className="text-xs font-bold text-accent-cyan uppercase">Neural Brain</h2>
          </div>
          <div className="flex-1 flex flex-col p-4 overflow-hidden">
            <div className="flex-1 overflow-y-auto flex flex-col gap-4 mb-4 scrollbar-none">
              {chatHistory.map((chat, i) => (
                <div 
                  key={i} 
                  className={`max-w-[90%] p-3 text-xs border ${
                    chat.sender === 'user' 
                      ? 'self-end bg-accent-cyan/10 border-accent-cyan/30' 
                      : 'self-start bg-white/5 border-white/10'
                  }`}
                >
                  {chat.msg}
                </div>
              ))}
              {isThinking && (
                <div className="self-start bg-white/5 border border-white/10 p-3 text-xs animate-pulse italic text-text-dim">
                  Analyzing data...
                </div>
              )}
            </div>
            <div className="flex gap-2">
              <input 
                type="text" 
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendChat()}
                placeholder="Query build state..."
                className="flex-1 bg-black border border-white/20 px-3 py-2 text-xs focus:border-accent-cyan outline-none transition-all"
              />
              <button onClick={sendChat} className="bg-accent-cyan text-black px-4 py-2 text-xs font-bold hover:bg-white transition-all">
                SEND
              </button>
            </div>
          </div>
        </section>

      </main>
    </div>
  );
}

export default App;
