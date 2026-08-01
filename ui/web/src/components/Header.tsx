import { memo } from 'react';

interface HeaderProps {
  cpuUsage: number;
  maxCores: number;
  timers: { package: number; phase: number; overall: number } | null;
  uptime: number;
  connected: boolean;
  onControlAction: (action: string) => void;
}

function HeaderInner({ cpuUsage, maxCores, timers, uptime, connected, onControlAction }: HeaderProps) {
  const formatTime = (seconds: number) => {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const formatLongTime = (seconds: number) => {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (d > 0) return `${d}d ${h}h ${m}m ${s}s`;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  return (
    <header className="h-16 glass z-50 flex items-center justify-between px-6 border-b border-white/5">
      <div className="flex items-center gap-5">
        <div className="flex items-center gap-3">
          <div className="w-1.5 h-1.5 rounded-full bg-accent-cyan glow-cyan" />
          <h1 className="text-base font-bold tracking-tight text-white">
            <span className="text-accent-cyan">Ginger</span>OS
          </h1>
        </div>
        <div className="h-5 w-px bg-white/5" />
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full transition-all duration-500 ${connected ? 'bg-accent-green shadow-[0_0_10px_rgba(0,255,136,0.6)]' : 'bg-accent-red shadow-[0_0_10px_rgba(255,51,102,0.4)]'}`} />
          <span className={`text-[9px] font-bold tracking-widest uppercase ${connected ? 'text-accent-green' : 'text-accent-red'}`}>
            {connected ? 'Operational' : 'Disconnected'}
          </span>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <div className="flex items-center gap-4 mr-4">
          <div className="flex flex-col items-center">
            <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">CPU</div>
            <div className="text-xs font-mono text-accent-cyan">
              {Math.round(cpuUsage)}% <span className="opacity-40 text-[8px]">({maxCores}c)</span>
            </div>
          </div>
          <div className="flex flex-col items-center">
            <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">Phase</div>
            <div className="text-xs font-mono text-accent-cyan">{formatTime(timers?.phase || 0)}</div>
          </div>
          <div className="flex flex-col items-center">
            <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">Total</div>
            <div className="text-xs font-mono text-accent-green">{formatTime(timers?.overall || 0)}</div>
          </div>
        </div>

        <div className="flex flex-col items-center mr-2">
          <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">Uptime</div>
          <div className="text-xs font-mono text-text-main">{formatLongTime(uptime)}</div>
        </div>
        <div className="flex gap-2">
          <button onClick={() => onControlAction('rebuild_ui')} className="btn-primary hover:!text-white hover:!border-accent-cyan/60 hover:!bg-accent-cyan/[0.15] !py-1.5 !px-3">Rebuild UI</button>
          <button onClick={() => onControlAction('auto')} className="btn-success hover:!text-white hover:!border-accent-green/60 hover:!bg-accent-green/[0.15] !py-1.5 !px-3">Auto</button>
          <button onClick={() => onControlAction('abort')} className="btn-danger hover:!text-white hover:!border-accent-red/60 hover:!bg-accent-red/[0.15] !py-1.5 !px-3">Abort</button>
        </div>
      </div>
    </header>
  );
}

export const Header = memo(HeaderInner);
