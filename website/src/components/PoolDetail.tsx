import { useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'motion/react';
import { ChevronLeft, Zap, Users, ShieldAlert, Calendar, Swords, ArrowRight } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { FETDisplay } from './ui/FETDisplay';

export default function PoolDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { scorePools, poolEntries, fetBalance, joinPool } = useAppStore();
  const [showJoinSheet, setShowJoinSheet] = useState(false);
  const scrollDirection = useScrollDirection();

  const pool = scorePools.find(c => c.id === id);
  // Just grabbing current user entries if any (in this mock everyone is random, but we will pretend 'me' is not joined yet unless added)
  const isJoined = poolEntries.some(e => e.poolId === id && e.userId === 'me');

  if (!pool) {
    return <div className="p-12 text-center text-text font-display">Pool not found</div>;
  }

  return (
    <div className="min-h-screen bg-bg pb-32 transition-colors duration-300">
      {/* Header */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <button onClick={() => navigate(-1)} className="text-text hover:text-primary transition-all">
          <ChevronLeft size={24} />
        </button>
        <div className="text-center">
          <div className="text-xs font-bold text-muted uppercase tracking-widest">Pool</div>
          <div className="text-sm font-bold text-text shrink-0">{pool.matchName}</div>
        </div>
        <div className="w-6" />
      </header>

      <div className="p-6">
        {/* Status Hero */}
        <div className="bg-surface2 rounded-3xl p-6 border border-border mb-6">
          <div className="flex justify-between items-start mb-6">
            <div className="bg-primary/10 border border-primary/20 px-3 py-1 rounded-full text-primary text-[10px] uppercase tracking-widest font-bold flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-primary animate-pulse" /> {pool.status}
            </div>
            <div className="text-right">
              <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Lock Time</div>
              <div className="text-sm font-mono text-text flex items-center gap-1">
                <Calendar size={12} /> {new Date(pool.lockAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </div>
            </div>
          </div>

          <div className="text-center mb-6">
            <h2 className="font-display text-4xl tracking-tight text-text mb-2">{pool.matchName}</h2>
            <div className="inline-flex items-center gap-2 bg-surface3 border border-border rounded-xl px-4 py-2">
              <span className="text-xs font-bold text-muted">STAKE</span>
              <span className="font-mono text-xl text-secondary font-bold">
                 <FETDisplay amount={pool.stake} showFiat={true} className="whitespace-nowrap inline" fiatClassName="text-muted ml-1 text-sm font-sans tracking-normal font-normal" />
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="bg-surface border border-border rounded-2xl p-4 text-center">
              <Zap size={20} className="mx-auto text-primary mb-2" />
              <div className="text-[10px] font-bold text-muted uppercase tracking-widest mb-1">Total Pool</div>
              <div className="font-mono text-lg text-text font-bold">
                 <FETDisplay amount={pool.totalPool} showFiat={false} className="whitespace-nowrap" />
              </div>
            </div>
            <div className="bg-surface border border-border rounded-2xl p-4 text-center">
              <Users size={20} className="mx-auto text-secondary mb-2" />
              <div className="text-[10px] font-bold text-muted uppercase tracking-widest mb-1">Participants</div>
              <div className="font-mono text-lg text-text font-bold">{pool.participantsCount}</div>
            </div>
          </div>
        </div>

        {/* Creator Info */}
        <div className="bg-surface2 rounded-3xl p-6 border border-border mb-6">
          <h3 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-4 flex items-center gap-2">
            <Swords size={14} /> Created By
          </h3>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-surface3 border border-border flex items-center justify-center font-bold text-text">
                {pool.creatorName.charAt(0)}
              </div>
              <span className="font-bold text-text">{pool.creatorName}</span>
            </div>
            <div className="text-right">
              <div className="text-[10px] text-muted font-bold uppercase tracking-widest mb-1">Prediction</div>
              <div className="font-mono text-sm font-bold text-primary">{pool.creatorPrediction}</div>
            </div>
          </div>
        </div>

        {/* CTA */}
        {pool.status === 'open' && !isJoined && (
          <button 
            onClick={() => setShowJoinSheet(true)}
            className="w-full bg-primary text-surface font-bold text-lg py-4 rounded-full shadow-sm hover:scale-[1.02] transition-transform flex items-center justify-center gap-2 px-2"
          >
            Join for <FETDisplay amount={pool.stake} showFiat={true} className="inline" fiatClassName="opacity-80 ml-1 text-sm font-normal" /> <ArrowRight size={20} className="shrink-0" />
          </button>
        )}
        {isJoined && (
          <div className="w-full bg-surface2 border border-primary/30 text-center py-4 rounded-xl">
            <span className="text-primary font-bold tracking-tight text-sm flex items-center justify-center gap-2">
              <ShieldAlert size={18} /> YOU ARE IN THIS CHALLENGE
            </span>
          </div>
        )}
      </div>

      <JoinSheet 
        isOpen={showJoinSheet} 
        onClose={() => setShowJoinSheet(false)} 
        pool={pool} 
        balance={fetBalance}
        onJoin={(home: number, away: number) => {
          joinPool({
            id: Math.random().toString(36).substring(7),
            poolId: pool.id,
            userId: 'me',
            userName: 'You',
            predictedHomeScore: home,
            predictedAwayScore: away,
            stake: pool.stake,
            status: 'active',
            payout: 0
          });
          setShowJoinSheet(false);
        }}
      />
    </div>
  );
}

function JoinSheet({ isOpen, onClose, pool, balance, onJoin }: any) {
  const [homeScore, setHomeScore] = useState(0);
  const [awayScore, setAwayScore] = useState(0);

  const isAffordable = balance >= pool.stake;

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-bg/90 backdrop-blur-md z-50"
          />
          <motion.div 
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            className="fixed bottom-0 left-0 right-0 bg-surface rounded-t-[2rem] border-t border-border z-50 p-6 pb-safe"
          >
            <div className="w-12 h-1.5 bg-surface3 rounded-full mx-auto mb-8" />
            <h3 className="font-display text-2xl text-text tracking-tight text-center mb-2">Join Pool</h3>
            <p className="text-center text-sm text-muted mb-8">{pool.matchName}</p>

            <div className="flex justify-center items-center gap-8 mb-8">
              <div className="text-center">
                <div className="text-xs font-bold text-muted mb-2 tracking-widest uppercase">Home</div>
                <div className="flex flex-col items-center gap-2">
                  <button onClick={() => setHomeScore(s => s + 1)} className="w-12 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3">+</button>
                  <div className="font-mono text-4xl text-text w-12 text-center">{homeScore}</div>
                  <button onClick={() => setHomeScore(s => Math.max(0, s - 1))} className="w-12 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3">-</button>
                </div>
              </div>
              <div className="font-mono text-2xl text-muted">:</div>
              <div className="text-center">
                <div className="text-xs font-bold text-muted mb-2 tracking-widest uppercase">Away</div>
                <div className="flex flex-col items-center gap-2">
                  <button onClick={() => setAwayScore(s => s + 1)} className="w-12 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3">+</button>
                  <div className="font-mono text-4xl text-text w-12 text-center">{awayScore}</div>
                  <button onClick={() => setAwayScore(s => Math.max(0, s - 1))} className="w-12 h-10 bg-surface2 rounded-xl text-text hover:bg-surface3">-</button>
                </div>
              </div>
            </div>

            <div className="bg-surface2 rounded-xl p-4 mb-6 border border-border flex justify-between items-center">
              <span className="text-xs font-bold text-muted uppercase tracking-widest">Required Stake</span>
              <span className="font-mono text-primary font-bold">
                 <FETDisplay amount={pool.stake} showFiat={true} />
              </span>
            </div>

            <button 
              onClick={() => onJoin(homeScore, awayScore)}
              disabled={!isAffordable}
              className={`w-full font-bold text-sm py-4 rounded-full transition-all ${
                isAffordable 
                  ? 'bg-text text-bg hover:opacity-90' 
                  : 'bg-surface3 text-muted cursor-not-allowed'
              }`}
            >
              {isAffordable ? 'Confirm & Stake' : 'Insufficient Funds'}
            </button>
            {!isAffordable && (
              <p className="text-center text-xs text-secondary mt-3 font-medium">You have {balance} FET</p>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
