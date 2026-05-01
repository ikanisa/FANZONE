import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { CheckCircle2, Copy, Loader2, Share2, Trophy, Users } from 'lucide-react';
import {
  clampPoolStake,
  estimatePoolOutcome,
  fixedOrDefaultStake,
  getPoolJoinAvailability,
  poolStatusLabel,
} from '@fanzone/core';
import { api } from '../services/api';
import { useAppStore } from '../store/useAppStore';
import type { Match, MatchPoolCamp, MatchPoolSummary } from '../types';
import { Badge } from './ui/Badge';
import { Card } from './ui/Card';
import { FETDisplay } from './ui/FETDisplay';

interface MatchPoolsProps {
  match: Match;
  inviteCode?: string | null;
  source?: "direct" | "venue_qr" | "social_share";
}

interface PoolListProps {
  pools: MatchPoolSummary[];
  emptyTitle?: string;
  emptyDescription?: string;
  inviteCode?: string | null;
  source?: "direct" | "venue_qr" | "social_share";
  onJoined?: () => void;
}

function poolShareUrl(
  pool: MatchPoolSummary,
  source: "direct" | "venue_qr" | "social_share" = "social_share",
) {
  const path = pool.shareUrl || (pool.shareSlug ? `/pools/${pool.shareSlug}` : '/pools');
  const url =
    typeof window === 'undefined'
      ? new URL(path, 'https://fanzone.ikanisa.com')
      : new URL(path, window.location.origin);
  if (!url.searchParams.has('source')) {
    url.searchParams.set('source', source);
  }
  return url.toString();
}

function formatScope(pool: MatchPoolSummary) {
  if (pool.scope === 'venue') return 'Venue pool';
  if (pool.scope === 'country') return `${pool.countryCode ?? 'Country'} pool`;
  return 'Global pool';
}

export function PoolList({
  pools,
  emptyTitle = 'No pools open yet',
  emptyDescription = 'Admin curated pools will appear here when available.',
  inviteCode,
  source = 'direct',
  onJoined,
}: PoolListProps) {
  if (pools.length === 0) {
    return (
      <Card className="p-6 border-border bg-surface2 text-sm text-muted">
        <div className="font-bold text-text mb-1">{emptyTitle}</div>
        {emptyDescription}
      </Card>
    );
  }

  return (
    <div className="grid gap-4">
      {pools.map((pool) => (
        <PoolCard
          key={pool.id}
          pool={pool}
          inviteCode={inviteCode}
          source={source}
          onJoined={onJoined}
        />
      ))}
    </div>
  );
}

