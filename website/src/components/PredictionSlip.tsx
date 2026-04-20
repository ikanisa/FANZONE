import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Trash2, ChevronUp, ChevronDown, Loader2 } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { triggerConfetti } from '../lib/confetti';
import { SharePredictionModal } from './ui/SharePredictionModal';
import { FETDisplay } from './ui/FETDisplay';

export default function PredictionSlip() {
  const { slip, isSlipOpen, toggleSlip, removePrediction, clearSlip, addFet } = useAppStore();
  const [showShareModal, setShowShareModal] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [lastPrediction, setLastPrediction] = useState<{ matchName: string; prediction: string; earn: number } | null>(null);

  if (slip.length === 0 && !showShareModal) return null;

  const totalEarn = slip.reduce((acc, curr) => acc + curr.potentialEarn, 0);

  const handleSubmit = () => {
    setIsSubmitting(true);
    
    // Save the last prediction details for the share card
    if (slip.length > 0) {
      setLastPrediction({
        matchName: slip[0].matchName,
        prediction: `${slip[0].selection} (${slip[0].market})`,
        earn: totalEarn
      });
    }

    // Simulate API call and success
    setTimeout(() => {
      setIsSubmitting(false);
      triggerConfetti();
      clearSlip();
      setShowShareModal(true);
    }, 1200);
  };

  return (
    <>
      <motion.div 
        initial={{ y: 100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        className={`fixed bottom-20 lg:bottom-6 right-4 lg:right-6 w-[calc(100vw-32px)] lg:w-80 bg-surface2 border border-border rounded-3xl shadow-2xl z-40 overflow-hidden ${slip.length === 0 ? 'hidden' : ''}`}
      >
        {/* Header / Toggle */}
        <div 
          className="bg-surface3 p-4 flex justify-between items-center cursor-pointer"
          onClick={toggleSlip}
        >
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-full bg-accent text-bg flex items-center justify-center text-xs font-bold">
              {slip.length}
            </div>
            <h3 className="font-display text-lg text-text tracking-widest">PREDICTION SLIP</h3>
          </div>
          {isSlipOpen ? <ChevronDown size={20} className="text-muted" /> : <ChevronUp size={20} className="text-muted" />}
        </div>

        {/* Expanded Content */}
        <AnimatePresence>
          {isSlipOpen && (
            <motion.div 
              initial={{ height: 0 }}
              animate={{ height: 'auto' }}
              exit={{ height: 0 }}
              className="px-6 pb-6 pt-4"
            >
              <div className="space-y-3 mb-6 max-h-[40vh] overflow-y-auto pr-2 custom-scrollbar">
                {slip.map((item) => (
                  <div key={item.id} className="flex justify-between items-center bg-surface3 p-3 rounded-xl border border-border">
                    <div>
                      <div className="text-xs font-bold text-text mb-1">{item.matchName}</div>
                      <div className="text-[10px] text-accent">{item.selection} · {item.market}</div>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="font-mono text-xs text-success [text-shadow:0_0_5px_rgba(152,255,152,0.2)]">+{item.potentialEarn}</span>
                      <button 
                        onClick={() => removePrediction(item.id)}
                        className="text-muted hover:text-danger hover:drop-shadow-[0_0_5px_rgba(239,68,68,0.5)] transition-all"
                        disabled={isSubmitting}
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex justify-between items-center mb-6 pt-4 border-t border-border">
                <span className="text-sm text-muted">Total Potential Earn</span>
                <span className="font-mono text-xl font-bold text-success [text-shadow:0_0_10px_rgba(152,255,152,0.3)]">+{totalEarn > 0 ? <FETDisplay amount={totalEarn} showFiat={true} fiatClassName="opacity-60 text-text ml-0 text-[0.6em]" /> : '0 FET'}</span>
              </div>

              <button 
                onClick={handleSubmit}
                disabled={isSubmitting}
                className="w-full bg-gradient-to-r from-accent to-accent2 hover:opacity-90 disabled:opacity-50 text-bg font-bold py-4 rounded-xl transition-all flex justify-center items-center gap-2 shadow-[0_10px_20px_-10px_rgba(34,211,238,0.5)]"
              >
                {isSubmitting ? (
                  <><Loader2 className="animate-spin" size={18} /> PROCESSING...</>
                ) : (
                  'LOCK IN PREDICTIONS'
                )}
              </button>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>

      {lastPrediction && (
        <SharePredictionModal 
          isOpen={showShareModal} 
          onClose={() => setShowShareModal(false)}
          matchName={lastPrediction.matchName}
          prediction={lastPrediction.prediction}
          earn={lastPrediction.earn}
        />
      )}
    </>
  );
}
