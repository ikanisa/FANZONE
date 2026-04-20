import React from 'react';
import { useAppStore } from '../../store/useAppStore';

const EUR_RATE = 100; // 100 FET = 1 EUR

const CURRENCY_RATES: Record<string, { symbol: string, rate: number }> = {
  EUR: { symbol: '€', rate: 1.0 },
  GBP: { symbol: '£', rate: 0.85 },
  RWF: { symbol: 'FRW ', rate: 1400 },
  NGN: { symbol: '₦', rate: 1400 },
  KES: { symbol: 'KSh ', rate: 145 },
  USD: { symbol: '$', rate: 1.09 },
  TRY: { symbol: '₺', rate: 35.0 },
  CAD: { symbol: 'CA$', rate: 1.48 },
};

// Map specific teams to currencies to infer local country
const TEAM_TO_CURRENCY: Record<string, string> = {
  // Malta
  'Hamrun Spartans': 'EUR', 'Valletta FC': 'EUR', 'Floriana': 'EUR', 'Birkirkara': 'EUR',
  'Hibernians': 'EUR', 'Sliema Wanderers': 'EUR', 'Balzan': 'EUR', 'Gzira United': 'EUR',
  
  // UK
  'Arsenal': 'GBP', 'Manchester City': 'GBP', 'Manchester United': 'GBP', 'Chelsea': 'GBP',
  'Liverpool': 'GBP', 'Tottenham Hotspur': 'GBP', 'Aston Villa': 'GBP', 'Newcastle United': 'GBP',
  'Celtic': 'GBP', 'Rangers': 'GBP',
  
  // Rwanda
  'APR FC': 'RWF', 'Rayon Sports': 'RWF', 'Kiyovu Sports': 'RWF', 'Police FC': 'RWF', 'Mukura VS': 'RWF',

  // Nigeria
  'Enyimba': 'NGN', 'Kano Pillars': 'NGN', 'Rivers United': 'NGN', 'Enugu Rangers': 'NGN',

  // Kenya
  'Gor Mahia': 'KES', 'AFC Leopards': 'KES',

  // Turkey
  'Galatasaray': 'TRY', 'Fenerbahce': 'TRY', 'Besiktas': 'TRY',
};

export function guessUserCurrency(favoriteTeams: string[]): { code: string, symbol: string, rate: number } {
  for (const team of favoriteTeams) {
    if (TEAM_TO_CURRENCY[team]) {
       const code = TEAM_TO_CURRENCY[team];
       return { code, ...CURRENCY_RATES[code] };
    }
  }
  // Default to EUR
  return { code: 'EUR', ...CURRENCY_RATES['EUR'] };
}

export function FETDisplay({ 
    amount, 
    showFiat = true, 
    className = "",
    fiatClassName = "text-muted text-[0.85em] ml-1 font-normal tracking-normal"
}: { 
    amount: number, 
    showFiat?: boolean, 
    className?: string,
    fiatClassName?: string 
}) {
   const { favoriteTeams } = useAppStore();
   const { symbol, rate } = guessUserCurrency(favoriteTeams);
   
   const fiatAmount = (amount / EUR_RATE) * rate;
   const fiatStr = fiatAmount % 1 === 0 ? fiatAmount.toLocaleString() : fiatAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
   
   return (
      <span className={className}>
         FET {amount.toLocaleString()} {showFiat && <span className={fiatClassName}>({symbol}{fiatStr})</span>}
      </span>
   );
}
