import { motion, AnimatePresence } from 'motion/react';
import { X, Search } from 'lucide-react';
import { useState } from 'react';

interface MarketSelectorProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function MarketSelector({ isOpen, onClose }: MarketSelectorProps) {
  const [activeTab, setActiveTab] = useState('Match');
  const tabs = ['Match', 'Goals', 'Players', 'Corners', 'Cards'];

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
            className="fixed bottom-0 left-0 right-0 h-[80vh] bg-surface rounded-t-3xl border-t border-border z-50 p-6 flex flex-col"
          >
            <div className="flex justify-between items-center mb-6">
              <h3 className="font-display text-2xl text-text tracking-widest">SELECT MARKET</h3>
              <button onClick={onClose} className="text-muted hover:text-text"><X size={24} /></button>
            </div>

            <div className="relative mb-6">
              <Search className="absolute left-3 top-3 text-muted" size={18} />
              <input 
                type="text" 
                placeholder="Search markets..." 
                className="w-full bg-surface2 border border-border rounded-xl py-3 pl-10 pr-4 text-sm text-text focus:outline-none focus:border-primary"
              />
            </div>

            <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
              {tabs.map(tab => (
                <button 
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`px-4 py-2 rounded-full text-xs font-bold whitespace-nowrap transition-all ${activeTab === tab ? 'bg-primary text-bg' : 'bg-surface2 text-muted hover:text-text'}`}
                >
                  {tab}
                </button>
              ))}
            </div>

            <div className="flex-1 overflow-y-auto space-y-4">
              <MarketItem title="Full Time Result (1X2)" odds="1.85" />
              <MarketItem title="Double Chance (1X)" odds="1.25" />
              <MarketItem title="Draw No Bet" odds="2.10" />
              <MarketItem title="Both Teams to Score" odds="1.65" />
            </div>

            <button className="w-full bg-secondary hover:bg-secondary/90 text-bg font-bold py-4 rounded-xl transition-all mt-4">
              ADD 4 PREDICTIONS · EARN 48 FET
            </button>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function MarketItem({ title, odds }: { title: string; odds: string }) {
  return (
    <div className="bg-surface2 p-4 rounded-2xl border border-border flex justify-between items-center">
      <span className="text-sm font-bold text-text">{title}</span>
      <div className="flex gap-2">
        <button className="bg-surface3 hover:bg-primary/20 border border-border rounded-lg px-4 py-2 text-xs font-mono font-bold text-primary transition-all">
          {odds}
        </button>
      </div>
    </div>
  );
}
