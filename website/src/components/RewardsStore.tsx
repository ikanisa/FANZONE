import React from 'react';
import { motion } from 'motion/react';
import { Gift, Smartphone, Star, Zap } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { triggerConfetti } from '../lib/confetti';
import { AnimatedCounter } from './ui/AnimatedCounter';

export default function RewardsStore() {
  const { fetBalance } = useAppStore();

  return (
    <div className="min-h-screen bg-bg p-6 lg:p-12 pb-24">
      <header className="mb-8">
        <h1 className="font-display text-3xl text-text tracking-widest mb-2">REWARDS STORE</h1>
        <p className="text-muted text-sm">Redeem your FET for exclusive rewards</p>
      </header>

      {/* Balance */}
      <div className="bg-surface2 p-6 rounded-2xl border border-border flex items-center justify-between mb-8">
        <div className="text-sm font-bold text-muted">Your Balance</div>
        <div className="font-mono text-2xl font-bold text-accent3">
          <AnimatedCounter value={fetBalance} /> FET
        </div>
      </div>

      {/* Rewards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <RewardItem icon={<Smartphone />} title="Mobile Airtime" cost={500} category="Utility" />
        <RewardItem icon={<Star />} title="Premium Badge" cost={200} category="Cosmetic" />
        <RewardItem icon={<Zap />} title="Jackpot Entry" cost={100} category="Gameplay" />
        <RewardItem icon={<Gift />} title="Partner Voucher" cost={1000} category="Utility" />
      </div>
    </div>
  );
}

function RewardItem({ icon, title, cost, category }: { icon: React.ReactNode; title: string; cost: number; category: string }) {
  const { fetBalance, deductFet } = useAppStore();
  const canAfford = fetBalance >= cost;

  const handleRedeem = () => {
    if (canAfford) {
      deductFet(cost);
      triggerConfetti();
    }
  };

  return (
    <div className="bg-surface2 p-6 rounded-2xl border border-border flex flex-col gap-4">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-surface3 flex items-center justify-center text-accent">
          {icon}
        </div>
        <div>
          <div className="text-sm font-bold text-text">{title}</div>
          <div className="text-[10px] text-muted uppercase tracking-widest">{category}</div>
        </div>
      </div>
      <button 
        onClick={handleRedeem}
        disabled={!canAfford}
        className={`w-full font-bold py-3 rounded-xl transition-all border ${
          canAfford 
            ? 'bg-surface3 hover:bg-accent/20 border-border text-accent' 
            : 'bg-surface3/50 border-border/50 text-muted cursor-not-allowed'
        }`}
      >
        Redeem {cost} FET
      </button>
    </div>
  );
}
