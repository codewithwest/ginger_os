import { useEffect, useRef, useCallback } from 'react';

interface UseWebSocketOptions<T> {
  path: string;
  onMessage: (data: T) => void;
  onStatusChange?: (connected: boolean) => void;
  reconnectInterval?: number;
}

export function useWebSocket<T>({ path, onMessage, onStatusChange, reconnectInterval = 2000 }: UseWebSocketOptions<T>) {
  const wsRef = useRef<WebSocket | null>(null);
  const retryCountRef = useRef(0);
  const mountedRef = useRef(true);

  const connect = useCallback(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    const ws = new WebSocket(`${protocol}//${host}${path}`);

    ws.onopen = () => {
      retryCountRef.current = 0;
      onStatusChange?.(true);
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        onMessage(data);
      } catch { /* ignore malformed messages */ }
    };

    ws.onerror = () => {
      onStatusChange?.(false);
    };

    ws.onclose = () => {
      onStatusChange?.(false);
      if (mountedRef.current) {
        retryCountRef.current++;
        const delay = Math.min(reconnectInterval * Math.pow(1.5, retryCountRef.current - 1), 30000);
        setTimeout(connect, delay);
      }
    };

    wsRef.current = ws;
  }, [path, onMessage, onStatusChange, reconnectInterval]);

  useEffect(() => {
    mountedRef.current = true;
    connect();
    return () => {
      mountedRef.current = false;
      wsRef.current?.close();
    };
  }, [connect]);

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  return { send };
}
