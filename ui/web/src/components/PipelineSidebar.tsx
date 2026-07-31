import { memo } from 'react';

interface Step {
  id: string;
  name: string;
  phase: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress: number;
  duration: number;
}

interface PackageItem {
  name: string;
  built: boolean;
}

interface PipelineSidebarProps {
  steps: Step[];
  selectedPhaseIdx: number;
  onSelectPhase: (idx: number) => void;
  onRunPhase: (idx: number) => void;
  onForcePhase: (idx: number) => void;
  onRunPackage: (pkg: string) => void;
  onForcePackage: (pkg: string) => void;
  packages: PackageItem[];
  packageError: string | null;
  onRefreshPackages: () => void;
}

const statusConfig: Record<string, { color: string; label: string; indicator: string }> = {
  completed: { color: 'text-accent-green', label: 'Done', indicator: '●' },
  running:   { color: 'text-accent-cyan', label: 'Run', indicator: '▶' },
  failed:    { color: 'text-accent-red', label: 'Fail', indicator: '●' },
  pending:   { color: 'text-text-dim', label: '--', indicator: '○' },
};

const StepButton = memo(({ step, idx, selected, onSelect, onRun, onForce }: {
  step: Step; idx: number; selected: boolean;
  onSelect: (idx: number) => void; onRun: (idx: number) => void; onForce: (idx: number) => void;
}) => {
  const cfg = statusConfig[step.status] || statusConfig.pending;

  return (
    <div
      className={`w-full text-left p-3 rounded-lg border transition-all duration-300 card-hover ${
        selected
          ? 'bg-accent-cyan/10 border-accent-cyan/40 shadow-[0_0_20px_rgba(0,210,255,0.12)]'
          : 'border-white/5 bg-white/[0.02]'
      }`}
    >
      <button className="w-full text-left" onClick={() => onSelect(idx)}>
        <div className="flex justify-between items-start mb-1">
          <div className="flex items-center gap-2 min-w-0">
            <span className={`text-[9px] ${cfg.color} transition-colors`}>{cfg.indicator}</span>
            <span className="text-xs font-semibold truncate text-white">{step.name}</span>
          </div>
          <span className={`text-[8px] font-bold uppercase whitespace-nowrap tracking-wider ${cfg.color} ${
            step.status === 'running' ? 'animate-pulse' : ''
          }`}>
            {cfg.label}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-[8px] text-text-dim uppercase tracking-tighter">{step.phase}</span>
          {step.status === 'running' && step.progress > 0 && (
            <span className="text-[8px] font-mono text-accent-cyan">{step.progress}%</span>
          )}
        </div>
        {step.status === 'running' && step.progress > 0 && (
          <div className="mt-1.5 h-0.5 bg-white/5 rounded-full overflow-hidden">
            <div
              className="h-full progress-gradient transition-all duration-500"
              style={{ width: `${step.progress}%` }}
            />
          </div>
        )}
      </button>
      {selected && (
        <div className="flex gap-1.5 mt-2 animate-fade-in-up">
          <button onClick={() => onRun(idx)} className="btn-primary !py-1 !px-2.5 !text-[8px]">
            Run
          </button>
          <button onClick={() => onForce(idx)} className="btn-success !py-1 !px-2.5 !text-[8px]">
            Force
          </button>
        </div>
      )}
    </div>
  );
});

const PackageCard = memo(({ pkg, onRun, onForce }: {
  pkg: PackageItem; onRun: (name: string) => void; onForce: (name: string) => void;
}) => (
  <div className="flex items-center justify-between gap-3 p-3 rounded-lg bg-black/30 border border-white/5 card-hover">
    <div className="min-w-0 flex-1">
      <div className="text-sm font-semibold text-white truncate">{pkg.name}</div>
      <div className="flex items-center gap-1.5 mt-1">
        <span className={`w-1.5 h-1.5 rounded-full ${pkg.built ? 'bg-accent-green glow-green' : 'bg-text-dim'}`} />
        <span className="text-[8px] text-text-dim uppercase tracking-wider">{pkg.built ? 'Built' : 'Pending'}</span>
      </div>
    </div>
    <div className="flex gap-1.5 flex-shrink-0">
      <button onClick={() => onRun(pkg.name)} className="btn-primary !py-1 !px-2 !text-[8px]">
        {pkg.built ? 'Re-run' : 'Run'}
      </button>
      {pkg.built && (
        <button onClick={() => onForce(pkg.name)} className="btn-success !py-1 !px-2 !text-[8px]">
          Force
        </button>
      )}
    </div>
  </div>
));

