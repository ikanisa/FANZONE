import { motion } from 'motion/react';
import { Trophy, Zap, ChevronRight, Check } from 'lucide-react';
import { Badge } from './ui/Badge';
import { Card } from './ui/Card';

export default function JackpotPool() {
  return (
    <div className="min-h-screen bg-bg p-5 lg:p-12 pb-32">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          Jackpots
        </h1>
      </header>

      {/* Prize Card */}
      <div className="bg-gradient-to-r from-accent4/90 to-accent/90 rounded-[28px] p-6 mb-8 text-black relative overflow-hidden shadow-sm">
        <div className="relative z-10">
           <Badge variant="ghost" className="mb-4 bg-black/10 text-black border-transparent">
             <Trophy size={10} className="mr-1 inline" /> WEEKLY POOL
           </Badge>
          <div className="font-mono text-4xl py-2 font-bold mb-2 leading-none">50,000 FET</div>
          <div className="text-[10px] font-bold bg-black/10 inline-block px-3 py-1.5 rounded-full uppercase tracking-widest flex items-center gap-1.5 w-fit">
            <Zap size={12} /> ENDS: 2d 14h
          </div>
        </div>
        <Trophy className="absolute -bottom-4 -right-10 text-black/10" size={180} />
      </div>

      {/* Matches List */}
      <div className="space-y-3">
        <div className="flex items-center justify-between mb-4 px-1">
          <h3 className="font-sans font-bold text-base text-text">10 Matches</h3>
          <Badge variant="ghost" className="text-muted">0/10 predicted</Badge>
        </div>
        {[1, 2, 3, 4, 5].map((i) => (
          <div key={i} className="bg-surface px-4 py-3 rounded-2xl border border-border flex items-center justify-between hover:bg-surface2 transition-colors cursor-pointer group">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-xs shadow-inner shrink-0">⚽</div>
              <div>
                <div className="text-sm font-bold text-text group-hover:text-accent transition-colors leading-tight">Team A vs Team B</div>
                <div className="text-[10px] font-bold uppercase tracking-widest text-muted mt-1">EPL · 18:00</div>
              </div>
            </div>
            <button className="bg-surface2 border border-border text-muted group-hover:text-accent group-hover:border-accent/40 w-10 h-10 rounded-full flex justify-center items-center font-bold text-xs transition-colors shrink-0 shadow-[0_0_15px_rgba(34,211,238,0.0)] group-hover:shadow-[0_0_15px_rgba(34,211,238,0.1)]">
               <ChevronRight size={18} />
            </button>
          </div>
        ))}
      </div>

      <div className="fixed bottom-[70px] lg:bottom-0 left-0 right-0 p-4 bg-surface/80 backdrop-blur-xl border-t border-border z-40 lg:w-[calc(100%-16rem)] lg:ml-64">
        <button className="w-full bg-[var(--accent2)] hover:opacity-90 text-bg font-bold py-3.5 rounded-full transition-opacity shadow-[0_0_15px_rgba(255,127,80,0.3)] flex items-center justify-center gap-2">
          <Check size={18} /> SUBMIT 500 FET
        </button>
      </div>
    </div>
  );
}
