import { useEffect, useState } from 'react';
import {
  Bell,
  ChevronLeft,
  Loader2,
  Share2,
} from 'lucide-react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import MatchPools from './MatchPools';
import { TeamLogo } from './ui/TeamLogo';
import { api } from '../services/api';
import {
  getPlatformFeatureRoute,
  isPlatformFeatureVisible,
} from '../platform/access';
import { usePlatformBootstrap } from '../platform/bootstrap';
import type { Match } from '../types';

export default function MatchDetail() {
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  usePlatformBootstrap();
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ tone: 'success' | 'error'; message: string } | null>(null);
  const [match, setMatch] = useState<Match | null>(null);
  const inviteCode = searchParams.get('invite');
  const showNotifications = isPlatformFeatureVisible('notifications', {
    surface: 'route',
  });
  const notificationsRoute = getPlatformFeatureRoute('notifications', {
    fallback: '/notifications',
  });

  useEffect(() => {
    let active = true;

    async function loadMatch() {
      if (!id) {
        setLoadError('Match not found.');
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setLoadError(null);
      setFeedback(null);

      const nextMatch = await api.getMatchDetail(id);
      if (!active) return;

      if (!nextMatch) {
        setMatch(null);
        setLoadError('This match could not be loaded.');
        setIsLoading(false);
        return;
      }

      setMatch(nextMatch);
      setIsLoading(false);
    }

    void loadMatch();

    return () => {
      active = false;
    };
  }, [id]);

  const handleShare = async () => {
    if (!match) return;

    const shareText = `${match.homeTeam} vs ${match.awayTeam} - ${match.kickoffLabel}`;

    try {
      if (navigator.share) {
        await navigator.share({
          title: `${match.homeTeam} vs ${match.awayTeam}`,
          text: shareText,
          url: window.location.href,
        });
        return;
      }

      await navigator.clipboard.writeText(`${shareText} ${window.location.href}`);
      setFeedback({ tone: 'success', message: 'Match pool link copied.' });
    } catch {
      setFeedback({ tone: 'error', message: 'Sharing is not available on this device.' });
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
        <MatchHeader title="Match Pools" subtitle="Loading" />
        <div className="flex flex-col items-center justify-center py-24 gap-4">
          <Loader2 className="animate-spin text-accent" size={32} />
          <div className="text-sm font-bold text-muted animate-pulse">
            Loading match pools...
          </div>
        </div>
      </div>
    );
  }

  if (!match) {
    return (
      <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
        <MatchHeader title="Match Pools" subtitle="Unavailable" />
        <div className="p-6">
          <div className="bg-surface2 rounded-2xl border border-border p-6 text-sm text-muted">
            {loadError ?? 'This match is no longer available.'}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
        <Link to="/pools" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center min-w-0">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest truncate">
            {match.competitionLabel}
            {match.matchdayOrRound ? ` - ${match.matchdayOrRound}` : ''}
          </div>
          <div className="text-sm font-bold text-text truncate">
            {match.homeTeam} vs {match.awayTeam}
          </div>
        </div>
        <div className="flex gap-4">
          <button
            onClick={handleShare}
            className="text-muted hover:text-accent transition-all"
            aria-label="Share match pools"
          >
            <Share2 size={20} />
          </button>
          {showNotifications && (
            <Link
              to={notificationsRoute}
              className="text-muted hover:text-accent transition-all"
              aria-label="Open notifications"
            >
              <Bell size={20} />
            </Link>
          )}
        </div>
      </header>

      <div className="bg-surface2 p-8 flex flex-col items-center gap-6 border-b border-border">
        <div className="flex justify-between items-center w-full max-w-sm">
          <TeamBlock name={match.homeTeam} logoUrl={match.homeLogoUrl} />
          <div className="font-mono text-4xl font-bold">
            {match.score ?? 'vs'}
          </div>
          <TeamBlock name={match.awayTeam} logoUrl={match.awayLogoUrl} />
        </div>
        <div className="flex items-center gap-2 text-xs font-bold text-accent bg-accent/10 px-3 py-1 rounded-full">
          <span className={`w-2 h-2 rounded-full ${match.isLive ? 'bg-accent animate-pulse' : 'bg-accent/70'}`} />
          {match.isLive ? `${match.timeLabel} LIVE` : `${match.dateLabel} - ${match.kickoffLabel}`}
        </div>
      </div>

      <div className="p-6">
        {feedback && (
          <div
            className={`rounded-2xl border p-4 mb-4 text-sm ${
              feedback.tone === 'success'
                ? 'border-success/20 bg-success/10 text-text'
                : 'border-danger/20 bg-danger/10 text-text'
            }`}
          >
            {feedback.message}
          </div>
        )}

        <MatchPools match={match} inviteCode={inviteCode} />
      </div>
    </div>
  );
}

function MatchHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
      <Link to="/pools" className="text-text hover:text-accent transition-all">
        <ChevronLeft size={24} />
      </Link>
      <div className="text-center">
        <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
          {title}
        </div>
        <div className="text-sm font-bold text-text">{subtitle}</div>
      </div>
      <div className="w-12" />
    </header>
  );
}

function TeamBlock({ name, logoUrl }: { name: string; logoUrl?: string | null }) {
  return (
    <div className="flex flex-col items-center gap-2 min-w-0">
      <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center shadow-inner overflow-hidden border border-border">
        <TeamLogo
          teamName={name}
          src={logoUrl}
          size={64}
          className="w-full h-full object-contain p-2"
        />
      </div>
      <span className="font-bold text-sm truncate max-w-24">
        {name.slice(0, 3).toUpperCase()}
      </span>
    </div>
  );
}
