import { motion, AnimatePresence } from 'motion/react';
import { X, CheckCircle2 } from 'lucide-react';
import { useState } from 'react';

interface ContributionConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  tier: string | null;
  onConfirm: () => void;
}

export function ContributionConfirmModal({ isOpen, onClose, tier, onConfirm }: ContributionConfirmModalProps) {
  const [isConfirming, setIsConfirming] = useState(false);

  const handleConfirm = () => {
    setIsConfirming(true);
    // Simulate API call and confirmation
    setTimeout(() => {
      setIsConfirming(false);
      onConfirm();
    }, 1500);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-50"
          />

          {/* Modal */}
          <motion.div 
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-surface2 border border-border rounded-3xl z-50 p-6 lg:p-8 w-[90%] max-w-md shadow-2xl"
          >
            <button 
              onClick={onClose}
              className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full bg-surface3 text-muted hover:text-text transition-colors"
            >
              <X size={18} />
            </button>

            <div className="text-center mb-6">
              <div className="w-16 h-16 rounded-full bg-secondary/10 border border-secondary/30 flex items-center justify-center text-secondary mx-auto mb-4">
                <CheckCircle2 size={32} />
              </div>
              <h3 className="font-display text-2xl text-text tracking-widest mb-2">CONFIRM CONTRIBUTION</h3>
              <p className="text-sm text-muted">
                Did you complete the MoMo USSD payment for the <span className="font-bold text-text">{tier}</span> tier?
              </p>
            </div>

            <div className="bg-surface3 border border-border rounded-xl p-4 mb-6">
              <div className="flex justify-between items-center mb-2">
                <span className="text-xs text-muted">Selected Tier</span>
                <span className="font-bold text-text">{tier}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-xs text-muted">Status</span>
                <span className="text-[10px] font-bold text-secondary uppercase tracking-widest bg-secondary/10 px-2 py-1 rounded-full">Pending Verification</span>
              </div>
            </div>

            <div className="flex gap-3">
              <button 
                onClick={onClose}
                className="flex-1 bg-surface3 hover:bg-surface3/80 text-text font-bold py-3 rounded-xl transition-all text-sm"
              >
                Not Yet
              </button>
              <button 
                onClick={handleConfirm}
                disabled={isConfirming}
                className="flex-1 bg-secondary hover:bg-secondary/90 disabled:opacity-50 text-bg font-bold py-3 rounded-xl transition-all text-sm flex justify-center items-center"
              >
                {isConfirming ? 'Confirming...' : 'Yes, I Paid'}
              </button>
            </div>
            
            <p className="text-[9px] text-muted text-center mt-4 uppercase tracking-widest">
              Contributions are verified anonymously via Fan ID.
            </p>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
