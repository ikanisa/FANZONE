import { motion, AnimatePresence } from "motion/react";
import { X, Download, Twitter, MessageCircle } from "lucide-react";
import { DigitalMembershipCard } from "./DigitalMembershipCard";

interface ShareCardModalProps {
  isOpen: boolean;
  onClose: () => void;
  fanId: string;
}

export function ShareCardModal({
  isOpen,
  onClose,
  fanId,
}: ShareCardModalProps) {
  const handleShare = (platform: string) => {
    alert(`Sharing to ${platform} is not fully implemented yet in this demo.`);
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

            <div className="mb-8">
              <DigitalMembershipCard
                clubName="Favorite Team"
                tier="Ultra"
                fanId={fanId}
                crest="🦅"
                color="#ffd32a"
                memberSince="OCT 2023"
              />
            </div>

            <div className="bg-surface2 border border-border rounded-3xl p-6">
              <h3 className="font-display text-xl text-text tracking-widest mb-4 text-center">
                SHARE YOUR FANDOM
              </h3>

              <div className="grid grid-cols-3 gap-3">
                <button
                  onClick={() => handleShare("WhatsApp")}
                  className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-[#25D366]/10 border border-[#25D366]/20 text-[#25D366] hover:bg-[#25D366]/20 transition-colors"
                >
                  <MessageCircle size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">
                    WhatsApp
                  </span>
                </button>
                <button
                  onClick={() => handleShare("X (Twitter)")}
                  className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-white/5 border border-white/10 text-text hover:bg-white/10 transition-colors"
                >
                  <Twitter size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">
                    X (Twitter)
                  </span>
                </button>
                <button
                  onClick={() => handleShare("Save Image")}
                  className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-accent/10 border border-accent/20 text-accent hover:bg-accent/20 transition-colors"
                >
                  <Download size={24} />
                  <span className="text-[10px] font-bold uppercase tracking-widest">
                    Save Image
                  </span>
                </button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
