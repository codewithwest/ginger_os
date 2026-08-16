import { memo, useState, useCallback } from 'react';

interface ChatMessage {
  msg: string;
  sender: 'ai' | 'user';
}

interface NeuralInterfaceProps {
  chatHistory: ChatMessage[];
  isThinking: boolean;
  onSendChat: (msg: string) => void;
  connected: boolean;
}

function NeuralInterfaceInner({ chatHistory, isThinking, onSendChat, connected }: NeuralInterfaceProps) {
  const [input, setInput] = useState('');

  const handleSend = useCallback(() => {
    if (!input.trim() || !connected) return;
    onSendChat(input);
    setInput('');
  }, [input, connected, onSendChat]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }, [handleSend]);

  return (
    <div className="glass elevation-2 p-5 rounded-2xl flex-1 flex flex-col overflow-hidden">
      <h2 className="text-[9px] font-bold text-text-dim uppercase tracking-[0.2em] mb-4">Neural Chat</h2>
      <div className="flex-1 overflow-y-auto space-y-3 pr-2 mb-4">
        {!connected && (
          <div className="p-3 rounded-lg text-xs leading-relaxed bg-accent-red/10 border border-accent-red/20 text-accent-red animate-fade-in-up">
            <div className="flex items-center gap-2 mb-1">
              <span className="w-1.5 h-1.5 rounded-full bg-accent-red glow-red" />
              <span className="text-[8px] uppercase font-bold tracking-wider">Disconnected</span>
            </div>
            Reconnecting to AI backend...
          </div>
        )}
        {chatHistory.map((chat, i) => (
          <div
            key={i}
            className={`p-3 rounded-lg text-xs leading-relaxed animate-slide-in-right ${
              chat.sender === 'user'
                ? 'bg-accent-cyan/10 border border-accent-cyan/20 ml-4'
                : 'bg-transparent border border-white/10 mr-4'
            }`}
          >
            <div className="flex items-center gap-2 mb-1">
              <span className={`w-1.5 h-1.5 rounded-full ${chat.sender === 'user' ? 'bg-accent-cyan' : 'bg-accent-green'}`} />
              <span className="text-[7px] uppercase font-bold tracking-widest opacity-40">{chat.sender}</span>
            </div>
            {chat.msg}
          </div>
        ))}
        {isThinking && (
          <div className="bg-transparent border border-white/10 p-3 rounded-lg text-[10px] text-text-dim animate-fade-in-up">
            <div className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full bg-accent-green animate-pulse" />
              Processing request...
            </div>
          </div>
        )}
      </div>
      <div className="relative">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={connected ? 'Ask about the build...' : 'Waiting for connection...'}
          disabled={!connected}
          className="input-ghost w-full pr-12 disabled:opacity-50"
        />
        <button
          onClick={handleSend}
          disabled={!connected || !input.trim()}
          className="absolute right-2 top-2 p-1.5 text-accent-cyan hover:text-white transition-all duration-300 hover:scale-110 disabled:opacity-30 disabled:hover:scale-100"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
          </svg>
        </button>
      </div>
    </div>
  );
}

export const NeuralInterface = memo(NeuralInterfaceInner);
