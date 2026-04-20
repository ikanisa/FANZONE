import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Wallet, ArrowUpRight, ArrowDownLeft, Gift, PieChart, Send, X } from 'lucide-react';
import { AnimatedCounter } from './ui/AnimatedCounter';
import { useAppStore, type WalletTransaction } from '../store/useAppStore';
import { Link } from 'react-router-dom';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { FETDisplay } from './ui/FETDisplay';

export default function WalletHub() {
  const { fetBalance, walletTransactions, transferFET } = useAppStore();
  const [showTransferSheet, setShowTransferSheet] = useState(false);
  const scrollDirection = useScrollDirection();

  return (
    <div className="min-h-screen bg-bg transition-colors duration-300">
      {/* Sticky Header */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border py-4 px-5 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          <Wallet size={24} className="text-accent" /> Wallet
        </h1>
      </header>

      <div className="p-4 lg:p-12 pb-24 space-y-6">
        {/* Balance Card */}
        <div className="bg-gradient-to-br from-[#0F7B6C] to-[#2563EB] rounded-[28px] p-5 text-[#FDFCF0] relative overflow-hidden shadow-[0_10px_30px_-10px_rgba(37,99,235,0.3)]">
          <div className="relative z-10 flex flex-col items-center text-center">
            <div className="text-[10px] font-bold opacity-80 uppercase tracking-widest mb-1 select-none">Total Balance</div>
            <div className="text-5xl lg:text-6xl font-mono font-bold tracking-tight mb-5 [text-shadow:0_0_20px_rgba(253,252,240,0.3)] flex flex-col items-center justify-center h-20">
              <FETDisplay amount={fetBalance} showFiat={true} fiatClassName="opacity-80 text-sm font-sans block mt-1 tracking-normal leading-none" />
            </div>
            <div className="flex gap-2 w-full max-w-[300px]">
              <Link 
                to="/rewards"
                className="bg-[#FDFCF0] text-[#09090b] h-12 rounded-xl font-bold flex flex-col items-center justify-center gap-0.5 flex-1 hover:scale-[1.02] transition-transform shadow-sm"
              >
                <div className="flex items-center gap-1.5"><Gift size={14} className="text-accent" /> <span className="text-[10px] tracking-widest">REDEEM</span></div>
              </Link>
              <button 
                onClick={() => setShowTransferSheet(true)}
                className="bg-white/10 backdrop-blur-md border border-white/20 text-[#FDFCF0] h-12 rounded-xl font-bold flex flex-col items-center justify-center gap-0.5 flex-1 hover:bg-white/20 transition-all hover:scale-[1.02]"
              >
                <div className="flex items-center gap-1.5"><Send size={14} /> <span className="text-[10px] tracking-widest">SEND</span></div>
              </button>
            </div>
          </div>
          <Wallet className="absolute -bottom-6 -right-6 text-white/5 mix-blend-overlay rotate-[-15deg] pointer-events-none" size={200} />
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-2">
          <div className="bg-surface2 p-3 rounded-[20px] border border-border shadow-sm flex items-center justify-between">
            <div className="flex-1">
              <div className="text-muted text-[9px] uppercase tracking-widest font-bold mb-0.5 opacity-80">Earned</div>
              <div className="font-mono text-base font-bold text-success leading-none [text-shadow:0_0_8px_rgba(152,255,152,0.1)]">+1.2k</div>
            </div>
            <div className="w-8 h-8 rounded-full bg-success/10 text-success flex items-center justify-center shrink-0 border border-success/20"><ArrowUpRight size={14} /></div>
          </div>
          <div className="bg-surface2 p-3 rounded-[20px] border border-border shadow-sm flex items-center justify-between">
            <div className="flex-1">
              <div className="text-muted text-[9px] uppercase tracking-widest font-bold mb-0.5 opacity-80">Spent</div>
              <div className="font-mono text-base font-bold text-accent3 leading-none [text-shadow:0_0_8px_rgba(255,127,80,0.1)]">-450</div>
            </div>
            <div className="w-8 h-8 rounded-full bg-accent3/10 text-accent3 flex items-center justify-center shrink-0 border border-accent3/20"><ArrowDownLeft size={14} /></div>
          </div>
        </div>

        {/* Tiers/Split Model */}
        <section>
          <div className="flex items-center gap-2 mb-2 px-1">
            <PieChart size={14} className="text-teal" />
            <h3 className="font-sans font-bold text-sm text-text">Club Earnings Split</h3>
          </div>
          <div className="bg-surface2 rounded-[20px] border border-border p-3">
             <div className="flex justify-between text-[9px] font-bold text-muted uppercase tracking-widest mb-1.5 px-1 truncate">
                <span className="text-teal font-mono">80% YOU</span>
                <span className="text-accent font-mono text-right">20% CLUB</span>
             </div>
             <div className="h-1.5 w-full bg-surface3 rounded-full overflow-hidden flex mb-3">
                <div className="h-full bg-teal w-[80%]" />
                <div className="h-full bg-accent w-[20%]" />
             </div>
             <div className="flex flex-col gap-1">
               <SplitRow tier="Supporter" wallet="100%" club="0%" />
               <SplitRow tier="Member" wallet="90%" club="10%" />
               <SplitRow tier="Ultra" wallet="80%" club="20%" active />
               <SplitRow tier="Legend" wallet="65%" club="35%" />
             </div>
          </div>
        </section>

        {/* Transactions */}
        <section>
          <div className="flex items-center gap-2 mb-2 px-1">
            <ArrowDownLeft size={14} className="text-muted" />
            <h3 className="font-sans font-bold text-sm text-text">History</h3>
          </div>
          <div className="bg-surface2 rounded-[20px] border border-border shadow-sm flex flex-col overflow-hidden divide-y divide-border/50">
            {walletTransactions.map((tx) => (
              <TransactionItem key={tx.id} transaction={tx} />
            ))}
            {walletTransactions.length === 0 && (
              <div className="text-[10px] uppercase tracking-widest text-muted text-center py-6 font-bold">No history available</div>
            )}
          </div>
        </section>
      </div>

      <TransferSheet 
        isOpen={showTransferSheet}
        onClose={() => setShowTransferSheet(false)}
        balance={fetBalance}
        onTransfer={(recipient: string, amount: number) => {
          return transferFET(recipient, amount);
        }}
      />
    </div>
  );
}

function SplitRow({ tier, wallet, club, active = false }: { tier: string, wallet: string, club: string, active?: boolean }) {
  return (
    <div className={`flex items-center justify-between px-2 py-1.5 rounded-lg transition-colors ${active ? 'bg-accent/10 border border-accent/20' : 'bg-transparent border border-transparent'}`}>
      <div className={`text-[10px] font-bold leading-none uppercase tracking-widest ${active ? 'text-accent' : 'text-text'}`}>{tier}</div>
      <div className="flex gap-2 text-[10px] font-mono leading-none items-center">
        <span className="text-teal w-6 text-right">{wallet}</span>
        <span className="text-border">|</span>
        <span className="text-accent w-6 text-right">{club}</span>
      </div>
    </div>
  );
}

function TransactionItem({ transaction }: { transaction: WalletTransaction }) {
  const isPositive = transaction.type === 'earn' || transaction.type === 'transfer_received';
  return (
    <div className="p-2 bg-surface hover:bg-surface2 flex items-center justify-between transition-colors gap-3">
      <div className="flex items-center gap-2 overflow-hidden">
        <div className={`w-6 h-6 rounded-full flex justify-center items-center shrink-0 border ${isPositive ? 'bg-success/10 text-success border-success/20' : 'bg-accent3/10 text-accent3 border-accent3/20'}`}>
           {isPositive ? <ArrowUpRight size={10} /> : <ArrowDownLeft size={10} />}
        </div>
        <div className="truncate">
          <div className="text-[10px] font-bold text-text leading-tight truncate">{transaction.title}</div>
          <div className="text-[8px] font-bold uppercase tracking-widest text-muted truncate">{transaction.dateStr}</div>
        </div>
      </div>
      <div className={`shrink-0 font-mono text-[10px] font-bold leading-none flex flex-col items-end ${isPositive ? 'text-success' : 'text-accent3'}`}>
        <div className="flex items-center">
           {isPositive ? '+' : '-'}
           <FETDisplay amount={transaction.amount} showFiat={false} className="inline ml-0.5" />
        </div>
        <FETDisplay amount={transaction.amount} showFiat={true} className="hidden" fiatClassName="opacity-60 text-text font-sans font-normal text-[8px] tracking-normal mt-0.5 block" />
      </div>
    </div>
  );
}

function TransferSheet({ isOpen, onClose, balance, onTransfer }: { 
  isOpen: boolean; 
  onClose: () => void; 
  balance: number;
  onTransfer: (r: string, a: number) => { success: boolean; error?: string };
}) {
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const numAmount = parseInt(amount) || 0;
  const isAffordable = numAmount > 0 && numAmount <= balance;
  
  // Enforce 6 digits for Fan ID
  const cleanRecipient = recipient.replace(/\D/g, ''); 
  const isValid = cleanRecipient.length === 6 && isAffordable;

  const handleTransfer = () => {
    setError('');
    
    // We can also let the store validate if the user is trying to send to themselves
    const result = onTransfer(cleanRecipient, numAmount);
    if (!result.success) {
      setError(result.error || 'Transfer failed');
    } else {
      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        setRecipient('');
        setAmount('');
        onClose();
      }, 2000);
    }
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
            className="fixed inset-0 bg-bg/90 backdrop-blur-md z-50"
          />
          <motion.div 
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            className="fixed bottom-0 left-0 right-0 bg-surface rounded-t-[2rem] border-t border-border z-50 p-6 pb-safe"
          >
            <div className="w-12 h-1.5 bg-surface3 rounded-full mx-auto mb-8" />
            
            {success ? (
              <motion.div 
                initial={{ scale: 0.9, opacity: 0 }} 
                animate={{ scale: 1, opacity: 1 }} 
                className="text-center py-8"
              >
                <div className="w-20 h-20 bg-accent/20 text-accent rounded-full flex items-center justify-center mx-auto mb-6">
                  <Send size={40} className="translate-x-1" />
                </div>
                <h3 className="font-display text-2xl text-text mb-2">Sent Successfully!</h3>
                <p className="text-muted">You sent {numAmount} FET to Fan #{cleanRecipient}</p>
              </motion.div>
            ) : (
              <>
                <div className="flex justify-between items-start mb-6">
                  <div>
                    <h3 className="font-display text-2xl text-text tracking-tight mb-1">Transfer FET</h3>
                    <p className="text-sm text-muted">Send tokens to other fans instantly.</p>
                  </div>
                  <button onClick={onClose} className="p-2 bg-surface2 rounded-full text-muted hover:text-text transition-colors">
                    <X size={20} />
                  </button>
                </div>

                <div className="space-y-4 mb-6">
                  <div>
                    <label className="text-xs font-bold text-muted uppercase tracking-widest mb-2 block">Recipient Fan ID</label>
                    <div className="relative">
                      <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-muted mt-0.5">#</span>
                      <input 
                        type="text" 
                        inputMode="numeric"
                        placeholder="123456"
                        maxLength={6}
                        value={recipient}
                        onChange={(e) => setRecipient(e.target.value.replace(/\D/g, ''))}
                        className="w-full bg-surface2 border border-border p-4 pl-8 rounded-xl text-text placeholder:text-muted/50 font-mono text-xl focus:outline-none focus:border-accent transition-colors"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-bold text-muted uppercase tracking-widest mb-2 flex justify-between">
                      Amount to Send
                      <span className="text-accent2">Balance: {balance} FET</span>
                    </label>
                    <div className="relative">
                      <input 
                        type="number" 
                        placeholder="0"
                        value={amount}
                        min="1"
                        max={balance}
                        onChange={(e) => setAmount(e.target.value)}
                        className="w-full bg-surface2 border border-border p-4 rounded-xl text-text placeholder:text-muted/50 font-mono text-xl focus:outline-none focus:border-accent transition-colors pl-16 pt-6 pb-2"
                      />
                      <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-muted uppercase tracking-widest text-xs mt-1">FET</span>
                      <button 
                        onClick={() => setAmount(balance.toString())}
                        className="absolute right-4 top-1/2 -translate-y-1/2 text-xs font-bold text-accent bg-accent/10 px-2 py-1 rounded mt-1 hover:bg-accent/20 transition-colors"
                      >
                        MAX
                      </button>
                    </div>
                  </div>
                </div>

                {error && (
                  <div className="bg-accent2/10 text-accent2 text-xs font-bold p-3 rounded-xl mb-6 text-center border border-accent2/20">
                    {error}
                  </div>
                )}

                <button 
                  onClick={handleTransfer}
                  disabled={!isValid}
                  className={`w-full font-bold text-sm py-4 rounded-full transition-all flex items-center justify-center gap-2 ${
                    isValid 
                      ? 'bg-text text-bg hover:opacity-90 shadow-sm' 
                      : 'bg-surface3 text-muted cursor-not-allowed'
                  }`}
                >
                  Confirm Transfer <Send size={16} />
                </button>
              </>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
