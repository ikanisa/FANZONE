import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { useAppStore } from '../store/useAppStore';
import { ArrowLeft, RefreshCcw, CheckCircle, ChevronDown, Check, Globe } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';

// Base token setup
const FET_TO_EUR_RATE = 100; // 100 FET = 1 EUR
const BASE_CURRENCY = 'EUR';

// Mock Exchange Rates (relative to EUR)
const EXCHANGE_RATES: Record<string, { rate: number, label: string, symbol: string, region: string }> = {
  EUR: { rate: 1.0, label: 'Euro', symbol: '€', region: 'Global' },
  USD: { rate: 1.09, label: 'US Dollar', symbol: '$', region: 'North America' },
  GBP: { rate: 0.85, label: 'British Pound', symbol: '£', region: 'Europe' },
  CAD: { rate: 1.48, label: 'Canadian Dollar', symbol: 'CA$', region: 'North America' },
  AUD: { rate: 1.65, label: 'Australian Dollar', symbol: 'A$', region: 'Oceania' },
  JPY: { rate: 164.50, label: 'Japanese Yen', symbol: '¥', region: 'Asia' },
  
  // African Currencies
  NGN: { rate: 1300.0, label: 'Nigerian Naira', symbol: '₦', region: 'Africa' },
  ZAR: { rate: 20.50, label: 'South African Rand', symbol: 'R', region: 'Africa' },
  KES: { rate: 145.20, label: 'Kenyan Shilling', symbol: 'KSh', region: 'Africa' },
  GHS: { rate: 14.50, label: 'Ghanaian Cedi', symbol: 'GH₵', region: 'Africa' },
  MAD: { rate: 10.80, label: 'Moroccan Dirham', symbol: 'MAD', region: 'Africa' },

  // Other Global Currencies
  INR: { rate: 90.50, label: 'Indian Rupee', symbol: '₹', region: 'Asia' },
  BRL: { rate: 5.40, label: 'Brazilian Real', symbol: 'R$', region: 'South America' },
  MXN: { rate: 18.20, label: 'Mexican Peso', symbol: '$', region: 'North America' },
  AED: { rate: 4.00, label: 'UAE Dirham', symbol: 'د.إ', region: 'Middle East' },
};

