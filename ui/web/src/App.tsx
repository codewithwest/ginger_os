import { useState, useEffect, useCallback, useMemo } from 'react';
import { Background3D } from './components/Background3D';
import { Header } from './components/Header';
import { PipelineSidebar } from './components/PipelineSidebar';
import { LogStream } from './components/LogStream';
import { SystemsPanel } from './components/SystemsPanel';
import { NeuralInterface } from './components/NeuralInterface';
import { useWebSocket } from './hooks/useWebSocket';
import { useStatusPolling } from './hooks/useStatusPolling';

interface PackageItem {
  name: string;
  built: boolean;
}

interface LogEntry {
  msg: string;
  style: string;
}

function App() {
  const { status, connected: apiConnected } = useStatusPolling(1000);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [wsConnected, setWsConnected] = useState(false);
  const [chatHistory, setChatHistory] = useState<{msg: string, sender: 'ai' | 'user'}[]>([
    { msg: 'Neural interface initialized. All systems nominal.', sender: 'ai' }
  ]);
  const [isThinking, setIsThinking] = useState(false);
  const [selectedPhaseIdx, setSelectedPhaseIdx] = useState(0);
  const [packages, setPackages] = useState<PackageItem[]>([]);
  const [packageError, setPackageError] = useState<string | null>(null);
  const [packagesFetchedFor, setPackagesFetchedFor] = useState<number | null>(null);
  const [parallelWindow, setParallelWindow] = useState(4);

  // Fetch parallel_window from server config on mount
  useEffect(() => {
    const controller = new AbortController();
    fetch('/api/config', { signal: controller.signal })
      .then(r => r.json())
      .then(data => {
        if (data.status === 'ok' && data.config?.PARALLEL_WINDOW) {
          setParallelWindow(parseInt(data.config.PARALLEL_WINDOW) || 4);
        }
      })
      .catch(() => {});
    return () => controller.abort();
  }, []);

  const connected = apiConnected && wsConnected;

  useWebSocket<LogEntry & { ping?: boolean }>({
    path: '/ws/logs',
    onMessage: useCallback((data) => {
      if (data.ping) return;
      setLogs(prev => [...prev.slice(-1000), { msg: data.msg, style: data.style }]);
    }, []),
    onStatusChange: setWsConnected,
  });

  const { send: sendChat } = useWebSocket<{ status: string; answer: string }>({
    path: '/ws/chat',
    onMessage: useCallback((data) => {
      if (data.status === 'thinking') setIsThinking(true);
      else if (data.status === 'complete') {
        setIsThinking(false);
        setChatHistory(prev => [...prev, { msg: data.answer, sender: 'ai' }]);
      }
    }, []),
    onStatusChange: () => {},
  });

  const controlAction = useCallback((action: string) => {
    fetch(`/api/control/${action}`, { method: 'POST' }).catch(() => {});
  }, []);

  const fetchPackages = useCallback(async (idx: number) => {
    if (!status?.steps || idx < 0 || idx >= status.steps.length) {
      setPackages([]);
      setPackageError(null);
      return;
    }
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000);
      const res = await fetch(`/api/step/${idx}/packages`, { signal: controller.signal });
      clearTimeout(timeout);
      const data = await res.json();
      if (data.status === 'ok') {
        setPackages(data.packages || []);
        setPackageError(null);
      } else {
        setPackages([]);
        setPackageError(data.message || 'Unable to load package list.');
      }
    } catch {
      setPackages([]);
      setPackageError('Unable to load package list.');
    }
  }, [status]);

  useEffect(() => {
    if (status?.steps?.length && packagesFetchedFor !== selectedPhaseIdx) {
      fetchPackages(selectedPhaseIdx);
      setPackagesFetchedFor(selectedPhaseIdx);
    }
  }, [selectedPhaseIdx, status, packagesFetchedFor, fetchPackages]);

  const runStep = useCallback(async (idx: number, pkg?: string) => {
    const query = pkg ? `?pkg=${encodeURIComponent(pkg)}` : '';
    try { await fetch(`/api/step/${idx}/run${query}`, { method: 'POST' }); } catch {}
    if (pkg) fetchPackages(idx);
  }, [fetchPackages]);

  const forceStep = useCallback(async (idx: number, pkg?: string) => {
    const query = pkg ? `?pkg=${encodeURIComponent(pkg)}` : '';
    try { await fetch(`/api/step/${idx}/force${query}`, { method: 'POST' }); } catch {}
    if (pkg) fetchPackages(idx);
  }, [fetchPackages]);

  const runPhase = useCallback((idx: number) => runStep(idx), [runStep]);
  const forcePhase = useCallback((idx: number) => forceStep(idx), [forceStep]);
  const runPackage = useCallback((pkg: string) => runStep(selectedPhaseIdx, pkg), [runStep, selectedPhaseIdx]);
  const forcePackage = useCallback((pkg: string) => forceStep(selectedPhaseIdx, pkg), [forceStep, selectedPhaseIdx]);

  const updateCoreCount = useCallback((count: number) => {
    fetch(`/api/control/cores/${count}`, { method: 'POST' }).catch(() => {});
  }, []);

  const updateWindowCount = useCallback((count: number) => {
    setParallelWindow(count);
    fetch('/api/config/update', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key: 'PARALLEL_WINDOW', value: String(count) }),
    }).catch(() => {});
  }, []);

  const handleSendChat = useCallback((msg: string) => {
    setChatHistory(prev => [...prev, { msg, sender: 'user' }]);
    sendChat({ question: msg });
  }, [sendChat]);

  const steps = useMemo(() => status?.steps || [], [status]);
  const completedSteps = useMemo(() => steps.filter(s => s.status === 'completed').length, [steps]);
  const timers = useMemo(() => status?.timers || null, [status]);

  return (
    <div className="relative flex flex-col h-screen bg-transparent text-text-main font-sans selection:bg-accent-cyan/30">
      <Header
        cpuUsage={status?.cpu_usage || 0}
        maxCores={status?.max_cores || 0}
        timers={timers}
        uptime={status?.timers?.overall || 0}
        connected={connected}
        onControlAction={controlAction}
      />

      <Background3D />
      <div className="relative z-10 flex flex-1 flex-col min-h-0">
        <main className="flex-1 flex overflow-hidden p-4 gap-4">
        <PipelineSidebar
          steps={steps}
          selectedPhaseIdx={selectedPhaseIdx}
          onSelectPhase={setSelectedPhaseIdx}
          onRunPhase={runPhase}
          onForcePhase={forcePhase}
          onRunPackage={runPackage}
          onForcePackage={forcePackage}
          packages={packages}
          packageError={packageError}
          onRefreshPackages={() => fetchPackages(selectedPhaseIdx)}
        />

        <LogStream
          logs={logs}
          currentPkg={status?.current_pkg || ''}
          running={status?.running || false}
        />

        <section className="w-80 flex flex-col gap-4">
          <SystemsPanel
            storageLfs={status?.storage?.lfs || 0}
            storageHost={status?.storage?.host || 0}
            cores={status?.cores || 1}
            maxCores={status?.max_cores || 1}
            completedSteps={completedSteps}
            totalSteps={steps.length}
            onCoreChange={updateCoreCount}
            parallelWindow={parallelWindow}
            onWindowChange={updateWindowCount}
          />

          <NeuralInterface
            chatHistory={chatHistory}
            isThinking={isThinking}
            onSendChat={handleSendChat}
            connected={connected}
          />
        </section>
        </main>
      </div>
    </div>
  );
}

export default App;
