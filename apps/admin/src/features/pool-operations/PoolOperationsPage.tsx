import {
  AlertTriangle,
  Image,
  Loader2,
  Play,
  RefreshCcw,
  Search,
  Share2,
  ShieldCheck,
  Trophy,
  Users,
  Wallet,
  XCircle,
} from "lucide-react";
import { useMemo, useState } from "react";
import { safeHref } from "@fanzone/core";

import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import {
  EmptyState,
  ErrorState,
  LoadingState,
} from "../../components/ui/StateViews";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDateTime, formatFET } from "../../lib/formatters";
import {
  useGeneratePoolSocialCard,
  useCancelRefundPool,
  usePoolOperationsKpis,
  usePoolOperationsQueue,
  useRetryPoolSettlement,
  useRunPoolSettlement,
  type PoolOperationsRow,
} from "./usePoolOperations";

function formatAge(minutes: number) {
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 48) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
}

function settlementLabel(row: PoolOperationsRow) {
  if (row.settlement_status) return row.settlement_status;
  if (row.needs_settlement) return "pending";
  return "not due";
}

export function PoolOperationsPage({
  title = "Pools",
  subtitle = "Pool health, automated settlements, failed retries, social cards, and invite rewards",
}: {
  title?: string;
  subtitle?: string;
}) {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [scopeFilter, setScopeFilter] = useState("all");
  const [refundTarget, setRefundTarget] = useState<PoolOperationsRow | null>(
    null,
  );
  const [refundReason, setRefundReason] = useState("");
  const [retryTarget, setRetryTarget] = useState<PoolOperationsRow | null>(
    null,
  );
  const [retryReason, setRetryReason] = useState("");

  const {
    data: kpis,
    isLoading: kpisLoading,
    refetch: refetchKpis,
  } = usePoolOperationsKpis();
  const {
    data: queue,
    isLoading: queueLoading,
    error: queueError,
    refetch: refetchQueue,
  } = usePoolOperationsQueue();
  const runSettlement = useRunPoolSettlement();
  const generateSocialCard = useGeneratePoolSocialCard();
  const cancelRefundPool = useCancelRefundPool();
  const retrySettlement = useRetryPoolSettlement();

  const filteredQueue = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (queue ?? []).filter((row) => {
      if (
        statusFilter !== "all" &&
        row.pool_status !== statusFilter &&
        settlementLabel(row) !== statusFilter
      )
        return false;
      if (scopeFilter !== "all" && row.scope !== scopeFilter) return false;
      if (!q) return true;
      return [
        row.title,
        row.match_label,
        row.competition_name ?? "",
        row.venue_name ?? "",
        row.country_code ?? "",
        row.match_id,
        row.pool_id,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [queue, scopeFilter, search, statusFilter]);

  async function refreshAll() {
    await Promise.all([refetchKpis(), refetchQueue()]);
  }

  async function handleRunSettlement() {
    await runSettlement.mutateAsync({ p_limit: 50 });
    await refreshAll();
  }

  async function handleGenerateCard(poolId: string) {
    await generateSocialCard.mutateAsync({ poolId });
    await refreshAll();
  }

  async function handleCancelRefund() {
    if (!refundTarget) return;
    await cancelRefundPool.mutateAsync({
      p_pool_id: refundTarget.pool_id,
      p_reason: refundReason.trim(),
    });
    setRefundTarget(null);
    setRefundReason("");
    await refreshAll();
  }

  async function handleRetrySettlement() {
    if (!retryTarget) return;
    await retrySettlement.mutateAsync({
      p_pool_id: retryTarget.pool_id,
      p_reason: retryReason.trim(),
    });
    setRetryTarget(null);
    setRetryReason("");
    await refreshAll();
  }

  return (
    <div>
      <PageHeader title={title} subtitle={subtitle} />

      <div className="flex flex-wrap gap-3 mb-6">
        <button
          className="btn btn-primary"
          type="button"
          disabled={runSettlement.isPending}
          onClick={() => void handleRunSettlement()}
        >
          {runSettlement.isPending ? (
            <Loader2 size={16} className="animate-spin" />
          ) : (
            <Play size={16} />
          )}
          Run Settlement
        </button>
        <button
          className="btn btn-ghost"
          type="button"
          onClick={() => void refreshAll()}
        >
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      {kpisLoading ? (
        <LoadingState lines={2} />
      ) : (
        kpis && (
          <div className="grid grid-4 gap-4 mb-6">
            <KpiCard
              label="Open Pools"
              value={kpis.openPools}
              icon={<Trophy size={18} />}
            />
            <KpiCard
              label="Due Settlements"
              value={kpis.pendingFinalPools}
              icon={<Play size={18} />}
            />
            <KpiCard
              label="Failed Settlements"
              value={kpis.failedSettlements}
              icon={<AlertTriangle size={18} />}
            />
            <KpiCard
              label="Stale Settling"
              value={kpis.staleSettlingPools}
              icon={<ShieldCheck size={18} />}
            />
            <KpiCard
              label="Open Pooled FET"
              value={kpis.totalOpenStakeFet}
              format="fet"
              icon={<Wallet size={18} />}
            />
            <KpiCard
              label="Settled 24h"
              value={kpis.settled24h}
              icon={<ShieldCheck size={18} />}
            />
            <KpiCard
              label="Missing Cards"
              value={kpis.socialCardsMissing}
              icon={<Image size={18} />}
            />
            <KpiCard
              label="Invite Rewards 7d"
              value={kpis.inviteRewards7d}
              format="fet"
              icon={<Users size={18} />}
            />
          </div>
        )
      )}

      <div className="filter-bar mb-4">
        <div style={{ position: "relative", maxWidth: 340 }}>
          <Search
            size={16}
            style={{
              position: "absolute",
              left: 12,
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--fz-muted-2)",
            }}
          />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search pool, match, country, venue..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </div>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={scopeFilter}
          onChange={(event) => setScopeFilter(event.target.value)}
        >
          <option value="all">All scopes</option>
          <option value="global">Global</option>
          <option value="country">Country</option>
          <option value="venue">Venue</option>
        </select>
        <select
          className="input select"
          style={{ maxWidth: 200 }}
          value={statusFilter}
          onChange={(event) => setStatusFilter(event.target.value)}
        >
          <option value="all">All statuses</option>
          <option value="open">Open</option>
          <option value="locked">Locked</option>
          <option value="live">Live</option>
          <option value="settling">Settling</option>
          <option value="failed">Failed settlement</option>
          <option value="pending">Pending settlement</option>
        </select>
      </div>

      {queueLoading ? (
        <LoadingState lines={8} />
      ) : queueError ? (
        <ErrorState onRetry={() => refetchQueue()} />
      ) : filteredQueue.length === 0 ? (
        <EmptyState title="No pool operations need attention" />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Pool</th>
                <th>Match</th>
                <th>Status</th>
                <th>Members</th>
                <th>Pooled</th>
                <th>Camp Distribution</th>
                <th>Settlement</th>
                <th>Social Card</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredQueue.map((row) => {
                const socialCardUrl = safeHref(row.social_card_url);
                return (
                  <tr key={row.pool_id}>
                    <td>
                      <div className="font-medium">{row.title}</div>
                      <div className="text-xs text-muted">
                        {row.scope}
                        {row.country_code ? ` · ${row.country_code}` : ""}
                        {row.venue_name ? ` · ${row.venue_name}` : ""}
                        {" · "}
                        {formatAge(row.age_minutes)}
                      </div>
                    </td>
                    <td>
                      <div className="font-medium">{row.match_label}</div>
                      <div className="text-xs text-muted">
                        {row.competition_name ?? "Competition"}
                        {row.kickoff_at
                          ? ` · ${formatDateTime(row.kickoff_at)}`
                          : ""}
                      </div>
                    </td>
                    <td>
                      <StatusBadge status={row.pool_status} />
                    </td>
                    <td>{row.total_members}</td>
                    <td>{formatFET(row.total_staked_fet)}</td>
                    <td>
                      <div className="flex flex-col gap-1">
                        {(row.camps ?? []).slice(0, 3).map((camp) => (
                          <span key={camp.id} className="text-xs">
                            {camp.label}: {camp.member_count ?? 0} /{" "}
                            {formatFET(camp.total_staked_fet ?? 0)}
                          </span>
                        ))}
                        {(row.camps ?? []).length === 0 && (
                          <span className="text-xs text-muted">No entries</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <div className="flex flex-col gap-1">
                        <StatusBadge status={settlementLabel(row)} />
                        {row.settlement_error && (
                          <span className="text-xs text-danger">
                            {row.settlement_error}
                          </span>
                        )}
                        {row.result_code && (
                          <span className="text-xs text-muted">
                            Result {row.result_code}
                          </span>
                        )}
                      </div>
                    </td>
                    <td>
                      {socialCardUrl ? (
                        <a
                          className="btn btn-ghost btn-sm"
                          href={socialCardUrl}
                          target="_blank"
                          rel="noreferrer"
                        >
                          <Share2 size={14} />
                          Open
                        </a>
                      ) : (
                        <StatusBadge status="missing" />
                      )}
                    </td>
                    <td className="cell-actions">
                      {row.settlement_status === "failed" && (
                        <button
                          className="btn btn-ghost btn-sm"
                          type="button"
                          disabled={retrySettlement.isPending}
                          onClick={() => setRetryTarget(row)}
                        >
                          <RefreshCcw size={14} />
                          Retry
                        </button>
                      )}
                      <button
                        className="btn btn-ghost btn-sm"
                        type="button"
                        disabled={generateSocialCard.isPending}
                        onClick={() => void handleGenerateCard(row.pool_id)}
                      >
                        {generateSocialCard.isPending ? (
                          <Loader2 size={14} className="animate-spin" />
                        ) : (
                          <Image size={14} />
                        )}
                        Generate Card
                      </button>
                      {row.pool_status !== "settled" &&
                        row.pool_status !== "cancelled" && (
                          <button
                            className="btn btn-ghost btn-sm text-error"
                            type="button"
                            disabled={cancelRefundPool.isPending}
                            onClick={() => setRefundTarget(row)}
                          >
                            <XCircle size={14} />
                            Cancel/Refund
                          </button>
                        )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {refundTarget && (
        <div
          className="modal-overlay"
          onClick={() => {
            setRefundTarget(null);
            setRefundReason("");
          }}
        >
          <div
            className="modal-panel"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="flex items-start gap-4 mb-4">
              <AlertTriangle
                size={24}
                style={{ color: "var(--fz-error)", flexShrink: 0 }}
              />
              <div>
                <h3 className="text-md font-semibold mb-1">
                  Cancel and Refund Pool
                </h3>
                <p className="text-sm text-muted">
                  {refundTarget.title} will be cancelled and active entries
                  refunded. This action is audited.
                </p>
              </div>
            </div>
            <div className="field-group mb-4">
              <label className="label">Reason</label>
              <textarea
                className="input"
                rows={3}
                value={refundReason}
                onChange={(event) => setRefundReason(event.target.value)}
              />
            </div>
            <div className="flex justify-end gap-3">
              <button
                className="btn btn-secondary"
                onClick={() => {
                  setRefundTarget(null);
                  setRefundReason("");
                }}
              >
                Cancel
              </button>
              <button
                className="btn btn-danger"
                disabled={
                  refundReason.trim().length < 8 || cancelRefundPool.isPending
                }
                onClick={() => void handleCancelRefund()}
              >
                Cancel and Refund
              </button>
            </div>
          </div>
        </div>
      )}

      {retryTarget && (
        <div
          className="modal-overlay"
          onClick={() => {
            setRetryTarget(null);
            setRetryReason("");
          }}
        >
          <div
            className="modal-panel"
            onClick={(event) => event.stopPropagation()}
          >
            <h3 className="text-md font-semibold mb-1">Retry Settlement</h3>
            <p className="text-sm text-muted mb-4">
              Retry {retryTarget.title} with the admin settlement idempotency
              key.
            </p>
            <div className="field-group mb-4">
              <label className="label">Reason</label>
              <textarea
                className="input"
                rows={3}
                value={retryReason}
                onChange={(event) => setRetryReason(event.target.value)}
              />
            </div>
            <div className="flex justify-end gap-3">
              <button
                className="btn btn-secondary"
                onClick={() => {
                  setRetryTarget(null);
                  setRetryReason("");
                }}
              >
                Cancel
              </button>
              <button
                className="btn btn-primary"
                disabled={
                  retryReason.trim().length < 8 || retrySettlement.isPending
                }
                onClick={() => void handleRetrySettlement()}
              >
                Retry Settlement
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
