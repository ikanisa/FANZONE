import { useEffect, useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Link } from 'react-router-dom';
import { Trophy, Calendar, Sparkles, Activity, ChevronRight, X, Flame } from 'lucide-react';
import { MatchCard } from './ui/MatchCard';
import { EmptyState } from './ui/EmptyState';
import { Badge } from './ui/Badge';
import { useAppStore } from '../store/useAppStore';
import { api } from '../services/api';
import { getWebsiteHomeBlocks, isPlatformFeatureVisible } from '../platform/access';
import { usePlatformBootstrap } from '../platform/bootstrap';
import type { Match } from '../types';

function PromoBanner({
  title,
  subtitle,
  badge,
  kicker,
  ctaLabel,
  ctaRoute,
}: {
  title: string;
  subtitle: string;
  badge: string;
  kicker: string;
  ctaLabel: string;
  ctaRoute: string;
}) {
  const [hidden, setHidden] = useState(false);

  if (hidden) return null;

  return (
    <AnimatePresence>
      {!hidden && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          exit={{ opacity: 0, height: 0 }}
          className="mb-4"
        >
          <div className="bg-gradient-to-r from-[#2563EB]/20 to-[#EF4444]/20 border border-border rounded-[20px] p-3 flex items-center justify-between gap-3 overflow-hidden relative shadow-sm">
            <div className="absolute inset-0 bg-[url('https://picsum.photos/seed/derby/800/200')] opacity-5 mix-blend-overlay bg-cover bg-center pointer-events-none" />
            <div className="flex items-center gap-3 relative z-10 min-w-0">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#2563EB] to-[#EF4444] p-[1px] shrink-0 shadow-[0_0_15px_rgba(239,68,68,0.3)]">
                <div className="w-full h-full bg-bg rounded-full flex items-center justify-center">
                  <Flame size={18} className="text-danger" />
                </div>
              </div>
              <div className="flex flex-col min-w-0">
                <div className="flex items-center gap-2 mb-0.5">
                  <Badge
                    variant="danger"
                    pulse
                    className="px-1 py-0.5 text-[8px] leading-none"
                  >
                    {badge}
                  </Badge>
                  <span className="text-[9px] font-bold text-muted uppercase tracking-widest truncate">
                    {kicker}
                  </span>
                </div>
                <h3 className="font-display text-sm text-text leading-tight truncate">
                  {title}
                </h3>
                <p className="text-[9px] text-muted truncate">
                  {subtitle}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-1.5 relative z-10 shrink-0">
              <button
                onClick={() => setHidden(true)}
                className="w-6 h-6 rounded-full bg-surface2 flex items-center justify-center text-muted hover:text-text hover:bg-surface3 transition-colors border border-border"
              >
                <X size={12} />
              </button>
              <Link
                to={ctaRoute}
                className="h-6 px-2.5 rounded-full bg-[#EF4444] text-bg font-bold text-[9px] uppercase tracking-widest hover:bg-[#EF4444]/90 transition-colors shadow-sm whitespace-nowrap flex items-center"
              >
                {ctaLabel}
              </Link>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function DailyInsight({
  team,
  subtitle,
}: {
  team: string | null;
  subtitle: string;
}) {
  if (!team) return null;

  return (
    <div className="bg-gradient-to-br from-surface to-surface2 border border-success/20 rounded-[24px] p-4 mb-6 shadow-[0_10px_30px_-10px_rgba(152,255,152,0.1)] relative overflow-hidden">
      <div className="absolute top-0 right-0 w-32 h-32 bg-success/10 rounded-full blur-2xl -translate-y-1/2 translate-x-1/2" />
      <div className="relative z-10 flex gap-3 items-center">
        <div className="w-10 h-10 rounded-full bg-success/10 border border-success/20 flex items-center justify-center text-success shrink-0 [text-shadow:0_0_10px_rgba(152,255,152,0.3)]">
          <Sparkles size={16} />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-xs leading-snug text-text line-clamp-2">
            {team} is pinned to your lean prediction feed. {subtitle}
          </p>
        </div>
      </div>
    </div>
  );
}

function FeedSection({
  title,
  icon,
  trailing,
  matches,
  emptyTitle,
  emptyDesc,
}: {
  title: string;
  icon: React.ReactNode;
  trailing?: React.ReactNode;
  matches: Match[];
  emptyTitle: string;
  emptyDesc: string;
}) {
  return (
    <section>
      <div className="flex items-center justify-between mb-4 px-1">
        <div className="flex items-center gap-2">
          {icon}
          <h2 className="font-sans font-bold text-sm text-text">{title}</h2>
        </div>
        {trailing}
      </div>

      {matches.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {matches.map((match) => (
            <MatchCard
              key={match.id}
              matchId={match.id}
              home={match.homeTeam}
              away={match.awayTeam}
              homeLogoUrl={match.homeLogoUrl}
              awayLogoUrl={match.awayLogoUrl}
              live={match.isLive}
              score={match.score ?? undefined}
              time={match.isLive ? match.timeLabel : match.kickoffLabel}
              league={match.competitionLabel}
            />
          ))}
        </div>
      ) : (
        <EmptyState title={emptyTitle} desc={emptyDesc} icon={icon} />
      )}
    </section>
  );
}

export default function HomeFeed() {
  const profileTeam = useAppStore((state) => state.profileTeam);
  const { bootstrap } = usePlatformBootstrap();
  const [liveMatches, setLiveMatches] = useState<Match[]>([]);
  const [upcomingMatches, setUpcomingMatches] = useState<Match[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const homeBlocks = useMemo(
    () => getWebsiteHomeBlocks('home.primary'),
    [bootstrap],
  );
  const showPredictions = isPlatformFeatureVisible('predictions', {
    surface: 'action',
  });
  const showLeaderboard = isPlatformFeatureVisible('leaderboard', {
    surface: 'route',
  });

  useEffect(() => {
    let active = true;

    Promise.all([api.getLiveMatches(8), api.getUpcomingMatches(8)])
      .then(([live, upcoming]) => {
        if (!active) return;
        setLiveMatches(live);
        setUpcomingMatches(upcoming);
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <div className="p-4 lg:p-12 space-y-10 pb-32 transition-all duration-300 pt-4 lg:pt-12">
      <header className="mb-2 hidden lg:flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight flex items-center gap-2">
          Predictions
        </h1>
        <div className="flex gap-2">
          <Link
            to="/fixtures"
            className="bg-[var(--accent2)] text-bg w-10 h-10 rounded-full flex items-center justify-center hover:opacity-90 transition-opacity shadow-[0_0_15px_rgba(37,99,235,0.3)]"
          >
            <Calendar size={18} />
          </Link>
          {showLeaderboard && (
            <Link
              to="/leaderboard"
              className="bg-surface2 text-text w-10 h-10 rounded-full flex items-center justify-center border border-border hover:bg-surface3 transition-colors"
            >
              <Trophy size={18} />
            </Link>
          )}
        </div>
      </header>

      {isLoading ? (
        <div className="space-y-6">
          <div className="bg-surface2 rounded-[24px] border border-border h-32 animate-pulse" />
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div className="bg-surface2 rounded-[24px] border border-border h-48 animate-pulse" />
            <div className="bg-surface2 rounded-[24px] border border-border h-48 animate-pulse" />
          </div>
        </div>
      ) : (
        homeBlocks.map((block) => {
          if (block.blockType === 'promo_banner') {
            return (
              <PromoBanner
                key={block.blockKey}
                title={block.title}
                subtitle={String(block.content.subtitle ?? 'Live fixtures are synced now.')}
                badge={String(block.content.badge ?? 'LIVE')}
                kicker={String(block.content.kicker ?? 'Global')}
                ctaLabel={String(block.content.cta_label ?? 'Open')}
                ctaRoute={
                  showPredictions
                    ? String(block.content.cta_route ?? '/fixtures')
                    : '/fixtures'
                }
              />
            );
          }

          if (block.blockType === 'daily_insight') {
            return (
              <DailyInsight
                key={block.blockKey}
                team={profileTeam}
                subtitle={String(
                  block.content.subtitle ??
                    'Track live fixtures, lock free picks, and follow the leaderboard from one place.',
                )}
              />
            );
          }

          if (block.blockType === 'live_matches') {
            return (
              <FeedSection
                key={block.blockKey}
                title={block.title}
                icon={<Activity size={16} className="text-danger" />}
                trailing={
                  <Badge variant="danger" pulse={liveMatches.length > 0}>
                    {liveMatches.length}
                  </Badge>
                }
                matches={liveMatches}
                emptyTitle={String(block.content.empty_title ?? 'No Live Matches')}
                emptyDesc={String(block.content.empty_description ?? 'Check upcoming.')}
              />
            );
          }

          if (block.blockType === 'upcoming_matches') {
            return (
              <FeedSection
                key={block.blockKey}
                title={block.title}
                icon={<Calendar size={16} className="text-muted" />}
                trailing={
                  <Link to={String(block.content.cta_route ?? '/fixtures')} className="text-muted hover:text-accent transition-colors">
                    <ChevronRight size={20} />
                  </Link>
                }
                matches={upcomingMatches}
                emptyTitle={String(block.content.empty_title ?? 'No Upcoming')}
                emptyDesc={String(block.content.empty_description ?? 'None left.')}
              />
            );
          }

          return null;
        })
      )}
    </div>
  );
}
