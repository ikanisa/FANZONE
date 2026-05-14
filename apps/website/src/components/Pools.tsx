import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import {
  ChevronLeft,
  Copy,
  Loader2,
  Plus,
  Share2,
  Trophy,
  UserRound,
} from "lucide-react";
import { safeImageUrl } from "@fanzone/core";
import { api } from "../services/api";
import type { Match, MatchPoolEntrySummary, MatchPoolSummary } from "../types";
import MatchPools, { PoolList } from "./MatchPools";
import { Card } from "./ui/Card";
import { Badge } from "./ui/Badge";
import { FETDisplay } from "./ui/FETDisplay";

export default function Pools() {
  const [searchParams] = useSearchParams();
  const { slug } = useParams<{ slug: string }>();
  const matchId = searchParams.get("matchId");
  const inviteCode = searchParams.get("invite");
  const source = normalizePoolSource(searchParams.get("source"));
  const [match, setMatch] = useState<Match | null>(null);
  const [poolMatches, setPoolMatches] = useState<Match[]>([]);
  const [myPools, setMyPools] = useState<MatchPoolEntrySummary[]>([]);
  const [pools, setPools] = useState<MatchPoolSummary[]>([]);
  const [loading, setLoading] = useState(true);

  async function loadPools() {
    setLoading(true);
    const [nextMatches, nextMyPools] = await Promise.all([
      api.getPoolMatches(12),
      api.getMyPools(20),
    ]);
    setPoolMatches(nextMatches);
    setMyPools(nextMyPools);

    if (slug) {
      const pool = await api.getMatchPoolBySlug(
        slug,
        inviteCode,
        inviteCode ? "invite_link" : source,
      );
      if (!pool) {
        setMatch(null);
        setPools([]);
        setLoading(false);
        return;
      }

      let resolvedPool = pool;
      const card = await api.generatePoolShareCard(pool.id);
      if (card.success && card.socialCardUrl) {
        resolvedPool = { ...pool, socialCardUrl: card.socialCardUrl };
      }

      const nextMatch = await api.getMatchDetail(pool.matchId);
      setMatch(nextMatch);
      setPools([resolvedPool]);
      setLoading(false);
      return;
    }

    if (matchId) {
      const nextMatch = await api.getMatchDetail(matchId);
      setMatch(nextMatch);
      setPools([]);
      setLoading(false);
      return;
    }

    const rows = await api.getOpenMatchPools(24);
    setPools(rows);
    setMatch(null);
    setLoading(false);
  }

  useEffect(() => {
    void loadPools();
  }, [matchId, slug]);

  useEffect(() => {
    if (!slug || pools.length === 0) return;
    const pool = pools[0];
    const title = `${pool.title} | FANZONE Pool`;
    const description = match
      ? `${match.homeTeam} vs ${match.awayTeam}. Join the pool with FET.`
      : "Join this FANZONE match pool with FET.";
    document.title = title;
    setMetaTag("og:title", title, "property");
    setMetaTag("og:description", description, "property");
    setMetaTag("twitter:title", title);
    setMetaTag("twitter:description", description);
    const socialCardUrl = safeImageUrl(pool.socialCardUrl);
    if (socialCardUrl) {
      setMetaTag("og:image", socialCardUrl, "property");
      setMetaTag("twitter:image", socialCardUrl);
    }
    setMetaTag("og:url", window.location.href, "property");
  }, [match, pools, slug]);

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
        <Link to="/" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
            FET Pools
          </div>
          <div className="text-sm font-bold text-text">Match Pools</div>
        </div>
        <div className="w-6" />
      </header>

      <main className="p-6 space-y-6">
        <section className="bg-surface2 rounded-3xl border border-border p-6">
          <div className="w-12 h-12 rounded-2xl bg-accent/10 text-accent flex items-center justify-center mb-4">
            <Trophy size={24} />
          </div>
          <h1 className="font-display text-3xl text-text tracking-tight">
            Match Pools
          </h1>
          <p className="text-sm text-muted leading-6 mt-2 max-w-2xl">
            Join curated venue-linked pools. Guests enter a camp with FET, and
            settlement pays eligible winners after the final result.
          </p>
        </section>

        <SelectedMatches matches={poolMatches} />

        {loading ? (
          <Card className="p-6 bg-surface2 border-border">
            <div className="flex items-center gap-3 text-sm text-muted">
              <Loader2 size={18} className="animate-spin text-accent" />
              Loading pools...
            </div>
          </Card>
        ) : slug && match ? (
          <PoolList
            pools={pools}
            emptyTitle="Pool unavailable"
            emptyDescription="This pool is not currently visible."
            inviteCode={inviteCode}
            source={source}
            onJoined={loadPools}
          />
        ) : matchId && match ? (
          <div className="space-y-6">
            <MatchPools match={match} inviteCode={inviteCode} source={source} />
            <CreatePoolPanel
              matches={poolMatches}
              defaultMatchId={match.id}
              onCreated={loadPools}
            />
          </div>
        ) : slug || matchId ? (
          <Card className="p-6 border-border bg-surface2 text-sm text-muted">
            This pool or match could not be loaded.
          </Card>
        ) : (
          <div className="space-y-6">
            <MyPoolsList entries={myPools} />
            <CreatePoolPanel matches={poolMatches} onCreated={loadPools} />
            <PoolList
              pools={pools}
              emptyTitle="No open pools"
              emptyDescription="Pools will appear after admin curation and venue setup."
              inviteCode={inviteCode}
              source={source}
              onJoined={loadPools}
            />
          </div>
        )}
      </main>
    </div>
  );
}

