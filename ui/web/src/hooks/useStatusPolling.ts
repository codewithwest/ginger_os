import { useState, useEffect } from 'react';

interface StatusData {
  status: string;
  running: boolean;
  current_pkg: string;
  executing_step: number | null;
  steps: Array<{
    id: string;
    name: string;
    phase: string;
    status: 'pending' | 'running' | 'completed' | 'failed';
    progress: number;
    duration: number;
  }>;
  cores: number;
  max_cores: number;
  cpu_usage: number;
  timers: {
    package: number;
    phase: number;
    overall: number;
  };
  storage: {
    lfs: number;
    host: number;
  };
}

interface UseStatusPollingResult {
  status: StatusData | null;
  connected: boolean;
  error: string | null;
}

export function useStatusPolling(intervalMs = 1000): UseStatusPollingResult {
  const [status, setStatus] = useState<StatusData | null>(null);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    const poll = async () => {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);

        const res = await fetch('/api/status', { signal: controller.signal });
        clearTimeout(timeout);

        if (!res.ok) throw new Error(`HTTP ${res.status}`);

        const data = await res.json();
        if (!mounted) return;

        if (data.status === 'ok') {
          setStatus(data);
          setConnected(true);
          setError(null);
        } else {
          throw new Error(data.message || 'Invalid status response');
        }
      } catch (e) {
        if (!mounted) return;
        setConnected(false);
        setError(e instanceof Error ? e.message : 'Connection lost');
      }
    };

    poll();
    const id = setInterval(poll, intervalMs);

    return () => {
      mounted = false;
      clearInterval(id);
    };
  }, [intervalMs]);

  return { status, connected, error };
}