export default function FETExchange() {
  const { fetBalance, deductFet } = useAppStore();
  const navigate = useNavigate();
  const scrollDirection = useScrollDirection();
  
  const [amountFET, setAmountFET] = useState<string>('');
  const [selectedCurrency, setSelectedCurrency] = useState('USD');
  const [showCurrencySelector, setShowCurrencySelector] = useState(false);
  const [isExchanging, setIsExchanging] = useState(false);
  const [success, setSuccess] = useState(false);

  // Group currencies by region for the selector
  const groupedCurrencies = Object.entries(EXCHANGE_RATES).reduce((acc, [code, data]) => {
    if (!acc[data.region]) acc[data.region] = [];
    acc[data.region].push({ code, ...data });
    return acc;
  }, {} as Record<string, any[]>);

  const numAmount = parseInt(amountFET) || 0;
  const isAffordable = numAmount > 0 && numAmount <= fetBalance;
  
  // Calculate conversion
  const euroEquivalent = numAmount / FET_TO_EUR_RATE;
  const targetAmount = euroEquivalent * EXCHANGE_RATES[selectedCurrency].rate;

  const handleMax = () => {
    setAmountFET(fetBalance.toString());
  };

  const handleExchange = () => {
    if (!isAffordable) return;
    
    setIsExchanging(true);
    
    // Simulate API call for exchange
    setTimeout(() => {
      deductFet(numAmount);
      // In a real app we'd dispatch a 'withdraw/fiat equivalent' action here
      setIsExchanging(false);
      setSuccess(true);
      
      setTimeout(() => {
         navigate('/wallet');
      }, 3000);
    }, 1500);
  };

  if (success) {
    return (
      <div className="min-h-screen bg-bg flex flex-col items-center justify-center p-6 text-center">
        <motion.div 
           initial={{ scale: 0.8, opacity: 0 }}
           animate={{ scale: 1, opacity: 1 }}
           className="w-24 h-24 bg-accent/20 text-accent rounded-full flex items-center justify-center mb-6"
        >
          <CheckCircle size={48} />
        </motion.div>
        <h1 className="font-display text-4xl text-text tracking-widest mb-4">EXCHANGE SUCCESS</h1>
        <p className="text-muted text-lg mb-8 max-w-sm">
          You successfully converted {numAmount.toLocaleString()} FET into {EXCHANGE_RATES[selectedCurrency].symbol}{targetAmount.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})} {selectedCurrency}.
        </p>
        <p className="text-sm text-muted">Redirecting to wallet...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg pb-24 relative">
      {/* Sticky Header */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <button onClick={() => navigate(-1)} className="p-2 -ml-2 rounded-full text-muted hover:text-text transition-colors">
          <ArrowLeft size={20} />
        </button>
        <div className="text-center absolute left-1/2 -translate-x-1/2">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Global Payout</div>
          <div className="text-sm font-bold text-text">Exchange FET</div>
        </div>
        <div className="w-8" />
      </header>

      <div className="p-6 lg:p-12 max-w-xl mx-auto">
        <div className="mb-8">
           <div className="inline-flex items-center gap-2 bg-surface2 px-3 py-1 rounded-full border border-border mb-4">
              <Globe size={14} className="text-accent" />
              <span className="text-[10px] font-bold text-text uppercase tracking-widest">Global Payouts Active</span>
           </div>
           <h1 className="font-display text-4xl text-text tracking-widest mb-2">CASH OUT</h1>
           <p className="text-muted text-sm">Convert your FET balance into popular global and African currencies.</p>
        </div>

        {/* Exchange Card */}
        <div className="bg-surface2 rounded-3xl border border-border p-6 shadow-sm mb-6 relative">
           
           {/* Exchange Rate Badge */}
           <div className="absolute -top-3 right-6 bg-accent text-bg px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest shadow-sm">
             Base Rate: 100 FET = 1 EUR
           </div>

           {/* Input FET */}
           <div className="mb-6">
              <div className="flex justify-between items-center mb-2">
                 <label className="text-[10px] font-bold text-muted uppercase tracking-widest">Pay With FET</label>
                 <span className="text-xs font-bold text-text">Avail: {fetBalance.toLocaleString()}</span>
              </div>
              <div className="relative">
                 <input 
                    type="number"
                    value={amountFET}
                    onChange={(e) => setAmountFET(e.target.value)}
                    placeholder="0"
                    className="w-full bg-surface border border-border rounded-2xl p-4 pr-24 font-mono text-2xl text-text focus:outline-none focus:border-accent transition-colors"
                 />
                 <button 
                    onClick={handleMax}
                    className="absolute right-4 top-1/2 -translate-y-1/2 bg-surface3 border border-border px-3 py-1.5 rounded-lg text-xs font-bold text-text hover:bg-surface transition-colors"
                 >
                    MAX
                 </button>
              </div>
           </div>
           
           {/* Swap Icon Divider */}
           <div className="flex justify-center -my-3 relative z-10">
              <div className="w-10 h-10 bg-surface3 border border-border rounded-full flex items-center justify-center text-muted">
                 <RefreshCcw size={16} />
              </div>
           </div>

           {/* Receive Currency */}
           <div className="mt-4">
              <div className="flex justify-between items-center mb-2">
                 <label className="text-[10px] font-bold text-muted uppercase tracking-widest">You Receive</label>
                 <span className="text-[10px] text-muted">1 EUR = {EXCHANGE_RATES[selectedCurrency].rate} {selectedCurrency}</span>
              </div>
              <div className="flex gap-2">
                 <button 
                    onClick={() => setShowCurrencySelector(true)}
                    className="shrink-0 bg-surface border border-border rounded-2xl px-4 py-4 flex items-center gap-2 hover:bg-surface3 transition-colors text-text font-bold"
                 >
                    {selectedCurrency} <ChevronDown size={16} className="text-muted" />
                 </button>
                 <div className="flex-1 bg-surface border border-border rounded-2xl p-4 flex items-center justify-end overflow-hidden">
                    <span className="font-mono text-2xl text-accent truncate">
                       {EXCHANGE_RATES[selectedCurrency].symbol} {targetAmount > 0 ? targetAmount.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2}) : '0.00'}
                    </span>
                 </div>
              </div>
           </div>

        </div>

        {/* Action Button */}
        <button 
           onClick={handleExchange}
           disabled={!isAffordable || numAmount <= 0 || isExchanging}
           className={`w-full py-4 rounded-xl font-bold flex items-center justify-center gap-2 transition-all ${
              !isAffordable || numAmount <= 0 
                 ? 'bg-surface3 text-muted cursor-not-allowed'
                 : 'bg-text text-bg hover:opacity-90 shadow-lg'
           }`}
        >
           {isExchanging ? (
              <RefreshCcw size={20} className="animate-spin" />
           ) : (
              <>CONVERT TO {selectedCurrency}</>
           )}
        </button>

        {!isAffordable && numAmount > 0 && (
           <p className="text-accent2 text-xs font-bold text-center mt-3">Insufficient FET balance</p>
        )}
      </div>

      {/* Currency Selector Modal */}
      <AnimatePresence>
         {showCurrencySelector && (
            <>
               <motion.div 
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  onClick={() => setShowCurrencySelector(false)}
                  className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-50"
               />
               <motion.div
                  initial={{ y: '100%' }}
                  animate={{ y: 0 }}
                  exit={{ y: '100%' }}
                  transition={{ type: 'spring', damping: 25, stiffness: 200 }}
                  className="fixed bottom-0 left-0 right-0 max-h-[85vh] bg-surface rounded-t-3xl border-t border-border z-50 flex flex-col"
               >
                  <div className="p-4 border-b border-border flex justify-between items-center shrink-0">
                     <h3 className="font-bold text-text">Select Currency</h3>
                     <button onClick={() => setShowCurrencySelector(false)} className="p-2 bg-surface2 rounded-full text-muted">
                        <ArrowLeft size={16} className="-rotate-90" />
                     </button>
                  </div>
                  
                  <div className="overflow-y-auto p-4 space-y-6 pb-24">
                     {Object.entries(groupedCurrencies).map(([region, currencies]) => (
                        <div key={region}>
                           <h4 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-3">{region}</h4>
                           <div className="space-y-2">
                              {currencies.map(c => (
                                 <button
                                    key={c.code}
                                    onClick={() => {
                                       setSelectedCurrency(c.code);
                                       setShowCurrencySelector(false);
                                    }}
                                    className={`w-full flex items-center justify-between p-4 rounded-xl border transition-all ${
                                       selectedCurrency === c.code 
                                          ? 'border-accent bg-accent/5'
                                          : 'border-border bg-surface2 hover:bg-surface3'
                                    }`}
                                 >
                                    <div className="flex items-center gap-3">
                                       <div className="w-10 h-10 rounded-full bg-surface border border-border flex items-center justify-center font-bold text-sm text-text">
                                          {c.symbol}
                                       </div>
                                       <div className="text-left">
                                          <div className="font-bold text-text">{c.code}</div>
                                          <div className="text-xs text-muted leading-tight">{c.label}</div>
                                       </div>
                                    </div>
                                    {selectedCurrency === c.code && <Check className="text-accent" size={18} />}
                                 </button>
                              ))}
                           </div>
                        </div>
                     ))}
                  </div>
               </motion.div>
            </>
         )}
      </AnimatePresence>
    </div>
  );
}