function PipelineSidebarInner({
  steps, selectedPhaseIdx, onSelectPhase, onRunPhase, onForcePhase,
  onRunPackage, onForcePackage, packages, packageError, onRefreshPackages
}: PipelineSidebarProps) {
  const completedSteps = steps.filter(s => s.status === 'completed').length;
  const totalProgress = steps.length > 0 ? Math.round((completedSteps / steps.length) * 100) : 0;

  return (
    <section className="w-[28rem] flex flex-col gap-2">
      <div className="glass p-4 rounded-xl flex flex-col h-full overflow-hidden">
        <div className="flex items-center justify-between mb-4 px-1">
          <div className="flex items-center gap-2">
            <h2 className="text-[9px] font-bold text-text-dim uppercase tracking-[0.2em]">Pipeline</h2>
          </div>
          <div className="flex items-center gap-2">
            <div className="text-[9px] font-mono text-accent-cyan">{completedSteps}/{steps.length}</div>
            {totalProgress > 0 && (
              <div className="w-16 h-1 bg-white/5 rounded-full overflow-hidden">
                <div className="h-full progress-gradient transition-all duration-500" style={{ width: `${totalProgress}%` }} />
              </div>
            )}
          </div>
        </div>

        <div className="mb-4 p-3 rounded-xl border border-white/5 bg-black/20 card-hover">
          <div className="flex items-center justify-between mb-3">
            <div className="min-w-0 flex-1 mr-2">
              <div className="text-[8px] text-text-dim uppercase font-bold tracking-[0.2em]">Active Module</div>
              <div className="text-sm font-semibold mt-0.5 text-white truncate">
                {steps[selectedPhaseIdx]?.name || 'No module selected'}
              </div>
            </div>
            <div className="flex gap-1.5 flex-shrink-0">
              <button onClick={() => onRunPhase(selectedPhaseIdx)} className="btn-primary !py-1.5 !px-2.5">
                Run Phase
              </button>
              <button onClick={() => onForcePhase(selectedPhaseIdx)} className="btn-success !py-1.5 !px-2.5">
                Force
              </button>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto space-y-1.5 pr-1">
          {steps.map((step, idx) => (
            <StepButton
              key={step.id}
              step={step} idx={idx}
              selected={selectedPhaseIdx === idx}
              onSelect={onSelectPhase}
              onRun={onRunPhase}
              onForce={onForcePhase}
            />
          ))}
        </div>

        <div className="mt-4 p-3 rounded-xl border border-white/5 bg-black/20">
          <div className="flex items-center justify-between mb-3">
            <div>
              <div className="text-[8px] text-text-dim uppercase font-bold tracking-[0.2em]">Packages</div>
              <div className="text-[10px] text-white mt-0.5 font-mono">{packages.length} pkg{packages.length === 1 ? '' : 's'}</div>
            </div>
            <button onClick={onRefreshPackages} className="btn-ghost !py-1 !px-2 !text-[8px] border border-white/10 text-text-dim hover:text-white">
              Refresh
            </button>
          </div>
          {packageError && (
            <div className="mb-3 rounded-lg bg-accent-red/10 border border-accent-red/20 px-3 py-2 text-[9px] text-accent-red">
              {packageError}
            </div>
          )}
          <div className="space-y-1.5 max-h-72 overflow-y-auto pr-1">
            {packages.length > 0 ? packages.map(pkg => (
              <PackageCard key={pkg.name} pkg={pkg} onRun={onRunPackage} onForce={onForcePackage} />
            )) : (
              <div className="text-[9px] text-text-dim">No packages for this phase.</div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

export const PipelineSidebar = memo(PipelineSidebarInner);
