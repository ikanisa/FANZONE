import { useEffect, useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Link } from 'react-router-dom';
import { Calendar, Activity, ChevronRight, X, Flame, Trophy, Utensils, Wallet } from 'lucide-react';
import { MatchCard } from './ui/MatchCard';
import { EmptyState } from './ui/EmptyState';
import { Badge } from './ui/Badge';
import { api } from '../services/api';
import {
  getPlatformFeatureRoute,
  getWebsiteHomeBlocks,
  isPlatformFeatureVisible,
} from '../platform/access';
import { usePlatformBootstrap } from '../platform/bootstrap';
import type { Match } from '../types';
import { useAppStore } from '../store/useAppStore';
import { FETDisplay } from './ui/FETDisplay';

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
  const { bootstrap } = usePlatformBootstrap();
  const { fetBalance } = useAppStore();
  const [liveMatches, setLiveMatches] = useState<Match[]>([]);
  const [upcomingMatches, setUpcomingMatches] = useState<Match[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const homeBlocks = useMemo(
    () => getWebsiteHomeBlocks('home.primary'),
    [bootstrap],
  );
  const showPools = isPlatformFeatureVisible('pools', {
    surface: 'route',
  });
  const poolsRoute = getPlatformFeatureRoute('pools', {
    fallback: '/pools',
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
          Matchday
        </h1>
        <div className="flex gap-2">
          {showPools && (
            <Link
              to={poolsRoute}
              className="bg-[var(--accent2)] text-bg w-10 h-10 rounded-full flex items-center justify-center hover:opacity-90 transition-opacity shadow-[0_0_15px_rgba(37,99,235,0.3)]"
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
        <>
          <section className="fz-surface-card p-5 lg:p-6 bg-gradient-to-br from-surface via-surface2 to-[#0F7B6C]/40">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <div className="text-[10px] font-black uppercase tracking-widest text-muted">
                  Matchday wallet
                </div>
                <h2 className="mt-1 text-3xl lg:text-4xl font-black tracking-tight text-text">
                  Join pools, order at the bar, track FET.
                </h2>
                <p className="mt-2 max-w-2xl text-sm font-semibold leading-6 text-muted">
                  FET comes from bar orders and settled match pools. No odds, no prediction clutter.
                </p>
              </div>
              <div className="rounded-2xl border border-accent/20 bg-accent/10 p-4 min-w-[180px]">
                <div className="flex items-center gap-2 text-accent">
                  <Wallet size={16} />
                  <span className="text-[10px] font-black uppercase tracking-widest">
                    Balance
                  </span>
                </div>
                <div className="mt-2 text-2xl font-black text-text">
                  <FETDisplay amount={fetBalance} showFiat={false} />
                </div>
              </div>
            </div>
            <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
              {showPools && (
                <Link to={poolsRoute} className="h-14 rounded-xl bg-accent2 text-bg font-black flex items-center justify-center gap-2">
                  <Trophy size={18} /> Join Pool
                </Link>
              )}
              <Link to="/ordering" className="h-14 rounded-xl bg-primary text-primaryText font-black flex items-center justify-center gap-2">
                <Utensils size={18} /> Order
              </Link>
              <Link to="/wallet" className="h-14 rounded-xl border border-border bg-surface2 text-text font-black flex items-center justify-center gap-2">
                <Wallet size={18} /> Wallet
              </Link>
            </div>
          </section>

          {homeBlocks.map((block) => {
          if (block.blockType === 'promo_banner') {
            return (
              <PromoBanner
                key={block.blockKey}
                title={block.title}
                subtitle={String(block.content.subtitle ?? 'Curated match pools are live now.')}
                badge={String(block.content.badge ?? 'LIVE')}
                kicker={String(block.content.kicker ?? 'Global')}
                ctaLabel={String(block.content.cta_label ?? 'Open')}
                ctaRoute={
                  showPools
                    ? String(block.content.cta_route ?? poolsRoute)
                    : '/'
                }
              />
            );
          }

          if (block.blockType === 'daily_insight') {
            return null;
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
                  <Link to={String(block.content.cta_route ?? poolsRoute)} className="text-muted hover:text-accent transition-colors">
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
          })}
        </>
      )}
    </div>
  );
}
