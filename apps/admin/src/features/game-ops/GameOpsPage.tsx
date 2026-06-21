import { useMemo, useState, type FormEvent } from "react";
import {
  CalendarDays,
  CheckCircle2,
  Gamepad2,
  RefreshCw,
  Shuffle,
  Sparkles,
  XCircle,
} from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import {
  EmptyState,
  ErrorState,
  LoadingState,
} from "../../components/ui/StateViews";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDateTime } from "../../lib/formatters";
import {
  useAssignWeeklyGamePacks,
  useCreateGameContentRun,
  useGameContentPacks,
  useGameContentRuns,
  useOverrideVenueGameAssignment,
  useReviewGameContentPack,
  useVenueGameAssignments,
} from "./useGameOps";

const supportedMarkets = ["MT", "RW"];

function currentWeekStart() {
  const date = new Date();
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date.toISOString().slice(0, 10);
}

function toMarketList(values: string[]) {
  const normalized = values
    .map((value) => value.trim().toUpperCase())
    .filter((value) => supportedMarkets.includes(value));
  return normalized.length > 0 ? Array.from(new Set(normalized)) : supportedMarkets;
}

export function GameOpsPage() {
  const [weekStart, setWeekStart] = useState(currentWeekStart());
  const [markets, setMarkets] = useState<string[]>(supportedMarkets);
  const [prompt, setPrompt] = useState(
    "Generate sports-bar friendly FANZONE game packs for Malta and Rwanda. Keep all content free-to-play, hospitality-safe, and family-safe.",
  );
  const [assignmentSeed, setAssignmentSeed] = useState("");
  const [packsPerVenue, setPacksPerVenue] = useState("3");
  const [reviewNotes, setReviewNotes] = useState<Record<string, string>>({});

  const {
    data: runs = [],
    isLoading: runsLoading,
    error: runsError,
    refetch: refetchRuns,
  } = useGameContentRuns();
  const {
    data: packs = [],
    isLoading: packsLoading,
    error: packsError,
    refetch: refetchPacks,
  } = useGameContentPacks({ weekStart });
  const {
    data: assignments = [],
    isLoading: assignmentsLoading,
    error: assignmentsError,
    refetch: refetchAssignments,
  } = useVenueGameAssignments({ weekStart });

  const createRun = useCreateGameContentRun();
  const reviewPack = useReviewGameContentPack();
  const assignPacks = useAssignWeeklyGamePacks();
  const overrideAssignment = useOverrideVenueGameAssignment();

  const counts = useMemo(() => {
    const approved = packs.filter((pack) => pack.status === "approved").length;
    const pending = packs.filter(
      (pack) => pack.status === "generated_pending_review",
    ).length;
    return {
      runs: runs.length,
      packs: packs.length,
      approved,
      pending,
      assignments: assignments.length,
    };
  }, [assignments.length, packs, runs.length]);

  async function handleCreateRun(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await createRun.mutateAsync({
      p_week_start: weekStart,
      p_market_codes: toMarketList(markets),
      p_target_pack_count: 100,
      p_questions_per_pack: 20,
      p_generation_model: "gemini-2.5-flash",
      p_prompt: prompt.trim() || null,
      p_metadata: {
        requested_from: "admin_game_ops",
        review_required: true,
      },
    });
  }

  async function handleAssign(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await assignPacks.mutateAsync({
      p_week_start: weekStart,
      p_market_codes: toMarketList(markets),
      p_packs_per_venue: Number(packsPerVenue) || 3,
      p_seed: assignmentSeed.trim() || null,
    });
  }

  function toggleMarket(market: string) {
    setMarkets((current) => {
      if (current.includes(market)) {
        const next = current.filter((value) => value !== market);
        return next.length > 0 ? next : current;
      }
      return [...current, market];
    });
  }

  return (
    <div>
      <PageHeader
        title="Game Ops"
        subtitle="Weekly AI game pack review, approval, and random venue assignment for Malta and Rwanda."
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Runs" value={counts.runs} icon={<Sparkles size={18} />} />
        <KpiCard label="Packs" value={counts.packs} icon={<Gamepad2 size={18} />} />
        <KpiCard label="Approved" value={counts.approved} icon={<CheckCircle2 size={18} />} />
        <KpiCard label="Assignments" value={counts.assignments} icon={<Shuffle size={18} />} />
      </div>

      <div className="data-table-container mb-4" style={{ padding: 16 }}>
        <div className="flex items-center justify-between gap-3 mb-4">
          <div>
            <h2 className="font-semibold">Weekly Controls</h2>
            <p className="text-sm text-muted">
              Generated content stays pending until an admin approves each pack.
            </p>
          </div>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => {
              refetchRuns();
              refetchPacks();
              refetchAssignments();
            }}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>

        <div className="filter-bar">
          <label className="flex items-center gap-2 text-sm">
            <CalendarDays size={16} />
            <input
              className="input"
              type="date"
              value={weekStart}
              onChange={(event) => setWeekStart(event.target.value)}
              style={{ maxWidth: 180 }}
            />
          </label>
          {supportedMarkets.map((market) => (
            <label key={market} className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={markets.includes(market)}
                onChange={() => toggleMarket(market)}
              />
              {market === "MT" ? "Malta" : "Rwanda"}
            </label>
          ))}
        </div>

        <div className="grid grid-2 gap-4 mt-4">
          <form onSubmit={handleCreateRun}>
            <h3 className="font-semibold mb-2">Queue AI Generation</h3>
            <textarea
              className="input"
              value={prompt}
              onChange={(event) => setPrompt(event.target.value)}
              rows={5}
            />
            <div className="flex items-center justify-between gap-3 mt-3">
              <span className="text-sm text-muted">Target: 100 packs, 20 questions each.</span>
              <button
                className="btn btn-primary"
                type="submit"
                disabled={createRun.isPending}
              >
                <Sparkles size={16} /> Queue Run
              </button>
            </div>
          </form>

          <form onSubmit={handleAssign}>
            <h3 className="font-semibold mb-2">Assign Approved Packs</h3>
            <div className="filter-bar">
              <input
                className="input"
                type="number"
                min={1}
                max={10}
                value={packsPerVenue}
                onChange={(event) => setPacksPerVenue(event.target.value)}
                style={{ maxWidth: 180 }}
              />
              <input
                className="input"
                placeholder="Optional deterministic seed"
                value={assignmentSeed}
                onChange={(event) => setAssignmentSeed(event.target.value)}
              />
            </div>
            <div className="flex items-center justify-between gap-3 mt-3">
              <span className="text-sm text-muted">
                Uses only approved packs matching each venue market.
              </span>
              <button
                className="btn btn-primary"
                type="submit"
                disabled={assignPacks.isPending}
              >
                <Shuffle size={16} /> Assign
              </button>
            </div>
          </form>
        </div>
      </div>

      <div className="grid grid-2 gap-4 mb-4">
        <section className="data-table-container">
          <div className="p-4 border-bottom">
            <h2 className="font-semibold">Generation Runs</h2>
          </div>
          {runsLoading ? (
            <LoadingState lines={5} />
          ) : runsError ? (
            <ErrorState onRetry={() => refetchRuns()} />
          ) : runs.length === 0 ? (
            <EmptyState
              title="No game runs"
              description="Queue a weekly run before reviewing packs."
            />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Week</th>
                  <th>Markets</th>
                  <th>Status</th>
                  <th>Packs</th>
                  <th>Updated</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id}>
                    <td className="mono text-xs">{run.week_start}</td>
                    <td>{run.market_codes.join(", ")}</td>
                    <td><StatusBadge status={run.status} /></td>
                    <td>{run.approved_pack_count}/{run.generated_pack_count}/{run.target_pack_count}</td>
                    <td className="text-xs text-muted">{formatDateTime(run.updated_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>

        <section className="data-table-container">
          <div className="p-4 border-bottom">
            <h2 className="font-semibold">Venue Assignments</h2>
          </div>
          {assignmentsLoading ? (
            <LoadingState lines={5} />
          ) : assignmentsError ? (
            <ErrorState onRetry={() => refetchAssignments()} />
          ) : assignments.length === 0 ? (
            <EmptyState
              title="No assignments"
              description="Approve packs, then assign them to venues for the selected week."
            />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Venue</th>
                  <th>Pack</th>
                  <th>Rank</th>
                  <th>Status</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {assignments.map((assignment) => (
                  <tr key={assignment.id}>
                    <td>
                      <div className="font-medium">{assignment.venue_name}</div>
                      <div className="text-xs text-muted">{assignment.market_code}</div>
                    </td>
                    <td>
                      <div className="font-medium">{assignment.pack_title}</div>
                      <div className="text-xs text-muted">{assignment.template_name}</div>
                    </td>
                    <td>{assignment.assignment_rank}</td>
                    <td><StatusBadge status={assignment.status} /></td>
                    <td className="cell-actions">
                      <button
                        className="btn btn-ghost btn-sm"
                        type="button"
                        disabled={overrideAssignment.isPending}
                        onClick={() =>
                          overrideAssignment.mutateAsync({
                            p_assignment_id: assignment.id,
                            p_status: "published",
                            p_reason: null,
                          })
                        }
                      >
                        Publish
                      </button>
                      <button
                        className="btn btn-ghost btn-sm"
                        type="button"
                        disabled={overrideAssignment.isPending}
                        onClick={() =>
                          overrideAssignment.mutateAsync({
                            p_assignment_id: assignment.id,
                            p_status: "retired",
                            p_reason: "Retired from Game Ops",
                          })
                        }
                      >
                        Retire
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      </div>

      <section className="data-table-container">
        <div className="p-4 border-bottom flex items-center justify-between gap-3">
          <div>
            <h2 className="font-semibold">Pack Review</h2>
            <p className="text-sm text-muted">
              Pending: {counts.pending}. Approval is required before any venue assignment.
            </p>
          </div>
        </div>

        {packsLoading ? (
          <LoadingState lines={8} />
        ) : packsError ? (
          <ErrorState onRetry={() => refetchPacks()} />
        ) : packs.length === 0 ? (
          <EmptyState
            title="No packs for this week"
            description="Generated packs will appear here after the weekly pipeline writes them."
          />
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Pack</th>
                <th>Market</th>
                <th>Questions</th>
                <th>Status</th>
                <th>Assignments</th>
                <th>Review Notes</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {packs.map((pack) => (
                <tr key={pack.id}>
                  <td>
                    <div className="font-medium">{pack.title}</div>
                    <div className="text-xs text-muted">{pack.template_name}</div>
                  </td>
                  <td>{pack.market_code}</td>
                  <td>{pack.question_count}</td>
                  <td><StatusBadge status={pack.status} /></td>
                  <td>{pack.assignment_count}</td>
                  <td>
                    <input
                      className="input"
                      value={reviewNotes[pack.id] ?? pack.review_notes ?? ""}
                      onChange={(event) =>
                        setReviewNotes((current) => ({
                          ...current,
                          [pack.id]: event.target.value,
                        }))
                      }
                    />
                  </td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      type="button"
                      disabled={reviewPack.isPending}
                      onClick={() =>
                        reviewPack.mutateAsync({
                          p_pack_id: pack.id,
                          p_status: "approved",
                          p_review_notes: reviewNotes[pack.id] ?? pack.review_notes ?? null,
                        })
                      }
                    >
                      <CheckCircle2 size={14} /> Approve
                    </button>
                    <button
                      className="btn btn-ghost btn-sm"
                      type="button"
                      disabled={reviewPack.isPending}
                      onClick={() =>
                        reviewPack.mutateAsync({
                          p_pack_id: pack.id,
                          p_status: "rejected",
                          p_review_notes: reviewNotes[pack.id] ?? pack.review_notes ?? null,
                        })
                      }
                    >
                      <XCircle size={14} /> Reject
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
