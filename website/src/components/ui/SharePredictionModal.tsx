import { motion, AnimatePresence } from 'motion/react';
import { X, Download, Twitter, MessageCircle } from 'lucide-react';

interface SharePredictionModalProps {
  isOpen: boolean;
  onClose: () => void;
  matchName: string;
  prediction: string;
  earn: number;
}

export function SharePredictionModal({ isOpen, onClose, matchName, prediction, earn }: SharePredictionModalProps) {
  const handleShare = async (platform: string) => {
    try {
      if (navigator.share && platform !== 'Save Image') {
        await navigator.share({
          title: 'Fanzone Prediction',
          text: `Here is my prediction for ${matchName}: ${prediction}. I stand to win +${earn} FET!`,
          url: window.location.href,
        });
      } else {
        alert(`${platform} sharing is not fully implemented yet in this demo.`);
      }
    } catch (err) {
      console.log('Share canceled or failed', err);
    }
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
            onClick={onClose}
            className="fixed inset-0 bg-bg/90 backdrop-blur-md z-50"
          />

          {/* Modal */}
          <motion.div 
            initial={{ scale: 0.9, opacity: 0, y: 20 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            exit={{ scale: 0.9, opacity: 0, y: 20 }}
            className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full max-w-md z-50 p-6"
          >
            <button 
              onClick={onClose}
              className="absolute -top-12 right-0 w-10 h-10 flex items-center justify-center rounded-full bg-surface3 text-text hover:bg-surface2 transition-colors"
            >
              <X size={20} />
            </button>

            <div className="mb-8 bg-gradient-to-br from-surface2 to-surface3 border border-border rounded-3xl p-6 text-center shadow-2xl relative overflow-hidden">
              <div className="absolute top-0 left-0 right-0 h-1 bg-accent"></div>
              <div className="text-accent text-4xl mb-4">🎯</div>
              <h4 className="font-bold text-text text-xl mb-2">{matchName}</h4>
              <p className="text-muted text-sm mb-4">I predict: <span className="text-text font-bold">{prediction}</span></p>
              <div className="inline-block bg-surface border border-border rounded-full px-4 py-2">
                <span className="text-xs text-muted uppercase tracking-widest mr-2">Potential Win</span>
                <span className="font-mono font-bold text-accent3">+{earn} FET</span>
              </div>
            </div>

            <div className="bg-surface2 border border-border rounded-3xl p-6">
              <h3 className="font-display text-xl text-text tracking-widest mb-4 text-center">SHARE PREDICTION</h3>
              
              <div className="grid grid-cols-3 gap-3">
                <button onClick={() => handleShare('WhatsApp')} className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-[#25D366]/10 border border-[#25D366]/20 text-[#25D366] hover:bg-[#25D366]/20 transition-colors">
                  <MessageCircle size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">WhatsApp</span>
                </button>
                <button onClick={() => handleShare('X (Twitter)')} className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-white/5 border border-white/10 text-text hover:bg-white/10 transition-colors">
                  <Twitter size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">X (Twitter)</span>
                </button>
                <button onClick={() => handleShare('Save Image')} className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-accent/10 border border-accent/20 text-accent hover:bg-accent/20 transition-colors">
                  <Download size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">Save Image</span>
                </button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
