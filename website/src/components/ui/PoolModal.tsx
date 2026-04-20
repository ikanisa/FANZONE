import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { X, Swords, Trophy } from 'lucide-react';
import { mockMatches } from '../../lib/mockData';

interface PoolModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetName: string;
}

export function PoolModal({ isOpen, onClose, targetName }: PoolModalProps) {
  const [step, setStep] = useState(1);
  const [selectedMatch, setSelectedMatch] = useState<string | null>(null);
  const [wager, setWager] = useState(100);

  const handleCreate = () => {
    // In a real app, send API request here
    onClose();
    setTimeout(() => {
      setStep(1);
      setSelectedMatch(null);
      setWager(100);
    }, 300);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-50"
          />
          <motion.div 
            initial={{ opacity: 0, y: 10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.95 }}
            className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-surface2 border border-border rounded-3xl z-50 p-6 lg:p-8 w-[90%] max-w-md shadow-2xl"
          >
            <button 
              onClick={onClose}
              className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full bg-surface3 text-muted hover:text-text transition-colors"
            >
              <X size={18} />
            </button>

            {step === 1 && (
              <div className="flex flex-col gap-6">
                <div className="flex items-center justify-center gap-3 text-accent mb-2">
                  <Swords size={32} />
                </div>
                <div className="text-center">
                  <h3 className="font-display text-2xl text-text tracking-widest mb-2">CHALLENGE A FRIEND</h3>
                  <p className="text-muted text-sm">Select a match to pool <span className="font-bold text-text">{targetName}</span>.</p>
                </div>

                <div className="max-h-[40vh] overflow-y-auto space-y-3 pr-2 custom-scrollbar">
                  {mockMatches.filter(m => m.status === 'upcoming').map(match => (
                    <div 
                      key={match.id}
                      onClick={() => setSelectedMatch(match.id)}
                      className={`p-4 rounded-xl border cursor-pointer transition-all ${
                        selectedMatch === match.id 
                          ? 'border-accent bg-accent/10' 
                          : 'border-border bg-surface3 hover:border-accent/50'
                      }`}
                    >
                      <div className="flex justify-between items-center text-sm font-bold text-text mb-2">
                        <span>{match.homeTeam}</span>
                        <span className="text-muted font-mono">VS</span>
                        <span>{match.awayTeam}</span>
                      </div>
                      <div className="text-[10px] text-muted tracking-widest uppercase">{match.league} · {match.time}</div>
                    </div>
                  ))}
                </div>

                <button 
                  onClick={() => setStep(2)}
                  disabled={!selectedMatch}
                  className="w-full bg-accent hover:bg-accent/90 disabled:opacity-50 text-bg font-bold py-4 rounded-xl transition-all"
                >
                  NEXT
                </button>
              </div>
            )}

            {step === 2 && (
              <div className="flex flex-col gap-6">
                <div className="flex items-center justify-center gap-3 text-accent mb-2">
                  <Trophy size={32} />
                </div>
                <div className="text-center">
                  <h3 className="font-display text-2xl text-text tracking-widest mb-2">SET THE STAKES</h3>
                  <p className="text-muted text-sm">How many FET tokens are you willing to risk against <span className="font-bold text-text">{targetName}</span>?</p>
                </div>

                <div className="flex items-center justify-between bg-surface3 border border-border rounded-xl p-4">
                  <button 
                    onClick={() => setWager(Math.max(50, wager - 50))}
                    className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-text hover:text-accent font-mono text-xl transition-colors"
                  >
                    -
                  </button>
                  <div className="font-mono text-3xl font-bold text-text tracking-widest">
                    {wager}
                  </div>
                  <button 
                    onClick={() => setWager(wager + 50)}
                    className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-text hover:text-accent font-mono text-xl transition-colors"
                  >
                    +
                  </button>
                </div>

                <div className="flex gap-2">
                  <button onClick={() => setWager(100)} className="flex-1 py-2 rounded-lg bg-surface3 text-text text-xs hover:bg-surface3/80 font-mono">100</button>
                  <button onClick={() => setWager(500)} className="flex-1 py-2 rounded-lg bg-surface3 text-text text-xs hover:bg-surface3/80 font-mono">500</button>
                  <button onClick={() => setWager(1000)} className="flex-1 py-2 rounded-lg bg-surface3 text-text text-xs hover:bg-surface3/80 font-mono">1000</button>
                </div>

                <div className="flex gap-3 mt-4">
                  <button 
                    onClick={() => setStep(1)}
                    className="flex-1 bg-surface3 hover:bg-surface3/80 border border-border text-text font-bold py-4 rounded-xl transition-all"
                  >
                    BACK
                  </button>
                  <button 
                    onClick={handleCreate}
                    className="flex-1 bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all"
                  >
                    CHALLENGE
                  </button>
                </div>
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
