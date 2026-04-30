import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { CalendarDays, Send, X } from "lucide-react";
import { api } from "../../services/api";
import type { Match } from "../../types";

interface FriendPredictionModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetName: string;
}

export function FriendPredictionModal({
  isOpen,
  onClose,
  targetName,
}: FriendPredictionModalProps) {
  const [selectedMatch, setSelectedMatch] = useState<string | null>(null);
  const [matches, setMatches] = useState<Match[]>([]);

  useEffect(() => {
    if (!isOpen) return;
    let active = true;

    api.getUpcomingMatches(8).then((rows) => {
      if (active) {
        setMatches(rows);
      }
    });

    return () => {
      active = false;
    };
  }, [isOpen]);

  const handleShare = () => {
    onClose();
    setTimeout(() => {
      setSelectedMatch(null);
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

            <div className="flex flex-col gap-6">
              <div className="text-center">
                <h3 className="font-display text-2xl text-text tracking-widest mb-2">
                  SHARE A FIXTURE
                </h3>
                <p className="text-muted text-sm">
                  Pick a match and invite{" "}
                  <span className="font-bold text-text">{targetName}</span> to
                  compare free predictions.
                </p>
              </div>

              <div className="max-h-[40vh] overflow-y-auto space-y-3 pr-2 custom-scrollbar">
                {matches.length > 0 ? (
                  matches.map((match) => (
                    <div
                      key={match.id}
                      onClick={() => setSelectedMatch(match.id)}
                      className={`p-4 rounded-xl border cursor-pointer transition-all ${
                        selectedMatch === match.id
                          ? "border-accent bg-accent/10"
                          : "border-border bg-surface3 hover:border-accent/50"
                      }`}
                    >
                      <div className="flex justify-between items-center text-sm font-bold text-text mb-2">
                        <span>{match.homeTeam}</span>
                        <span className="text-muted font-mono">VS</span>
                        <span>{match.awayTeam}</span>
                      </div>
                      <div className="text-[10px] text-muted tracking-widest uppercase flex items-center gap-1">
                        <CalendarDays size={12} />
                        {match.competitionLabel} · {match.kickoffLabel}
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="rounded-xl border border-border bg-surface3 p-4 text-sm text-muted">
                    No upcoming fixtures are available to share yet.
                  </div>
                )}
              </div>

              <button
                onClick={handleShare}
                disabled={!selectedMatch}
                className="w-full bg-accent hover:bg-accent/90 disabled:opacity-50 text-bg font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2"
              >
                <Send size={16} />
                SEND INVITE
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
