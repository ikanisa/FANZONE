import React, { useState } from "react";
import {
  AlertCircle,
  CalendarClock,
  Copy,
  Image,
  Loader2,
  Plus,
  Trophy,
  Users,
  Wallet,
} from "lucide-react";
import { safeHref } from "@fanzone/core";
import { useVenue } from "../../hooks/useVenueContext";
import {
  createVenueOfficialPool,
  endorseVenuePool,
  generateVenuePoolSocialCard,
  rejectVenuePool,
  useVenuePoolMatchOptions,
  useVenuePools,
} from "../../hooks/useVenuePools";

function formatKickoff(value: string | null) {
  if (!value) return "Kickoff not set";
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export const VenuePoolsPage: React.FC = () => {
  const { venue, member } = useVenue();
  const { pools, loading, error, refresh } = useVenuePools(venue?.id);
  const matchOptions = useVenuePoolMatchOptions(venue?.id);
  const [selectedMatchId, setSelectedMatchId] = useState("");
  const [title, setTitle] = useState("");
  const [stakeMin, setStakeMin] = useState("5");
  const [stakeMax, setStakeMax] = useState("50");
  const [creatorReward, setCreatorReward] = useState("1");
  const [barStake, setBarStake] = useState("0");
  const [saving, setSaving] = useState(false);
  const [generatingPoolId, setGeneratingPoolId] = useState<string | null>(null);
  const [reviewingPoolId, setReviewingPoolId] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const canCreateOfficialPool =
    member?.role === "owner" || member?.role === "manager";

  async function handleCreatePool(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!venue?.id || !selectedMatchId) return;

    setSaving(true);
    setNotice(null);
    try {
      await createVenueOfficialPool({
        venueId: venue.id,
        matchId: selectedMatchId,
        title,
        entryFeeFet: Math.max(1, Number(stakeMin) || 1),
        stakeMinFet: Math.max(1, Number(stakeMin) || 1),
        stakeMaxFet: Math.max(
          Math.max(1, Number(stakeMin) || 1),
          Number(stakeMax) || 1,
        ),
        creatorRewardFet: Math.max(0, Number(creatorReward) || 0),
        barStakeFet: Math.max(0, Number(barStake) || 0),
      });
      setSelectedMatchId("");
      setTitle("");
      setBarStake("0");
      setNotice("Official venue pool created.");
      refresh();
      matchOptions.refresh();
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not create official pool.",
      );
    } finally {
      setSaving(false);
    }
  }

  async function handleGenerateSocialCard(poolId: string) {
    setGeneratingPoolId(poolId);
    setNotice(null);
    try {
      await generateVenuePoolSocialCard(poolId);
      setNotice("Social card generated.");
      refresh();
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not generate social card.",
      );
    } finally {
      setGeneratingPoolId(null);
    }
  }

  async function handleEndorsePool(poolId: string) {
    if (!venue?.id) return;
    setReviewingPoolId(poolId);
    setNotice(null);
    try {
      await endorseVenuePool(poolId, venue.id);
      setNotice("Venue pool endorsed and opened.");
      refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Could not endorse pool.");
    } finally {
      setReviewingPoolId(null);
    }
  }

  async function handleRejectPool(poolId: string) {
    if (!venue?.id) return;
    setReviewingPoolId(poolId);
    setNotice(null);
    try {
      await rejectVenuePool(poolId, venue.id, "Rejected from venue dashboard");
      setNotice("Venue pool rejected.");
      refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Could not reject pool.");
    } finally {
      setReviewingPoolId(null);
    }
  }

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <Loader2 className="animate-spin text-primary" size={48} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-danger">
        <AlertCircle size={48} />
        <p className="mt-4 font-bold">Failed to load venue pools: {error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Pools</h1>
          <p className="text-textSecondary font-medium mt-1">
            Official venue-linked FET pools with live members, pooled FET
            totals, and share links.
          </p>
        </div>
        <div className="ops-panel px-4 py-2 flex items-center gap-2 text-sm font-bold w-fit">
          <Trophy size={16} />
          {pools.filter((pool) => pool.status === "open").length} open
        </div>
      </div>

      {notice && (
        <div className="bg-white border border-border rounded-2xl px-5 py-4 font-bold text-sm">
          {notice}
        </div>
      )}

      {canCreateOfficialPool && (
        <form onSubmit={handleCreatePool} className="ops-card p-6 space-y-5">
          <div className="flex flex-col gap-2 md:flex-row md:items-start md:justify-between">
            <div>
              <h2 className="font-black text-xl">Create Official Venue Pool</h2>
              <p className="text-textSecondary font-medium text-sm mt-1">
                Choose an admin-curated fixture. The backend enforces one
                official pool per venue and match.
              </p>
            </div>
            <button
              className="btn btn-primary"
              type="submit"
              disabled={saving || !selectedMatchId}
            >
              {saving ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <Plus size={16} />
              )}
              Create Pool
            </button>
          </div>

          <div className="grid grid-cols-1 xl:grid-cols-[1.4fr_1fr_110px_110px_130px_130px] gap-3">
            <select
              className="input"
              value={selectedMatchId}
              onChange={(event) => setSelectedMatchId(event.target.value)}
              disabled={matchOptions.loading}
              required
            >
              <option value="">
                {matchOptions.loading
                  ? "Loading curated matches..."
                  : "Select curated match"}
              </option>
              {matchOptions.options.map((option) => (
                <option
                  key={`${option.match_id}-${option.venue_id ?? "global"}`}
                  value={option.match_id}
                  disabled={!!option.official_pool_id}
                >
                  {option.match_label} ·{" "}
                  {option.competition_name ?? "Competition"} ·{" "}
                  {formatKickoff(option.kickoff_at)}
                  {option.official_pool_id ? " · official pool exists" : ""}
                </option>
              ))}
            </select>
            <input
              className="input"
              placeholder="Pool title, optional"
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              maxLength={120}
            />
            <input
              className="input"
              type="number"
              min={1}
              value={stakeMin}
              onChange={(event) => setStakeMin(event.target.value)}
              aria-label="Minimum stake FET"
              placeholder="Min stake"
            />
            <input
              className="input"
              type="number"
              min={Number(stakeMin) || 1}
              value={stakeMax}
              onChange={(event) => setStakeMax(event.target.value)}
              aria-label="Maximum stake FET"
              placeholder="Max stake"
            />
            <input
              className="input"
              type="number"
              min={0}
              value={creatorReward}
              onChange={(event) => setCreatorReward(event.target.value)}
              aria-label="Creator reward FET"
              placeholder="Invite reward"
            />
            <input
              className="input"
              type="number"
              min={0}
              value={barStake}
              onChange={(event) => setBarStake(event.target.value)}
              aria-label="Bar stake FET"
              placeholder="Bar stake"
            />
          </div>

          {matchOptions.error && (
            <p className="text-danger font-bold text-sm">
              {matchOptions.error}
            </p>
          )}
        </form>
      )}

      {pools.length === 0 ? (
        <div className="ops-card p-10 text-center">
          <Trophy className="mx-auto text-textSecondary" size={40} />
          <h2 className="font-black text-xl mt-4">No venue pools configured</h2>
          <p className="text-textSecondary font-medium mt-2 max-w-xl mx-auto">
            Venue pools appear here after an admin or venue manager creates an
            official pool for a curated match.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          {pools.map((pool) => (
            <article key={pool.id} className="ops-card overflow-hidden">
              <div className="p-6 border-b border-border flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                <div>
                  <div className="flex flex-wrap items-center gap-2 mb-2">
                    <span className="px-3 py-1 rounded-full bg-surface2 text-xs font-black uppercase tracking-widest">
                      {pool.status}
                    </span>
                    {pool.isOfficial && (
                      <span className="px-3 py-1 rounded-full bg-accent/20 text-xs font-black uppercase tracking-widest">
                        Official
                      </span>
                    )}
                    {pool.endorsementStatus === "pending" && (
                      <span className="px-3 py-1 rounded-full bg-warning/20 text-xs font-black uppercase tracking-widest">
                        Needs Endorsement
                      </span>
                    )}
                    {pool.endorsementStatus === "rejected" && (
                      <span className="px-3 py-1 rounded-full bg-danger/20 text-xs font-black uppercase tracking-widest">
                        Rejected
                      </span>
                    )}
                    {pool.status === "settled" && (
                      <span className="px-3 py-1 rounded-full bg-success/20 text-xs font-black uppercase tracking-widest">
                        Settled
                      </span>
                    )}
                  </div>
                  <h2 className="font-black text-2xl tracking-tight">
                    {pool.matchName}
                  </h2>
                  <p className="text-sm text-textSecondary font-medium mt-1">
                    {pool.competitionName ?? "Curated match"}
                  </p>
                </div>
                <div className="text-left md:text-right">
                  <p className="text-xs font-black text-textSecondary uppercase tracking-widest">
                    Entry
                  </p>
                  <p className="font-black text-xl">
                    {pool.stakeMinFet} - {pool.stakeMaxFet} FET
                  </p>
                </div>
              </div>

              <div className="p-6 grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="bg-surface2 rounded-2xl p-4">
                  <Users size={18} className="text-primary mb-3" />
                  <p className="text-xs font-black text-textSecondary uppercase tracking-widest">
                    Members
                  </p>
                  <p className="font-black text-2xl">{pool.totalMembers}</p>
                </div>
                <div className="bg-surface2 rounded-2xl p-4">
                  <Wallet size={18} className="text-primary mb-3" />
                  <p className="text-xs font-black text-textSecondary uppercase tracking-widest">
                    Pooled
                  </p>
                  <p className="font-black text-2xl">
                    {pool.totalStakedFet} FET
                  </p>
                </div>
                <div className="bg-surface2 rounded-2xl p-4">
                  <CalendarClock size={18} className="text-primary mb-3" />
                  <p className="text-xs font-black text-textSecondary uppercase tracking-widest">
                    Kickoff
                  </p>
                  <p className="font-black text-sm">
                    {formatKickoff(pool.kickoffAt)}
                  </p>
                </div>
                <div className="bg-surface2 rounded-2xl p-4">
                  <Wallet size={18} className="text-primary mb-3" />
                  <p className="text-xs font-black text-textSecondary uppercase tracking-widest">
                    Bar stake
                  </p>
                  <p className="font-black text-2xl">{pool.barStakeFet} FET</p>
                </div>
              </div>

              <div className="px-6 pb-6">
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {pool.camps.map((camp) => (
                    <div
                      key={camp.id}
                      className={`border rounded-xl p-4 ${
                        camp.isWinningCamp
                          ? "border-success/30 bg-success/10"
                          : "border-border"
                      }`}
                    >
                      <p className="font-black">{camp.label}</p>
                      <p className="text-xs text-textSecondary font-bold mt-2">
                        {camp.memberCount} members · {camp.totalStakedFet} FET
                        pooled
                      </p>
                      {camp.isWinningCamp && (
                        <p className="text-[10px] text-success font-black uppercase tracking-widest mt-3">
                          Winning camp
                        </p>
                      )}
                    </div>
                  ))}
                </div>

                {pool.status === "settled" && (
                  <div className="mt-5 rounded-2xl bg-success/10 border border-success/20 p-4">
                    <p className="text-[10px] font-black text-success uppercase tracking-widest">
                      Settlement result
                    </p>
                    <p className="text-sm font-bold text-text mt-1">
                      Settled{" "}
                      {pool.settledAt
                        ? formatKickoff(pool.settledAt)
                        : "after final result"}
                      .
                    </p>
                  </div>
                )}

                {pool.shareUrl && (
                  <div className="mt-5 flex items-center gap-3 rounded-2xl border border-border bg-surface2 p-4">
                    <Copy size={18} className="text-textSecondary shrink-0" />
                    <p className="font-bold text-sm truncate">
                      {pool.shareUrl}
                    </p>
                  </div>
                )}

                <div className="mt-5 flex flex-wrap gap-3">
                  {pool.endorsementStatus === "pending" &&
                    canCreateOfficialPool && (
                      <>
                        <button
                          type="button"
                          onClick={() => void handleEndorsePool(pool.id)}
                          disabled={reviewingPoolId === pool.id}
                          className="btn btn-primary"
                        >
                          {reviewingPoolId === pool.id ? (
                            <Loader2 size={16} className="animate-spin" />
                          ) : (
                            <Trophy size={16} />
                          )}
                          Endorse
                        </button>
                        <button
                          type="button"
                          onClick={() => void handleRejectPool(pool.id)}
                          disabled={reviewingPoolId === pool.id}
                          className="btn bg-danger text-white"
                        >
                          Reject
                        </button>
                      </>
                    )}
                  <button
                    type="button"
                    onClick={() => void handleGenerateSocialCard(pool.id)}
                    disabled={generatingPoolId === pool.id}
                    className="btn bg-accent2 text-white"
                  >
                    {generatingPoolId === pool.id ? (
                      <Loader2 size={16} className="animate-spin" />
                    ) : (
                      <Image size={16} />
                    )}
                    {pool.socialCardUrl
                      ? "Refresh Social Card"
                      : "Generate Social Card"}
                  </button>
                  {safeHref(pool.socialCardUrl) && (
                    <a
                      href={safeHref(pool.socialCardUrl) ?? undefined}
                      target="_blank"
                      rel="noreferrer"
                      className="btn btn-secondary"
                    >
                      Open Card
                    </a>
                  )}
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
};
