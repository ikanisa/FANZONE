import { motion, AnimatePresence } from 'motion/react';
import { X, Check } from 'lucide-react';

interface MembershipTierModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectTier: (tier: string) => void;
}

export function MembershipTierModal({ isOpen, onClose, onSelectTier }: MembershipTierModalProps) {
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
            className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-50"
          />

          {/* Bottom Sheet */}
          <motion.div 
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="fixed bottom-0 left-0 right-0 bg-surface2 border-t border-border rounded-t-3xl z-50 p-6 lg:p-8 max-w-2xl mx-auto max-h-[90vh] overflow-y-auto"
          >
            <div className="flex justify-between items-center mb-6">
              <div>
                <h3 className="font-display text-2xl text-text tracking-widest">MEMBERSHIP TIERS</h3>
                <p className="text-xs text-muted">Select a tier to contribute to your club's FET pool.</p>
              </div>
              <button 
                onClick={onClose}
                className="w-8 h-8 flex items-center justify-center rounded-full bg-surface3 text-muted hover:text-text transition-colors"
              >
                <X size={18} />
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <TierCard 
                name="SUPPORTER" 
                icon="⚽" 
                price="FREE" 
                color="var(--muted)"
                fetShare="0%"
                perks={[
                  "Club profile access",
                  "View club news & fixtures",
                  "Club Fan ID badge on profile",
                  "Counted in club's member total"
                ]}
                onSelect={() => onSelectTier('Supporter')}
              />
              <TierCard 
                name="MEMBER" 
                icon="🏅" 
                price="500 RWF" 
                color="var(--brand-primary)"
                fetShare="10%"
                perks={[
                  "All Supporter benefits",
                  "10% of earned FET shared to club",
                  "Member-only club chat",
                  "Digital membership card"
                ]}
                onSelect={() => onSelectTier('Member')}
              />
              <TierCard 
                name="ULTRA" 
                icon="🔥" 
                price="1,500 RWF" 
                color="var(--brand-secondary)"
                fetShare="20%"
                popular
                perks={[
                  "All Member benefits",
                  "Gold 'Ultra' badge on profile",
                  "20% of earned FET shared to club",
                  "Priority access to Jackpot rounds"
                ]}
                onSelect={() => onSelectTier('Ultra')}
              />
              <TierCard 
                name="LEGEND" 
                icon="👑" 
                price="5,000 RWF" 
                color="var(--brand-secondary)"
                fetShare="35%"
                perks={[
                  "All Ultra benefits",
                  "Animated 'Legend' crown badge",
                  "35% of earned FET shared to club",
                  "Top 10 Legends listed publicly"
                ]}
                onSelect={() => onSelectTier('Legend')}
              />
            </div>
            
            <div className="mt-6 bg-surface3 border border-secondary/20 rounded-xl p-4 flex gap-3 items-start">
              <span className="text-xl">ℹ️</span>
              <div>
                <div className="font-bold text-xs text-secondary mb-1">FET Contribution Pool Logic</div>
                <div className="text-[10px] text-muted leading-relaxed">
                  Each member's prediction FET earn is split: (100% - tier%) goes to personal wallet, tier% goes to the club's collective FET pool. Club's total pooled FET is the ranking currency on the Fan Club Leaderboard.
                </div>
              </div>
            </div>

          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function TierCard({ name, icon, price, color, fetShare, perks, popular, onSelect }: { name: string, icon: string, price: string, color: string, fetShare: string, perks: string[], popular?: boolean, onSelect: () => void }) {
  return (
    <div 
      className={`bg-surface3 border-2 rounded-2xl p-5 relative flex flex-col transition-all hover:scale-[1.02] cursor-pointer`}
      style={{
        borderColor: popular ? 'var(--brand-secondary)' : 'transparent',
        borderTopColor: color,
        borderTopWidth: '4px',
      }}
      onClick={onSelect}
    >
      {popular && (
        <div className="absolute top-3 right-3 bg-secondary text-bg text-[9px] font-bold uppercase tracking-widest px-2 py-1 rounded-full">
          Popular
        </div>
      )}
      
      <div className="text-2xl mb-2">{icon}</div>
      <div className="font-display text-xl tracking-widest mb-1" style={{ color }}>{name}</div>
      <div className="font-mono text-xl font-bold text-text mb-1">{price}</div>
      <div className="text-[9px] text-muted uppercase tracking-widest mb-4">Per month · MoMo USSD</div>
      
      <div className="h-px bg-border mb-4 w-full"></div>
      
      <ul className="space-y-2 mb-6 flex-1">
        {perks.map((perk, i) => (
          <li key={i} className="flex items-start gap-2 text-[10px] text-text">
            <Check size={12} style={{ color }} className="shrink-0 mt-0.5" />
            <span>{perk}</span>
          </li>
        ))}
      </ul>
      
      <div className="bg-surface2 border border-border rounded-lg p-2 flex justify-between items-center mt-auto">
        <span className="text-[9px] font-bold text-muted uppercase tracking-widest">FET to Club</span>
        <span className="font-mono text-sm font-bold text-secondary">{fetShare}</span>
      </div>
    </div>
  );
}
