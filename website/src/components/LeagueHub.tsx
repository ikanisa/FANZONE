import { useParams } from 'react-router-dom';
import { motion } from 'motion/react';
import { ChevronLeft, Trophy, Users, Shield, Plus, Zap, Swords, ChevronRight } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { TeamLogo } from './ui/TeamLogo';
import { MatchCard } from './ui/MatchCard';
import { Badge } from './ui/Badge';
import { Card } from './ui/Card';
import { FETDisplay } from './ui/FETDisplay';

function formatLeagueName(id: string | undefined): string {
  if (!id) return 'Premier League';
  return id.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
}

export default function LeagueHub() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const leagueName = formatLeagueName(id);
  const scrollDirection = useScrollDirection();
  
  // Dummy data contextualized for the league
  const liveMatches = [
    { id: 'm1', home: 'APR FC', away: 'Rayon Sports', score: '2-1', time: "65'", status: 'live' },
    { id: 'm2', home: 'Kiyovu Sports', away: 'Police FC', time: 'Tomorrow, 15:30', status: 'upcoming' },
  ];

  const activePools = [
    { id: 'p1', name: 'Derby Weekend', creator: 'VallettaUltra', stake: 500, pool: 25000, members: 50 },
    { id: 'p2', name: 'Kigali Kings', creator: 'PredictorPro', stake: 1000, pool: 120000, members: 120 },
  ];

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      {/* Header */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <Link to="/fixtures" className="text-text hover:text-primary transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-xs font-bold text-muted uppercase tracking-widest">{id === 'ucl' || id === 'europa' ? 'Europe' : 'League Action'}</div>
          <div className="text-sm font-bold text-text truncate max-w-[200px]">{leagueName}</div>
        </div>
        <div className="w-6" /> {/* Spacer for alignment */}
      </header>

      {/* Hero Action Platform */}
      <div className="bg-surface2 p-6 border-b border-border relative overflow-hidden">
        {/* Glow effect behind hero */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-primary/10 rounded-full blur-3xl translate-x-1/3 -translate-y-1/3 pointer-events-none" />

        <div className="flex items-center gap-4 mb-4 relative z-10">
          <div className="w-16 h-16 bg-surface rounded-full flex items-center justify-center text-3xl shadow-inner border border-border shrink-0">
            {id === 'ucl' ? '⭐' : id === '2026-world-cup' ? '🌎' : '🏆'}
          </div>
          <div>
            <h1 className="font-display text-2xl md:text-3xl text-text tracking-tight mb-1">{leagueName}</h1>
            <div className="flex gap-3 text-[10px] font-bold text-muted uppercase tracking-widest">
              <span className="flex items-center gap-1"><Zap size={12} className="text-primary" /> Live Now</span>
              <span className="flex items-center gap-1"><Users size={12} /> 12 Active Pools</span>
            </div>
          </div>
        </div>

        {/* Global Action Line for League */}
        <div className="flex gap-3 mt-6 relative z-10">
          <button 
            onClick={() => navigate('/pools/create')}
            className="flex-1 bg-secondary text-bg font-bold py-3 rounded-xl flex justify-center items-center gap-2 hover:opacity-90 active:scale-[0.98] transition-all shadow-[0_0_15px_rgba(152,255,152,0.3)] text-xs"
          >
            <Plus size={16} /> NEW POOL
          </button>
          <button 
            onClick={() => navigate('/registry')}
            className="flex-1 bg-surface border border-border text-text font-bold py-3 rounded-xl flex justify-center items-center gap-2 hover:bg-surface3 active:scale-[0.98] transition-all text-xs"
          >
            <Shield size={16} /> CLUBS
          </button>
        </div>
      </div>

      {/* Actionable Content Tabs */}
      <div className="p-4 space-y-8">
        
        {/* 1. Live & Upcoming Features (Predict Driver) */}
        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
               Action Center <Badge variant="danger" pulse>LIVE</Badge>
            </h2>
            <Link to="/fixtures" className="text-xs font-bold text-primary">SEE ALL</Link>
          </div>
          <div className="grid gap-3">
            {liveMatches.map(m => (
               <MatchCard 
                 key={m.id} 
                 matchId={m.id} 
                 home={m.home} 
                 away={m.away} 
                 live={m.status === 'live'} 
                 score={m.status === 'live' ? m.score : undefined} 
                 time={m.time} 
                 league={leagueName} 
               />
            ))}
          </div>
        </section>

        {/* 2. Hot Pools specific to this league */}
        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
              <Swords size={20} className="text-[var(--secondary)]" /> Hot Pools
            </h2>
            <Link to="/pools" className="text-xs font-bold text-primary">BROWSE POOLS</Link>
          </div>
          <div className="grid gap-3">
             {activePools.map(pool => (
               <Card key={pool.id} className="p-0 border-border overflow-hidden">
                 <div className="p-4 flex items-start justify-between">
                   <div>
                     <Badge variant="ghost" className="mb-2">Stake: <FETDisplay amount={pool.stake} showFiat={false} className="ml-1 inline" /></Badge>
                     <h3 className="font-bold text-text text-lg leading-tight mb-1">{pool.name}</h3>
                     <p className="text-xs text-muted mb-3 flex items-center gap-4">
                       <span>By <span className="text-text font-medium">{pool.creator}</span></span>
                       <span className="flex items-center gap-1"><Users size={12}/> {pool.members}</span>
                     </p>
                   </div>
                   <div className="text-right">
                     <span className="text-[10px] font-bold text-muted uppercase block">Total Pool</span>
                     <FETDisplay amount={pool.pool} showFiat={false} className="text-xl text-[var(--secondary)] tracking-tight" />
                   </div>
                 </div>
                 <div className="bg-surface2 px-4 py-3 flex gap-2">
                    <button onClick={() => navigate(`/pool/${pool.id}`)} className="w-full bg-surface border border-border rounded-lg py-2 text-sm font-bold text-text hover:bg-text hover:text-bg transition-colors">
                      VIEW POOL
                    </button>
                    <button onClick={() => navigate(`/pool/${pool.id}`)} className="px-4 bg-[var(--secondary)] text-bg rounded-lg font-bold flex items-center justify-center hover:opacity-90">
                      JOIN
                    </button>
                 </div>
               </Card>
             ))}
          </div>
        </section>

        {/* 3. Fan Clubs for this league */}
        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
              Top Registries
            </h2>
          </div>
          <div className="bg-surface rounded-2xl border border-border overflow-hidden divide-y divide-border/50">
             <div className="p-4 flex items-center justify-between hover:bg-surface2 transition-colors cursor-pointer" onClick={() => navigate('/registry')}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-xl">🛡️</div>
                  <div>
                    <h4 className="font-bold text-text text-sm">{leagueName} Ultras</h4>
                    <span className="text-xs text-muted">14,200 Members</span>
                  </div>
                </div>
                <ChevronRight size={18} className="text-muted" />
             </div>
             <div className="p-4 flex items-center justify-between hover:bg-surface2 transition-colors cursor-pointer" onClick={() => navigate('/registry')}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-xl">🔥</div>
                  <div>
                    <h4 className="font-bold text-text text-sm">Prediction Kings</h4>
                    <span className="text-xs text-muted">8,950 Members</span>
                  </div>
                </div>
                <ChevronRight size={18} className="text-muted" />
             </div>
          </div>
        </section>
      </div>
    </div>
  );
}