function normalizePoolSource(
  value: string | null,
): "direct" | "venue_qr" | "social_share" {
  if (value === "venue_qr" || value === "social_share") return value;
  return "direct";
}

function setMetaTag(
  name: string,
  content: string,
  attribute: "name" | "property" = "name",
) {
  let tag = document.head.querySelector<HTMLMetaElement>(
    `meta[${attribute}="${name}"]`,
  );
  if (!tag) {
    tag = document.createElement("meta");
    tag.setAttribute(attribute, name);
    document.head.appendChild(tag);
  }
  tag.content = content;
}

function SelectedMatches({ matches }: { matches: Match[] }) {
  if (matches.length === 0) return null;

  return (
    <section className="space-y-3">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="font-display text-xl text-text tracking-widest">
            Selected Matches
          </h2>
          <p className="text-sm text-muted">
            Pick a match to compare venue-linked and shareable pools.
          </p>
        </div>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {matches.map((item) => (
          <Link
            key={item.id}
            to={`/pools?matchId=${encodeURIComponent(item.id)}`}
            className="rounded-2xl border border-border bg-surface2 p-4 hover:border-accent/40 transition-colors"
          >
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <div className="text-[10px] font-black uppercase tracking-widest text-muted truncate">
                  {item.competitionLabel}
                </div>
                <div className="font-black text-text truncate">
                  {item.homeTeam} vs {item.awayTeam}
                </div>
              </div>
              <Badge variant={item.isLive ? "danger" : "ghost"}>
                {item.isLive ? "LIVE" : item.kickoffLabel}
              </Badge>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

function MyPoolsList({ entries }: { entries: MatchPoolEntrySummary[] }) {
  if (entries.length === 0) {
    return (
      <Card className="p-5 border-border bg-surface2">
        <div className="flex items-center gap-3 text-muted">
          <UserRound size={18} />
          <span className="text-sm">Your joined pools will appear here.</span>
        </div>
      </Card>
    );
  }

  return (
    <section className="space-y-3">
      <h2 className="font-display text-xl text-text tracking-widest">
        My Pools
      </h2>
      <div className="grid gap-3">
        {entries.map((entry) => (
          <Link
            key={entry.entryId}
            to={
              entry.shareUrl ??
              `/pools?matchId=${encodeURIComponent(entry.matchId)}`
            }
            className="rounded-2xl border border-border bg-surface2 p-4 hover:border-accent/40 transition-colors"
          >
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div>
                <div className="text-[10px] font-black uppercase tracking-widest text-muted">
                  {entry.poolScope} pool · {entry.entryStatus}
                </div>
                <div className="font-black text-text">{entry.poolTitle}</div>
                <div className="text-xs text-muted mt-1">
                  {entry.matchLabel} · {entry.campLabel}
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2 min-w-[220px]">
                <MiniMetric
                  label="Staked"
                  value={<FETDisplay amount={entry.stakeAmount} />}
                />
                <MiniMetric
                  label="Payout"
                  value={<FETDisplay amount={entry.payoutFet} />}
                />
              </div>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

function CreatePoolPanel({
  matches,
  defaultMatchId = "",
  onCreated,
}: {
  matches: Match[];
  defaultMatchId?: string;
  onCreated: () => void;
}) {
  const [matchId, setMatchId] = useState(defaultMatchId);
  const [venueId, setVenueId] = useState("");
  const [title, setTitle] = useState("");
  const [stakeMin, setStakeMin] = useState(5);
  const [stakeMax, setStakeMax] = useState(50);
  const [creating, setCreating] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  useEffect(() => {
    setMatchId(defaultMatchId);
  }, [defaultMatchId]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!matchId) return;
    if (!venueId.trim()) {
      setResult("Choose the linked venue before creating a pool.");
      return;
    }

    setCreating(true);
    setResult(null);
    const response = await api.createPool({
      matchId,
      scope: "venue",
      title,
      stakeMinFet: Math.max(1, stakeMin),
      stakeMaxFet: Math.max(Math.max(1, stakeMin), stakeMax),
      venueId: venueId.trim(),
      visibility: "shareable",
    });
    setCreating(false);

    if (!response.success) {
      setResult(response.error ?? "Could not create pool.");
      return;
    }

    const endorsement =
      response.endorsementStatus === "pending"
        ? " Pending venue endorsement before guests can join."
        : "";
    setResult(
      response.status === "existing_pool"
        ? `A venue pool already exists. ${response.shareUrl ?? ""}`.trim()
        : `Pool created. ${response.shareUrl ?? ""}${endorsement}`.trim(),
    );
    setTitle("");
    onCreated();
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="rounded-3xl border border-border bg-surface2 p-5 space-y-4"
    >
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-accent">
            <Plus size={18} />
            <span className="text-[10px] font-black uppercase tracking-widest">
              Create Pool
            </span>
          </div>
          <h2 className="font-display text-xl text-text mt-1">
            Venue-linked Match Pool
          </h2>
          <p className="text-sm text-muted mt-1">
            Choose a curated match, linked venue, FET stake bounds, and
            home/draw/away camps, then share the generated link.
          </p>
        </div>
      </div>

      <div className="grid gap-3 md:grid-cols-2">
        <label className="grid gap-1">
          <span className="text-[10px] font-black uppercase tracking-widest text-muted">
            Match
          </span>
          <select
            className="rounded-xl border border-border bg-surface3 px-3 py-3 text-sm font-bold text-text"
            value={matchId}
            onChange={(event) => setMatchId(event.target.value)}
            required
          >
            <option value="">Select match</option>
            {matches.map((item) => (
              <option key={item.id} value={item.id}>
                {item.homeTeam} vs {item.awayTeam} · {item.kickoffLabel}
              </option>
            ))}
          </select>
        </label>

        <label className="grid gap-1">
          <span className="text-[10px] font-black uppercase tracking-widest text-muted">
            Venue ID
          </span>
          <input
            className="rounded-xl border border-border bg-surface3 px-3 py-3 text-sm font-bold text-text"
            value={venueId}
            onChange={(event) => setVenueId(event.target.value)}
            placeholder="Venue UUID from QR/table context"
            required
          />
        </label>
      </div>

      <div className="grid gap-3 md:grid-cols-[1fr_120px_120px]">
        <input
          className="rounded-xl border border-border bg-surface3 px-3 py-3 text-sm font-bold text-text"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="Pool title"
          maxLength={120}
        />
        <input
          className="rounded-xl border border-border bg-surface3 px-3 py-3 text-sm font-bold text-text"
          type="number"
          min={1}
          value={stakeMin}
          onChange={(event) => setStakeMin(Number(event.target.value))}
          aria-label="Minimum stake"
        />
        <input
          className="rounded-xl border border-border bg-surface3 px-3 py-3 text-sm font-bold text-text"
          type="number"
          min={stakeMin}
          value={stakeMax}
          onChange={(event) => setStakeMax(Number(event.target.value))}
          aria-label="Maximum stake"
        />
      </div>

      <div className="grid grid-cols-3 gap-2">
        <MiniMetric label="Camp" value="Team A" />
        <MiniMetric label="Camp" value="Draw" />
        <MiniMetric label="Camp" value="Team B" />
      </div>

      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <button
          type="submit"
          disabled={creating || !matchId || !venueId.trim()}
          className="h-12 rounded-2xl bg-accent2 px-5 font-black text-darkBg disabled:opacity-50 flex items-center justify-center gap-2"
        >
          {creating ? (
            <Loader2 size={18} className="animate-spin" />
          ) : (
            <Share2 size={18} />
          )}
          Create and Generate Share Card
        </button>
        {result && (
          <div className="flex items-center gap-2 text-sm text-muted min-w-0">
            <Copy size={16} className="shrink-0" />
            <span className="truncate">{result}</span>
          </div>
        )}
      </div>
    </form>
  );
}

function MiniMetric({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-xl border border-border bg-surface3 p-3">
      <div className="text-[10px] font-black uppercase tracking-widest text-muted">
        {label}
      </div>
      <div className="mt-1 text-sm font-black text-text">{value}</div>
    </div>
  );
}
