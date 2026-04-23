import { motion, AnimatePresence } from 'motion/react';
import { CheckCircle2, Goal, Target, X } from 'lucide-react';

interface PredictionOptionsSheetProps {
  isOpen: boolean;
  onClose: () => void;
  homeTeam: string;
  awayTeam: string;
  selectedHomeGoals: number | null;
  selectedAwayGoals: number | null;
  suggestedHomeGoals?: number | null;
  suggestedAwayGoals?: number | null;
  onSelectScore: (homeGoals: number, awayGoals: number) => void;
  onClearScore: () => void;
}

function buildQuickScorelines(
  suggestedHomeGoals: number | null | undefined,
  suggestedAwayGoals: number | null | undefined,
) {
  const seedHome = suggestedHomeGoals ?? 1;
  const seedAway = suggestedAwayGoals ?? 1;
  const candidates = [
    [seedHome, seedAway],
    [Math.max(0, seedHome + 1), seedAway],
    [seedHome, Math.max(0, seedAway + 1)],
    [Math.max(0, seedHome - 1), seedAway],
    [seedHome, Math.max(0, seedAway - 1)],
    [1, 1],
  ];

  return [...new Map(candidates.map(([home, away]) => [`${home}-${away}`, { home, away }])).values()];
}

export default function PredictionOptionsSheet({
  isOpen,
  onClose,
  homeTeam,
  awayTeam,
  selectedHomeGoals,
  selectedAwayGoals,
  suggestedHomeGoals,
  suggestedAwayGoals,
  onSelectScore,
  onClearScore,
}: PredictionOptionsSheetProps) {
  const quickScorelines = buildQuickScorelines(suggestedHomeGoals, suggestedAwayGoals);

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-40"
          />
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            className="fixed bottom-0 left-0 right-0 h-[75vh] bg-surface rounded-t-3xl border-t border-border z-50 p-6 flex flex-col"
          >
            <div className="flex justify-between items-center mb-6">
              <h3 className="font-display text-2xl text-text tracking-widest">
                EXACT SCORE
              </h3>
              <button
                onClick={onClose}
                className="text-muted hover:text-text"
              >
                <X size={24} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto space-y-5">
              <section className="bg-surface2 p-4 rounded-2xl border border-border">
                <div className="flex items-center gap-2 mb-3 text-accent">
                  <Target size={16} />
                  <span className="text-xs font-bold uppercase tracking-widest">
                    Quick Scorelines
                  </span>
                </div>
                <div className="grid grid-cols-3 gap-2">
                  {quickScorelines.map((option) => {
                    const isSelected =
                      selectedHomeGoals === option.home &&
                      selectedAwayGoals === option.away;
                    return (
                      <button
                        key={`${option.home}-${option.away}`}
                        onClick={() => onSelectScore(option.home, option.away)}
                        className={`rounded-xl border px-4 py-3 text-sm font-bold transition-all ${
                          isSelected
                            ? 'border-accent bg-accent/10 text-accent'
                            : 'bg-surface3 hover:bg-accent/10 border-border text-text'
                        }`}
                      >
                        {option.home} - {option.away}
                      </button>
                    );
                  })}
                </div>
              </section>

              <section className="bg-surface2 p-4 rounded-2xl border border-border">
                <div className="flex items-center gap-2 mb-3 text-accent">
                  <Goal size={16} />
                  <span className="text-xs font-bold uppercase tracking-widest">
                    Build Scoreline
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <ScoreStepper
                    label={homeTeam}
                    value={selectedHomeGoals ?? suggestedHomeGoals ?? 0}
                    onDecrease={() =>
                      onSelectScore(
                        Math.max(0, (selectedHomeGoals ?? suggestedHomeGoals ?? 0) - 1),
                        selectedAwayGoals ?? suggestedAwayGoals ?? 0,
                      )
                    }
                    onIncrease={() =>
                      onSelectScore(
                        (selectedHomeGoals ?? suggestedHomeGoals ?? 0) + 1,
                        selectedAwayGoals ?? suggestedAwayGoals ?? 0,
                      )
                    }
                  />
                  <ScoreStepper
                    label={awayTeam}
                    value={selectedAwayGoals ?? suggestedAwayGoals ?? 0}
                    onDecrease={() =>
                      onSelectScore(
                        selectedHomeGoals ?? suggestedHomeGoals ?? 0,
                        Math.max(0, (selectedAwayGoals ?? suggestedAwayGoals ?? 0) - 1),
                      )
                    }
                    onIncrease={() =>
                      onSelectScore(
                        selectedHomeGoals ?? suggestedHomeGoals ?? 0,
                        (selectedAwayGoals ?? suggestedAwayGoals ?? 0) + 1,
                      )
                    }
                  />
                </div>
                <button
                  onClick={onClearScore}
                  className="mt-3 w-full rounded-xl border border-border bg-surface3 py-3 text-sm font-bold text-muted hover:text-text transition-colors"
                >
                  Clear Exact Score
                </button>
              </section>
            </div>

            <button
              onClick={onClose}
              className="w-full bg-accent hover:bg-accent/90 text-bg font-bold py-4 rounded-xl transition-all mt-4 flex items-center justify-center gap-2"
            >
              <CheckCircle2 size={18} />
              APPLY SCORE PICK
            </button>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function ScoreStepper({
  label,
  value,
  onDecrease,
  onIncrease,
}: {
  label: string;
  value: number;
  onDecrease: () => void;
  onIncrease: () => void;
}) {
  return (
    <div className="rounded-2xl border border-border bg-surface3 p-4 text-center">
      <div className="text-[10px] font-bold uppercase tracking-widest text-muted mb-3 truncate">
        {label}
      </div>
      <div className="flex items-center justify-between gap-2">
        <button
          onClick={onDecrease}
          className="h-10 w-10 rounded-xl border border-border bg-surface2 text-lg font-bold text-text hover:border-accent transition-colors"
        >
          -
        </button>
        <span className="font-mono text-3xl font-bold text-text w-10 text-center">
          {value}
        </span>
        <button
          onClick={onIncrease}
          className="h-10 w-10 rounded-xl border border-border bg-surface2 text-lg font-bold text-text hover:border-accent transition-colors"
        >
          +
        </button>
      </div>
    </div>
  );
}