export function PoolCard({
  pool,
  inviteCode,
  source = 'direct',
  onJoined,
}: {
  pool: MatchPoolSummary;
  inviteCode?: string | null;
  source?: "direct" | "venue_qr" | "social_share";
  onJoined?: () => void;
}) {
  const { fetBalance, deductFet, addNotification } = useAppStore();
  const [selectedCampId, setSelectedCampId] = useState(pool.camps[0]?.id ?? '');
  const [stakeAmount, setStakeAmount] = useState(fixedOrDefaultStake(pool));
  const [joining, setJoining] = useState(false);
  const [joined, setJoined] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const selectedCamp = useMemo(
    () => pool.camps.find((camp) => camp.id === selectedCampId) ?? pool.camps[0],
    [pool.camps, selectedCampId],
  );
  const entryAmount = clampPoolStake(stakeAmount, pool);
  const joinAvailability = getPoolJoinAvailability(pool);
  const canJoin = joinAvailability.canJoin && !!selectedCamp && !joined;
  const outcomeEstimate = selectedCamp
    ? estimatePoolOutcome(pool, selectedCamp, entryAmount)
    : null;

  useEffect(() => {
    setStakeAmount(fixedOrDefaultStake(pool));
    setSelectedCampId(pool.camps[0]?.id ?? '');
    setJoined(false);
    setFeedback(null);
  }, [pool.id, pool.entryFeeFet, pool.stakeMinFet, pool.camps]);

  async function handleShare() {
    await api.generatePoolShareCard(pool.id);
    const invite = await api.createPoolInvite(pool.id);
    const url =
      invite.success && invite.shareUrl
        ? new URL(
            invite.shareUrl,
            typeof window === 'undefined'
              ? 'https://fanzone.ikanisa.com'
              : window.location.origin,
          ).toString()
        : poolShareUrl(pool, 'social_share');
    try {
      if (navigator.share) {
        await navigator.share({
          title: pool.title,
          text: `${pool.title} - ${formatScope(pool)}`,
          url,
        });
      } else {
        await navigator.clipboard.writeText(url);
        setFeedback('Pool link copied.');
      }
    } catch {
      setFeedback('Sharing is not available on this device.');
    }
  }

  async function handleJoin() {
    if (!selectedCamp) return;
    if (fetBalance < entryAmount) {
      setFeedback('Insufficient FET balance.');
      return;
    }

    setJoining(true);
    setFeedback(null);
    const result = await api.joinMatchPool(
      pool.id,
      selectedCamp.id,
      entryAmount,
      inviteCode,
      inviteCode ? 'direct' : source,
    );
    setJoining(false);

    if (!result.success) {
      setFeedback(result.error ?? 'Could not join pool.');
      return;
    }

    deductFet(entryAmount);
    setJoined(true);
    addNotification({
      type: 'system',
      title: 'Joined Match Pool',
      message: `You joined ${pool.title} on ${selectedCamp.label}.`,
    });
    onJoined?.();
  }

  return (
    <Card className="p-5 bg-surface2 border-border overflow-hidden relative">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2 text-accent2 mb-2">
            <Trophy size={18} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              {formatScope(pool)}
            </span>
          </div>
          <h3 className="text-xl font-black text-text leading-tight">
            {pool.title}
          </h3>
        </div>
        <button
          type="button"
          onClick={handleShare}
          className="w-10 h-10 rounded-full bg-surface border border-border text-muted hover:text-text flex items-center justify-center"
          aria-label="Share pool"
        >
          {typeof navigator !== 'undefined' && navigator.share ? (
            <Share2 size={18} />
          ) : (
            <Copy size={18} />
          )}
        </button>
      </div>

      {pool.socialCardUrl && (
        <img
          src={pool.socialCardUrl}
          alt={`${pool.title} share card`}
          className="mb-4 aspect-[1200/630] w-full rounded-2xl border border-border object-cover"
          loading="lazy"
        />
      )}

      <div className="grid grid-cols-2 gap-2 mb-4">
        <Metric label="Members" value={pool.totalMembers.toLocaleString()} />
        <Metric
          label="Pooled"
          value={<FETDisplay amount={pool.totalStakedFet} />}
        />
      </div>

      <div className="grid grid-cols-3 gap-2 mb-4">
        {pool.camps.map((camp) => (
          <CampButton
            key={camp.id}
            camp={camp}
            selected={camp.id === selectedCampId}
            disabled={pool.status !== 'open' || joined}
            onSelect={() => setSelectedCampId(camp.id)}
          />
        ))}
      </div>

      <div className="rounded-2xl border border-border bg-surface3 p-4 mb-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-[10px] font-bold uppercase tracking-widest text-muted">
              Stake
            </div>
            <div className="text-xs text-muted mt-1">
              {pool.entryFeeFet > 0
                ? 'Fixed stake for this pool'
                : `${pool.stakeMinFet} - ${pool.stakeMaxFet} FET`}
            </div>
          </div>
          <label className="flex items-center gap-2">
            <input
              type="number"
              min={pool.stakeMinFet}
              max={pool.stakeMaxFet}
              value={entryAmount}
              disabled={pool.entryFeeFet > 0 || !canJoin}
              onChange={(event) => setStakeAmount(Number(event.target.value))}
              className="w-24 rounded-xl border border-border bg-surface2 px-3 py-2 text-right font-mono font-bold text-text"
              aria-label="FET stake amount"
            />
            <span className="text-xs font-black text-muted">FET</span>
          </label>
        </div>

        {outcomeEstimate && (
          <div className="mt-4 grid grid-cols-2 gap-2 text-xs">
            <Metric
              label="If camp wins now"
              value={<FETDisplay amount={outcomeEstimate.estimatedReturnIfSelectedCampWins} />}
            />
            <Metric
              label="Est. upside"
              value={<FETDisplay amount={outcomeEstimate.estimatedProfitIfSelectedCampWins} />}
            />
            <p className="col-span-2 text-[11px] leading-5 text-muted">
              {outcomeEstimate.disclaimer}
            </p>
          </div>
        )}
      </div>

      {joined ? (
        <div className="flex items-center gap-3 p-4 bg-success/10 text-success rounded-2xl border border-success/20">
          <CheckCircle2 size={20} />
          <span className="font-bold">You are in this pool.</span>
        </div>
      ) : (
        <button
          disabled={!canJoin || joining}
          onClick={handleJoin}
          className="w-full h-14 bg-accent2 text-darkBg font-black rounded-2xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all disabled:opacity-50"
        >
          {joining ? (
            <Loader2 size={20} className="animate-spin" />
          ) : (
            <>
              <Users size={20} />
              STAKE {entryAmount} FET
            </>
          )}
        </button>
      )}

      <div className="flex items-center gap-2 mt-3">
        <Badge variant={pool.status === 'open' ? 'success' : 'ghost'}>
          {poolStatusLabel(pool.status).toUpperCase()}
        </Badge>
        {pool.isOfficial && <Badge variant="ghost">OFFICIAL</Badge>}
      </div>

      {!joinAvailability.canJoin && joinAvailability.reason && (
        <p className="mt-3 text-xs text-muted">{joinAvailability.reason}</p>
      )}

      {feedback && (
        <p className="mt-3 text-center text-xs text-warning font-bold uppercase tracking-tight">
          {feedback}
        </p>
      )}
    </Card>
  );
}

