import { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Share2, Bell, Plus, Sparkles, Loader2 } from 'lucide-react';
import MarketSelector from './MarketSelector';
import { StatsPanel } from './ui/StatsPanel';
import { Link } from 'react-router-dom';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { TeamLogo } from './ui/TeamLogo';
import Markdown from 'react-markdown';

export default function MatchDetail() {
  const [activeTab, setActiveTab] = useState('Predict');
  const [isMarketOpen, setIsMarketOpen] = useState(false);
  const scrollDirection = useScrollDirection();

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      {/* Header */}
      <header 
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? 'top-0' : 'top-[60px] lg:top-0'
        }`}
      >
        <Link to="/" className="text-text hover:text-primary transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">EPL · Matchday 28</div>
          <div className="text-sm font-bold text-text">Liverpool vs Arsenal</div>
        </div>
        <div className="flex gap-4">
          <Share2 size={20} className="text-muted hover:text-primary cursor-pointer" />
          <Bell size={20} className="text-muted hover:text-primary cursor-pointer" />
        </div>
      </header>

      {/* Match Hero */}
      <div className="bg-surface2 p-8 flex flex-col items-center gap-6 border-b border-border">
        <div className="flex justify-between items-center w-full max-w-sm">
          <div className="flex flex-col items-center gap-2">
            <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center shadow-inner overflow-hidden border border-border">
              <TeamLogo teamName="Liverpool" size={64} className="w-full h-full object-contain p-2" />
            </div>
            <span className="font-bold text-sm">LIV</span>
          </div>
          <div className="font-mono text-4xl font-bold">2 - 1</div>
          <div className="flex flex-col items-center gap-2">
            <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center shadow-inner overflow-hidden border border-border">
              <TeamLogo teamName="Arsenal" size={64} className="w-full h-full object-contain p-2" />
            </div>
            <span className="font-bold text-sm">ARS</span>
          </div>
        </div>
        <div className="flex items-center gap-2 text-xs font-bold text-primary bg-primary/10 px-3 py-1 rounded-full">
          <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
          63' LIVE
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-border bg-surface overflow-x-auto no-scrollbar">
        {['Predict', 'Insights', 'Stats', 'H2H', 'Lineups'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-none px-6 py-4 text-sm font-bold transition-all whitespace-nowrap ${activeTab === tab ? 'text-primary border-b-2 border-primary' : 'text-muted hover:text-text'}`}
          >
            {tab === 'Insights' && <Sparkles size={14} className="inline mr-1 -mt-0.5" />}
            {tab}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="p-6">
        {activeTab === 'Predict' && <PredictTab onOpenMarket={() => setIsMarketOpen(true)} />}
        {activeTab === 'Insights' && <InsightsTab matchQuery="live updates, stats, injuries and predictions for Liverpool vs Arsenal matchday 28" />}
        {activeTab === 'Stats' && <StatsTab />}
      </div>

      <MarketSelector isOpen={isMarketOpen} onClose={() => setIsMarketOpen(false)} />
    </div>
  );
}

function PredictTab({ onOpenMarket }: { onOpenMarket: () => void }) {
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="font-display text-xl text-text tracking-widest">MATCH MARKETS</h3>
        <button onClick={onOpenMarket} className="flex items-center gap-2 text-xs font-bold text-primary bg-primary/10 px-3 py-2 rounded-lg hover:bg-primary/20 transition-all">
          <Plus size={14} /> More Markets
        </button>
      </div>
      <MarketGroup title="Match Result" options={['1', 'X', '2']} />
      <MarketGroup title="Both Teams to Score" options={['Yes', 'No']} />
      <MarketGroup title="Over / Under 2.5" options={['Over', 'Under']} />
    </div>
  );
}

function MarketGroup({ title, options }: { title: string; options: string[] }) {
  return (
    <div className="bg-surface2 p-4 rounded-2xl border border-border">
      <div className="text-xs font-bold text-muted mb-3">{title}</div>
      <div className="grid grid-cols-3 gap-2">
        {options.map((opt) => (
          <button key={opt} className="bg-surface3 hover:bg-surface3/80 border border-border rounded-xl p-3 flex flex-col items-center transition-all">
            <span className="text-[10px] font-bold text-muted mb-1">{opt}</span>
            <span className="font-mono text-sm font-bold text-text">1.85</span>
            <span className="text-[9px] text-primary mt-1">+12 FET</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function StatsTab() {
  const matchStats = [
    { label: 'Possession', left: '55%', right: '45%', leftValue: 55, rightValue: 45 },
    { label: 'Shots on Target', left: '6', right: '3', leftValue: 6, rightValue: 3 },
    { label: 'Corners', left: '4', right: '2', leftValue: 4, rightValue: 2 },
    { label: 'Fouls', left: '8', right: '12', leftValue: 8, rightValue: 12 },
  ];

  return (
    <div className="space-y-6">
      <StatsPanel stats={matchStats} />
    </div>
  );
}

function InsightsTab({ matchQuery }: { matchQuery: string }) {
  const [insight, setInsight] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchInsights() {
      try {
        const response = await fetch('/api/insights', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            query: `Provide a short, punchy summary of ${matchQuery}. Focus on current form, key injuries, and tactical matchups. Keep it under 150 words. Format with markdown.`
          })
        });
        const data = await response.json();
        if (data.text) {
          setInsight(data.text);
        } else {
          setInsight("No insights could be generated at this time.");
        }
      } catch (err) {
        setInsight("Unable to fetch insights. Please check your connection.");
      } finally {
        setLoading(false);
      }
    }
    
    fetchInsights();
  }, [matchQuery]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-4">
        <Loader2 className="animate-spin text-primary" size={32} />
        <div className="text-sm font-bold text-muted animate-pulse">Gathering AI Insights...</div>
      </div>
    );
  }

  return (
    <div className="bg-surface2 rounded-2xl border border-primary/20 p-6 shadow-lg shadow-primary/5">
      <div className="flex items-center gap-2 mb-4 text-primary">
        <Sparkles size={20} />
        <h3 className="font-display text-lg tracking-widest">MATCH INSIGHTS</h3>
      </div>
      <div className="text-sm text-text leading-relaxed prose prose-invert prose-p:mb-2 prose-strong:text-primary max-w-none">
        {insight && <Markdown>{insight}</Markdown>}
      </div>
    </div>
  );
}
