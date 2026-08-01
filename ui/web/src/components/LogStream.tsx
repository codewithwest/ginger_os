import { memo, useRef, useEffect } from 'react';

interface LogEntry {
  msg: string;
  style: string;
}

interface LogStreamProps {
  logs: LogEntry[];
  currentPkg: string;
  running: boolean;
}

function getLogStyle(style: string): string {
  let classes = '';
  if (style.includes('green')) classes += ' text-accent-green';
  if (style.includes('cyan')) classes += ' text-accent-cyan';
  if (style.includes('red')) classes += ' text-accent-red';
  if (style.includes('yellow')) classes += ' text-accent-yellow';
  if (style.includes('bold')) classes += ' font-semibold';
  return classes;
}

const LogEntryLine = memo(({ log, index }: { log: LogEntry; index: number }) => (
  <div
    className={`mb-0.5 opacity-90 hover:opacity-100 transition-opacity animate-fade-in-up ${getLogStyle(log.style)}`}
    style={{ animationDelay: `${index * 5}ms` }}
  >
    {log.msg}
  </div>
));

function LogStreamInner({ logs, currentPkg, running }: LogStreamProps) {
  const logEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  const statusText = currentPkg || (running ? 'Processing...' : 'Standby');

  return (
    <section className="flex-1 flex flex-col gap-4 overflow-hidden">
      <div className="glass rounded-xl flex-1 flex flex-col overflow-hidden relative scanline">
        <div className="px-4 py-2.5 border-b border-white/5 bg-white/[0.02] flex justify-between items-center">
          <div className="flex items-center gap-3">
            <div className={`w-1.5 h-1.5 rounded-full transition-all duration-500 ${running ? 'bg-accent-green glow-green' : 'bg-text-dim'}`} />
            <h2 className="text-[9px] font-bold text-text-dim uppercase tracking-[0.2em]">Log Feed</h2>
          </div>
          <div className="text-[9px] font-mono text-accent-cyan bg-accent-cyan/10 px-2.5 py-1 rounded-full border border-accent-cyan/20">
            {statusText}
          </div>
        </div>
        <div className="flex-1 bg-black/30 p-5 overflow-y-auto font-mono text-[13px] leading-relaxed selection:bg-accent-cyan/30">
          {logs.length === 0 && (
            <div className="text-text-dim text-xs animate-fade-in-up">
              {running ? 'Connecting to build stream...' : 'Awaiting build output...'}
            </div>
          )}
          {logs.map((log, i) => (
            <LogEntryLine key={i} log={log} index={i} />
          ))}
          <div ref={logEndRef} />
        </div>
      </div>
    </section>
  );
}

export const LogStream = memo(LogStreamInner);
