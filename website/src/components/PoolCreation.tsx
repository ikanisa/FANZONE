import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { ChevronLeft, Calendar, User, Zap } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { mockMatches } from '../lib/mockData';
import { useScrollDirection } from '../hooks/useScrollDirection';

import { TeamLogo } from './ui/TeamLogo';
import { FETDisplay } from './ui/FETDisplay';

export default function PoolCreation() {
  const navigate = useNavigate();
  const { createPool, fetBalance } = useAppStore();
  const scrollDirection = useScrollDirection();
  
  const upcomingMatches = mockMatches.filter(m => m.status === 'upcoming');
  const [step, setStep] = useState(1);
  const [selectedMatch, setSelectedMatch] = useState<string | null>(null);
  const [homeScore, setHomeScore] = useState(0);
  const [awayScore, setAwayScore] = useState(0);
  const [stake, setStake] = useState(100);

  const match = upcomingMatches.find(m => m.id === selectedMatch);
  const isAffordable = fetBalance >= stake;

  const handleCreate = () => {
    if (!match || !isAffordable) return;
    
    const poolId = Math.random().toString(36).substring(7);
    
    createPool({
      id: poolId,
      matchId: match.id,
      matchName: `${match.homeTeam} vs ${match.awayTeam}`,
      creatorId: 'me',
      creatorName: 'You',
      creatorPrediction: `${match.homeTeam} ${homeScore}:${awayScore} ${match.awayTeam}`,
      stake,
      totalPool: stake,
      participantsCount: 1,
      status: 'open',
      lockAt: match.startTime
    }, {
      id: Math.random().toString(36).substring(7),
      poolId,
      userId: 'me',
      userName: 'You',
      predictedHomeScore: homeScore,
      predictedAwayScore: awayScore,
      stake,
      status: 'active',
      payout: 0
    });

    navigate(`/pool/${poolId}`);
  };

  return (
    <div className="min-h-screen bg-bg transition-colors duration-300">
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <button onClick={() => navigate(-1)} className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </button>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Create</div>
          <div className="text-sm font-bold text-text">New Pool</div>
        </div>
        <div className="w-6" />
      </header>

      <div className="p-6 pb-32">
        {step === 1 && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
            <h2 className="font-display text-2xl tracking-widest mb-6 border-b border-border pb-4">Select a Match</h2>
            <div className="space-y-3">
              {upcomingMatches.map(m => (
                <button 
                  key={m.id}
                  onClick={() => { setSelectedMatch(m.id); setStep(2); }}
                  className="w-full bg-surface2 border border-border p-4 rounded-2xl flex items-center justify-between hover:border-accent/50 transition-colors group"
                >
                  <div className="flex items-center gap-4">
                     <div className="flex items-center">
                        <TeamLogo teamName={m.homeTeam} size={24} className="w-8 h-8 rounded-full border border-border bg-surface -mr-2 relative z-10 p-1" />
                        <TeamLogo teamName={m.awayTeam} size={24} className="w-8 h-8 rounded-full border border-border bg-surface p-1" />
                     </div>
                     <div className="text-left">
                       <div className="font-bold text-sm text-text">{m.homeTeam} <span className="text-muted font-normal text-xs mx-1">vs</span> {m.awayTeam}</div>
                       <div className="text-[10px] text-muted flex items-center gap-1 mt-1 font-bold uppercase tracking-widest"><Calendar size={10}/> {m.time}</div>
                     </div>
                  </div>
                  <ChevronLeft size={18} className="text-muted rotate-180 group-hover:text-accent transition-colors" />
                </button>
              ))}
            </div>
          </motion.div>
        )}

        {step === 2 && match && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
            <h2 className="font-display text-2xl tracking-widest mb-6 text-center">Predict Score</h2>
            
            <div className="flex justify-center items-center gap-6 mb-12">
              <div className="text-center flex flex-col items-center">
                <div className="w-16 h-16 rounded-full overflow-hidden bg-surface3 flex items-center justify-center border border-border mb-3 shadow-inner">
                   <TeamLogo teamName={match.homeTeam} size={64} className="w-full h-full object-contain p-2" />
                </div>
                <div className="text-xs font-bold text-text mb-4 truncate w-20">{match.homeTeam}</div>
                <div className="flex flex-col items-center gap-2">
                  <button onClick={() => setHomeScore(s => s + 1)} className="w-14 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3 font-mono font-bold text-xl">+</button>
                  <div className="font-display text-5xl text-text tracking-tighter w-14 text-center">{homeScore}</div>
                  <button onClick={() => setHomeScore(s => Math.max(0, s - 1))} className="w-14 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3 font-mono font-bold text-xl">-</button>
                </div>
              </div>
              <div className="font-display text-3xl text-muted/30 pb-16">:</div>
              <div className="text-center flex flex-col items-center">
                <div className="w-16 h-16 rounded-full overflow-hidden bg-surface3 flex items-center justify-center border border-border mb-3 shadow-inner">
                   <TeamLogo teamName={match.awayTeam} size={64} className="w-full h-full object-contain p-2" />
                </div>
                <div className="text-xs font-bold text-text mb-4 truncate w-20">{match.awayTeam}</div>
                <div className="flex flex-col items-center gap-2">
                  <button onClick={() => setAwayScore(s => s + 1)} className="w-14 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3 font-mono font-bold text-xl">+</button>
                  <div className="font-display text-5xl text-text tracking-tighter w-14 text-center">{awayScore}</div>
                  <button onClick={() => setAwayScore(s => Math.max(0, s - 1))} className="w-14 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3 font-mono font-bold text-xl">-</button>
                </div>
              </div>
            </div>

            <button 
              onClick={() => setStep(3)}
              className="w-full bg-accent text-surface font-bold text-lg py-4 rounded-xl shadow-sm"
            >
              Continue to Stake
            </button>
          </motion.div>
        )}

        {step === 3 && match && (
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
            <h2 className="font-display text-2xl tracking-widest mb-6 border-b border-border pb-4">Set Your Stake</h2>
            
            <div className="bg-surface2 border border-border p-6 rounded-3xl mb-8">
              <div className="text-center mb-6">
                <div className="text-[10px] font-bold text-muted uppercase tracking-widest mb-1">STAKE AMOUNT</div>
                <div className="font-mono text-4xl text-accent3 font-bold">
                   <FETDisplay amount={stake} showFiat={true} />
                </div>
              </div>
              
              <input 
                type="range" 
                min="50" max="5000" step="50"
                value={stake}
                onChange={(e) => setStake(Number(e.target.value))}
                className="w-full accent-accent3 bg-surface3 rounded-lg appearance-none h-2 cursor-pointer mb-6"
              />

              <div className="flex justify-between items-center text-xs">
                <span className="text-muted font-bold">Min: 50</span>
                <span className="text-muted font-bold">Max: 5000</span>
              </div>
            </div>

            <div className="bg-surface p-4 rounded-2xl border border-border flex justify-between items-center mb-8">
              <span className="text-sm text-text font-bold">Your Balance</span>
              <span className={`font-mono font-bold ${isAffordable ? 'text-accent' : 'text-accent2'}`}>
                 <FETDisplay amount={fetBalance} showFiat={false} />
              </span>
            </div>

            <button 
              onClick={handleCreate}
              disabled={!isAffordable}
              className={`w-full font-bold text-lg py-4 rounded-xl transition-all ${
                isAffordable 
                  ? 'bg-accent text-surface shadow-sm hover:scale-[1.02]' 
                  : 'bg-surface3 text-muted cursor-not-allowed'
              }`}
            >
              {isAffordable ? 'CREATE CHALLENGE' : 'INSUFFICIENT FUNDS'}
            </button>
          </motion.div>
        )}
      </div>
    </div>
  );
}
