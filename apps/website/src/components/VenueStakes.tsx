import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, Ticket, Users, CheckCircle2 } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { api } from '../services/api';
import { Card } from './ui/Card';
import { Badge } from './ui/Badge';
import { FETDisplay } from './ui/FETDisplay';
import { VenueMatchStake, Match, UserPrediction } from '../types';

interface VenueStakesProps {
  match: Match;
  userPrediction?: UserPrediction | null;
  venueId: string;
  venueName: string;
}

export const VenueStakes: React.FC<VenueStakesProps> = ({ match, userPrediction, venueId, venueName }) => {
  const { fetBalance, deductFet, addNotification } = useAppStore();
  const [stake, setStake] = useState<VenueMatchStake | null>(null);
  const [loading, setLoading] = useState(true);
  const [isJoined, setIsJoined] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    const loadStake = async () => {
      try {
        setLoading(true);
        const activeStake = await api.fetchActiveStake(venueId, match.id);
        setStake(activeStake);
      } catch (err) {
        console.error('Failed to load stake:', err);
      } finally {
        setLoading(false);
      }
    };

    loadStake();
  }, [venueId, match.id]);

  const handleJoin = async () => {
    if (!stake) return;
    if (!userPrediction) {
      alert('Please make a prediction first!');
      return;
    }

    if (fetBalance < stake.entryFeeFet) {
      alert('Insufficient token balance.');
      return;
    }

    setIsSubmitting(true);
    try {
      await api.joinStake(stake.id);
      
      deductFet(stake.entryFeeFet);
      setIsJoined(true);

      addNotification({
        type: 'system',
        title: 'Joined Match Pool',
        message: `You successfully joined the ${venueName} pool for ${match.homeTeam} vs ${match.awayTeam}.`
      });
    } catch (err) {
      console.error('Failed to join stake:', err);
      alert('Failed to join the pool. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) return (
    <Card className="p-6 bg-surface2 border-border animate-pulse">
      <div className="h-24 bg-surface3 rounded-xl" />
    </Card>
  );

  if (!stake) return null;

  return (
    <Card className="p-6 bg-surface2 border-border overflow-hidden relative">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2 text-accent2">
          <Sparkles size={18} />
          <span className="text-xs font-black uppercase tracking-widest">Venue Pool</span>
        </div>
        <Badge variant="success">{stake.totalPoolFet} FET POOL</Badge>
      </div>

      <h3 className="text-xl font-black text-text mb-1">Join the {venueName} Pool</h3>
      <p className="text-sm text-textSecondary mb-6">
        Correct picks share the entire pool to spend on orders here.
      </p>

      {isJoined ? (
        <div className="flex items-center gap-3 p-4 bg-success/10 text-success rounded-2xl border border-success/20">
          <CheckCircle2 size={20} />
          <span className="font-bold">You're in the pool!</span>
        </div>
      ) : (
        <button
          disabled={isSubmitting || !userPrediction}
          onClick={handleJoin}
          className="w-full h-14 bg-accent2 text-darkBg font-black rounded-2xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all disabled:opacity-50"
        >
          {isSubmitting ? (
            <div className="w-5 h-5 border-2 border-darkBg/30 border-t-darkBg rounded-full animate-spin" />
          ) : (
            <>
              <Ticket size={20} />
              JOIN FOR {stake.entryFeeFet} FET
            </>
          )}
        </button>
      )}

      {!userPrediction && !isJoined && (
        <p className="mt-3 text-center text-xs text-warning font-bold uppercase tracking-tight">
          Make a prediction to unlock this pool
        </p>
      )}
    </Card>
  );
};
