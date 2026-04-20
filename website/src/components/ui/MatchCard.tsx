import { motion } from 'motion/react';
import { useAppStore } from '../../store/useAppStore';
import { Link, useNavigate } from 'react-router-dom';
import { Card } from './Card';
import { Badge } from './Badge';
import { TeamLogo } from './TeamLogo';
import { Swords, PlusCircle, Target } from 'lucide-react';

interface MatchCardProps {
  matchId: string;
  home: string;
  away: string;
  live?: boolean;
  score?: string;
  time: string;
  league?: string;
}

export function MatchCard({ matchId, home, away, live = false, score, time, league = 'EPL' }: MatchCardProps) {
  const matchName = `${home} vs ${away}`;
  const navigate = useNavigate();

  return (
    <Card className={`p-3 hover:border-accent/30 group transition-all relative overflow-hidden ${live ? 'border-danger/30 shadow-[0_0_20px_rgba(239,68,68,0.05)]' : ''}`}>
      {/* Live background glow */}
      {live && <div className="absolute top-0 right-1/2 w-48 h-48 bg-danger/5 rounded-full blur-3xl translate-x-1/2 pointer-events-none" />}

      <div className="flex justify-between items-center mb-3 relative z-10">
        <Badge variant="ghost" className="font-bold tracking-widest text-[9px] py-1">{league} · {time}</Badge>
        {live && <Badge variant="danger" pulse className="px-1.5 py-0.5 text-[9px]">LIVE</Badge>}
      </div>

      <Link to={`/match/${matchId}`} className="block relative z-10">
        <div className="flex justify-between items-center mb-3">
          <div className="flex flex-col items-center gap-1.5 w-[35%]">
            <div className="w-10 h-10 rounded-full overflow-hidden bg-surface2 flex items-center justify-center border border-border group-hover:border-accent/30 transition-colors shadow-inner">
              <TeamLogo teamName={home} size={24} className="w-full h-full object-contain p-1" />
            </div>
            <span className="font-bold text-[10px] text-center leading-tight truncate px-1 w-full">{home}</span>
          </div>
          <div className="w-[30%] flex justify-center">
            <div className={`font-mono text-xl font-bold tracking-tight ${live ? 'text-danger [text-shadow:0_0_15px_rgba(239,68,68,0.2)]' : 'text-text'}`}>
              {live ? score : 'VS'}
            </div>
          </div>
          <div className="flex flex-col items-center gap-1.5 w-[35%]">
            <div className="w-10 h-10 rounded-full overflow-hidden bg-surface2 flex items-center justify-center border border-border group-hover:border-accent/30 transition-colors shadow-inner">
              <TeamLogo teamName={away} size={24} className="w-full h-full object-contain p-1" />
            </div>
            <span className="font-bold text-[10px] text-center leading-tight truncate px-1 w-full">{away}</span>
          </div>
        </div>
      </Link>

      <div className="grid grid-cols-2 gap-2 relative z-10">
         <button 
           onClick={(e) => { e.preventDefault(); navigate(`/match/${matchId}`); }}
           className={`py-2 rounded-lg font-bold text-[10px] uppercase tracking-widest flex items-center justify-center gap-1.5 transition-all ${
             live ? 'bg-danger text-bg hover:opacity-90 shadow-[0_0_15px_rgba(239,68,68,0.3)]' : 'bg-[var(--accent2)]/10 text-[var(--accent2)] hover:bg-[var(--accent2)] hover:text-bg'
           }`}
         >
           <Target size={14} /> PREDICT
         </button>
         <button 
           onClick={(e) => { e.preventDefault(); navigate('/pools/create'); }}
           className="bg-surface border border-accent/20 text-accent hover:bg-accent hover:text-bg py-2 rounded-lg font-bold text-[10px] uppercase tracking-widest flex items-center justify-center gap-1.5 transition-all shadow-sm"
         >
           <Swords size={14} /> POOL
         </button>
      </div>
    </Card>
  );
}
