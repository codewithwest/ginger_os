import { memo, useCallback } from 'react';

interface SystemsPanelProps {
  storageLfs: number;
  storageHost: number;
  cores: number;
  maxCores: number;
  completedSteps: number;
  totalSteps: number;
  onCoreChange: (count: number) => void;
  parallelWindow: number;
  onWindowChange: (count: number) => void;
}

function SystemsPanelInner({ storageLfs, storageHost, cores, maxCores, completedSteps, totalSteps, onCoreChange, parallelWindow, onWindowChange }: SystemsPanelProps) {
  const totalProgress = totalSteps > 0 ? Math.round((completedSteps / totalSteps) * 100) : 0;

  const handleCoreChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    onCoreChange(parseInt(e.target.value));
  }, [onCoreChange]);

  const handleWindowChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    onWindowChange(parseInt(e.target.value));
  }, [onWindowChange]);

  return (
    <section className="w-80 flex flex-col gap-4">
      <div className="glass elevation-2 p-5 rounded-2xl space-y-5">
        <h2 className="text-[9px] font-bold text-text-dim uppercase tracking-[0.2em]">Systems</h2>

        <div className="space-y-2">
          <div className="flex justify-between items-center">
            <span className="text-[9px] font-semibold text-text-dim uppercase tracking-wider">LFS Capacity</span>
            <span className="text-[11px] font-mono text-accent-cyan">{Math.round(storageLfs)}%</span>
          </div>
          <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
            <div className="h-full progress-gradient transition-all duration-1000 shadow-[0_0_10px_rgba(0,210,255,0.4)]" style={{ width: `${storageLfs}%` }} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-transparent border border-white/10 space-y-3">
          <div className="flex justify-between items-center">
            <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">Cores</div>
            <div className="text-xs font-mono text-accent-cyan">{cores} / {maxCores}</div>
          </div>
          <input
            type="range"
            min="1"
            max={maxCores || 1}
            value={cores || 1}
            onChange={handleCoreChange}
            className="w-full accent-accent-cyan"
            style={{ accentColor: '#00d2ff' }}
          />
          <div className="flex justify-between text-[7px] text-text-dim uppercase font-bold tracking-wider">
            <span>Min</span>
            <span>Max</span>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-transparent border border-white/10 space-y-3">
          <div className="flex justify-between items-center">
            <div className="text-[8px] text-text-dim uppercase font-bold tracking-wider">Parallel Window</div>
            <div className="text-xs font-mono text-accent-green">{parallelWindow}</div>
          </div>
          <input
            type="range"
            min="1"
            max="16"
            value={parallelWindow}
            onChange={handleWindowChange}
            className="w-full accent-accent-green"
            style={{ accentColor: '#00ff88' }}
          />
          <div className="flex justify-between text-[7px] text-text-dim uppercase font-bold tracking-wider">
            <span>Sequential</span>
            <span>Aggressive</span>
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex justify-between items-center">
            <span className="text-[9px] font-semibold text-text-dim uppercase tracking-wider">Host Disk</span>
            <span className="text-[11px] font-mono text-accent-blue">{Math.round(storageHost)}%</span>
          </div>
          <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
            <div className="h-full bg-accent-blue transition-all duration-1000 shadow-[0_0_10px_rgba(58,123,213,0.4)]" style={{ width: `${storageHost}%` }} />
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex justify-between items-center">
            <span className="text-[9px] font-semibold text-text-dim uppercase tracking-wider">Pipeline</span>
            <span className="text-[11px] font-mono text-accent-green">{totalProgress}%</span>
          </div>
          <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
            <div className="h-full progress-glowing transition-all duration-1000" style={{ width: `${totalProgress}%` }} />
          </div>
        </div>
      </div>
    </section>
  );
}

export const SystemsPanel = memo(SystemsPanelInner);
