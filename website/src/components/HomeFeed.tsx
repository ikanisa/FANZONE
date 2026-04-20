import { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { Link } from 'react-router-dom';
import { MatchCard } from './ui/MatchCard';
import { mockMatches } from '../lib/mockData';
import { EmptyState } from './ui/EmptyState';
import { Trophy, Calendar, Sparkles, Loader2, Play, Activity, PlusCircle, Shield, ChevronRight } from 'lucide-react';
import { Badge } from './ui/Badge';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { useAppStore } from '../store/useAppStore';
import Markdown from 'react-markdown';

function DailyInsight({ team }: { team: string | null }) {
  const [insight, setInsight] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!team) {
      setLoading(false);
      return;
    }
    
    async function fetchInsights() {
      try {
        const response = await fetch('/api/insights', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: `Provide a 2-sentence breaking news update regarding ${team}. Keep it punchy.`
          })
        });
        const data = await response.json();
        if (data.text) setInsight(data.text);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    
    fetchInsights();
  }, [team]);

  if (!team || (!loading && !insight)) return null;

  return (
    <div className="bg-gradient-to-br from-surface to-surface2 border border-success/20 rounded-[24px] p-4 mb-6 shadow-[0_10px_30px_-10px_rgba(152,255,152,0.1)] relative overflow-hidden">
      <div className="absolute top-0 right-0 w-32 h-32 bg-success/10 rounded-full blur-2xl -translate-y-1/2 translate-x-1/2" />
      <div className="relative z-10 flex gap-3 items-center">
        <div className="w-10 h-10 rounded-full bg-success/10 border border-success/20 flex items-center justify-center text-success shrink-0 [text-shadow:0_0_10px_rgba(152,255,152,0.3)]">
          <Sparkles size={16} />
        </div>
        <div className="flex-1 min-w-0">
          {loading ? (
            <div className="flex items-center gap-2 text-muted">
              <Loader2 size={14} className="animate-spin text-success" />
              <span className="text-[10px] uppercase font-bold tracking-widest animate-pulse">Syncing Insights...</span>
            </div>
          ) : (
            <div className="text-xs leading-snug text-text prose prose-invert prose-p:my-0.5 prose-strong:text-success max-w-none line-clamp-2">
              <Markdown>{insight}</Markdown>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function HomeFeed() {
  const liveMatches = mockMatches.filter(m => m.status === 'live');
  const upcomingMatches = mockMatches.filter(m => m.status === 'upcoming');
  const scrollDirection = useScrollDirection();
  const profileTeam = useAppStore(state => state.profileTeam);

  return (
    <div className={`p-4 lg:p-12 space-y-10 pb-32 transition-all duration-300 ${scrollDirection === 'down' ? 'pt-4 lg:pt-12' : 'pt-20 lg:pt-12'}`}>
      <header className="mb-2 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          Predictions
        </h1>
        <div className="flex gap-2">
           <Link to="/pools/create" className="bg-[var(--accent2)] text-bg w-10 h-10 rounded-full flex items-center justify-center hover:opacity-90 transition-opacity shadow-[0_0_15px_rgba(255,127,80,0.3)]">
             <PlusCircle size={20} />
           </Link>
           <Link to="/registry" className="bg-surface2 text-text w-10 h-10 rounded-full flex items-center justify-center border border-border hover:bg-surface3 transition-colors">
             <Shield size={20} />
           </Link>
        </div>
      </header>

      <DailyInsight team={profileTeam || 'Liverpool'} />

      <section>
        <div className="flex items-center justify-between mb-4 px-1">
          <div className="flex items-center gap-2">
             <Activity size={16} className="text-danger" />
             <h2 className="font-sans font-bold text-sm text-text">Live Action</h2>
          </div>
          <Badge variant="danger" pulse>{liveMatches.length}</Badge>
        </div>
        
        {liveMatches.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {liveMatches.map(match => (
              <MatchCard 
                key={match.id}
                matchId={match.id} 
                home={match.homeTeam} 
                away={match.awayTeam} 
                live={true} 
                score={match.score} 
                time={match.time || ''} 
                league={match.league}
              />
            ))}
          </div>
        ) : (
          <EmptyState 
            title="No Live Matches"
            desc="Check upcoming."
            icon={<Trophy size={20} />}
          />
        )}
      </section>

      <section className="pb-32">
        <div className="flex items-center justify-between mb-4 px-1">
          <div className="flex items-center gap-2">
             <Calendar size={16} className="text-muted" />
             <h2 className="font-sans font-bold text-sm text-text">Upcoming</h2>
          </div>
          <Link to="/fixtures" className="text-muted hover:text-accent transition-colors">
             <ChevronRight size={20} />
          </Link>
        </div>
        
        {upcomingMatches.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {upcomingMatches.map(match => (
              <MatchCard 
                key={match.id}
                matchId={match.id} 
                home={match.homeTeam} 
                away={match.awayTeam} 
                time={match.time || ''} 
                league={match.league}
              />
            ))}
          </div>
        ) : (
          <EmptyState 
            title="No Upcoming"
            desc="None left."
            icon={<Calendar size={20} />}
          />
        )}
      </section>
    </div>
  );
}