export default function MatchPools({ match, inviteCode, source }: MatchPoolsProps) {
  const [pools, setPools] = useState<MatchPoolSummary[]>([]);
  const [loading, setLoading] = useState(true);

  async function loadPools() {
    setLoading(true);
    const rows = await api.getMatchPools(match.id);
    setPools(rows);
    setLoading(false);
  }

  useEffect(() => {
    void loadPools();
  }, [match.id]);

  if (loading) {
    return (
      <Card className="p-6 bg-surface2 border-border">
        <div className="flex items-center gap-3 text-sm text-muted">
          <Loader2 size={18} className="animate-spin text-accent" />
          Loading match pools...
        </div>
      </Card>
    );
  }

  return (
    <section className="space-y-4">
      <div>
        <h2 className="font-display text-xl text-text tracking-widest">
          Match Pools
        </h2>
        <p className="text-sm text-muted mt-1">
          Join a camp with FET. After the final result, winning camps receive
          the settled pool through the wallet ledger.
        </p>
      </div>
      <PoolList
        pools={pools}
        emptyTitle="No pool is open for this match"
        emptyDescription="Official venue, country, or global pools will appear after admin curation."
        inviteCode={inviteCode}
        source={source}
        onJoined={loadPools}
      />
    </section>
  );
}

function CampButton({
  camp,
  selected,
  disabled,
  onSelect,
}: {
  camp: MatchPoolCamp;
  selected: boolean;
  disabled: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onSelect}
      className={`rounded-xl p-3 text-left transition-all border ${
        selected
          ? 'border-accent bg-accent/10 text-accent'
          : 'bg-surface3 hover:bg-surface3/80 border-border text-text'
      } disabled:opacity-70`}
    >
      <div className="font-bold text-sm truncate">{camp.label}</div>
      <div className="text-[10px] text-muted mt-1">
        {camp.memberCount} members
      </div>
      <div className="text-[10px] text-muted">
        {camp.totalStakedFet} FET pooled
      </div>
    </button>
  );
}

function Metric({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <div className="rounded-xl border border-border bg-surface3 p-3">
      <div className="text-[10px] font-bold uppercase tracking-widest text-muted">
        {label}
      </div>
      <div className="font-mono text-sm font-bold text-text mt-1">{value}</div>
    </div>
  );
}
