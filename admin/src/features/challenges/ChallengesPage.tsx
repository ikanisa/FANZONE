// FANZONE Admin — Challenges (Pools) Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { KpiCard } from '../../components/ui/KpiCard';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';

import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { SettlePoolModal } from './SettlePoolModal';
import { useChallenges, useChallengeEntries, useSettlePool, useVoidPool } from './useChallenges';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatFET, formatDateTime } from '../../lib/formatters';
import { Swords, Users, Coins, AlertTriangle, Search, Flag, Gavel, XCircle, Eye } from 'lucide-react';
import type { Challenge } from '../../types';

export function ChallengesPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState<Challenge | null>(null);

  // Action states
  const [settleTarget, setSettleTarget] = useState<Challenge | null>(null);
  const [voidTarget, setVoidTarget] = useState<Challenge | null>(null);
  const [voidReason, setVoidReason] = useState('');

  // Data
  const { data: result, isLoading, error, refetch } = useChallenges({ page }, { status: statusFilter, search });
  const { data: entries } = useChallengeEntries(selected?.id ?? null);
  const settleMutation = useSettlePool();
  const voidMutation = useVoidPool();
  const { logAction } = useAuditLog();

  const pools = result?.data ?? [];

  const handleSettle = async (homeScore: number, awayScore: number) => {
    if (!settleTarget) return;
    await settleMutation.mutateAsync({
      p_pool_id: settleTarget.id,
      p_official_home_score: homeScore,
      p_official_away_score: awayScore,
    });
    await logAction({
      action: 'settle_pool',
      module: 'challenges',
      targetType: 'challenge',
      targetId: settleTarget.id,
      afterState: { home_score: homeScore, away_score: awayScore },
    });
    setSettleTarget(null);
    setSelected(null);
  };

  const handleVoid = async () => {
    if (!voidTarget) return;
    await voidMutation.mutateAsync({
      p_pool_id: voidTarget.id,
      p_reason: voidReason,
    });
    await logAction({
      action: 'void_pool',
      module: 'challenges',
      targetType: 'challenge',
      targetId: voidTarget.id,
      afterState: { reason: voidReason },
    });
    setVoidTarget(null);
    setVoidReason('');
    setSelected(null);
  };

  // Stats from current data
  const openPools = pools.filter(p => p.status === 'open' || p.status === 'locked');
  const totalParticipants = pools.reduce((s, p) => s + p.total_participants, 0);
  const totalStaked = pools.reduce((s, p) => s + p.total_pool_fet, 0);

  return (
    <div>
      <PageHeader title="Pools" subtitle="Score prediction pools management" />

      {/* KPIs */}
      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Active Pools" value={openPools.length} icon={<Swords size={18} />} />
        <KpiCard label="Total Participants" value={totalParticipants} icon={<Users size={18} />} />
        <KpiCard label="FET Staked" value={totalStaked} format="fet" icon={<Coins size={18} />} />
        <KpiCard label="Flagged" value={pools.filter(p => p.total_pool_fet > 50000).length} icon={<AlertTriangle size={18} />} />
      </div>

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search pools..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="open">Open</option>
          <option value="locked">Locked</option>
          <option value="settled">Settled</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={6} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       pools.length === 0 ? <EmptyState title="No pools found" description="Try adjusting your search or filters." /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Pool</th>
                <th>Match</th>
                <th>Stake</th>
                <th>Pool Total</th>
                <th>Players</th>
                <th>Status</th>
                <th>Lock Time</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {pools.map(p => (
                <tr
                  key={p.id}
                  className={`cursor-pointer ${p.total_pool_fet > 50000 ? 'selected' : ''}`}
                  onClick={() => setSelected(p)}
                >
                  <td className="mono text-xs">{p.id}</td>
                  <td className="font-medium">{p.match_id}</td>
                  <td className="mono">{formatFET(p.stake_fet)}</td>
                  <td className="mono font-semibold">{formatFET(p.total_pool_fet)}</td>
                  <td>{p.total_participants}</td>
                  <td><StatusBadge status={p.status} /></td>
                  <td className="text-muted">{formatDateTime(p.lock_at)}</td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {(p.status === 'open' || p.status === 'locked') && (
                        <>
                          <button
                            className="btn btn-ghost btn-sm text-success"
                            onClick={e => { e.stopPropagation(); setSettleTarget(p); }}
                            title="Settle Pool"
                          >
                            <Gavel size={14} /> Settle
                          </button>
                          <button
                            className="btn btn-ghost btn-sm text-error"
                            onClick={e => { e.stopPropagation(); setVoidTarget(p); }}
                            title="Void Pool"
                          >
                            <XCircle size={14} /> Void
                          </button>
                        </>
                      )}
                      <button
                        className="btn btn-ghost btn-sm"
                        onClick={e => { e.stopPropagation(); setSelected(p); }}
                        title="View Details"
                      >
                        <Eye size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div className="pagination">
            <span>Showing {pools.length} of {result?.count ?? 0} pools</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={pools.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Drawer */}
      <DetailDrawer
        open={!!selected}
        title={`Pool ${selected?.id ?? ''}`}
        subtitle={selected?.match_id}
        onClose={() => setSelected(null)}
        actions={
          selected && (selected.status === 'open' || selected.status === 'locked') ? (
            <>
              <button className="btn btn-ghost btn-sm text-success" onClick={() => setSettleTarget(selected)}>
                <Gavel size={14} /> Settle
              </button>
              <button className="btn btn-ghost btn-sm text-error" onClick={() => setVoidTarget(selected)}>
                <XCircle size={14} /> Void
              </button>
            </>
          ) : undefined
        }
      >
        {selected && (
          <>
            <DrawerSection title="Pool Details">
              <DrawerField label="Match" value={selected.match_id} />
              <DrawerField label="Creator" value={selected.creator_user_id} />
              <DrawerField label="Entry Stake" value={formatFET(selected.stake_fet)} />
              <DrawerField label="Total Pool" value={formatFET(selected.total_pool_fet)} />
              <DrawerField label="Participants" value={selected.total_participants} />
              <DrawerField label="Status" value={<StatusBadge status={selected.status} />} />
              <DrawerField label="Lock Time" value={formatDateTime(selected.lock_at)} />
              {selected.settled_at && <DrawerField label="Settled" value={formatDateTime(selected.settled_at)} />}
              {selected.winner_count !== null && <DrawerField label="Winners" value={selected.winner_count} />}
              {selected.payout_per_winner_fet !== null && <DrawerField label="Payout/Winner" value={formatFET(selected.payout_per_winner_fet)} />}
              {selected.void_reason && <DrawerField label="Void Reason" value={<span className="text-error">{selected.void_reason}</span>} />}
              <DrawerField label="High Value" value={selected.total_pool_fet > 50000 ? <span className="text-error font-semibold"><Flag size={12} style={{ display: 'inline', marginRight: 4 }} />Yes — Review Required</span> : 'No'} />
            </DrawerSection>

            <DrawerSection title={`Entries (${entries?.length ?? 0})`}>
              {entries && entries.length > 0 ? (
                <div className="data-table-container" style={{ maxHeight: 300, overflow: 'auto' }}>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>User</th>
                        <th>Prediction</th>
                        <th>Stake</th>
                        <th>Status</th>
                        <th>Payout</th>
                      </tr>
                    </thead>
                    <tbody>
                      {entries.map(e => (
                        <tr key={e.id}>
                          <td className="mono text-xs">{e.user_id}</td>
                          <td className="font-semibold mono">{e.predicted_home_score} - {e.predicted_away_score}</td>
                          <td className="mono">{formatFET(e.stake_fet)}</td>
                          <td><StatusBadge status={e.status} /></td>
                          <td className="mono">{e.payout_fet ? formatFET(e.payout_fet) : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <p className="text-sm text-muted">No entries found.</p>
              )}
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      {/* Settle Modal */}
      <SettlePoolModal
        open={!!settleTarget}
        poolId={settleTarget?.id ?? ''}
        matchLabel={settleTarget?.match_id ?? ''}
        onConfirm={handleSettle}
        onCancel={() => setSettleTarget(null)}
        isPending={settleMutation.isPending}
      />

      {/* Void Confirm */}
      {voidTarget && (
        <div className="modal-overlay" onClick={() => setVoidTarget(null)}>
          <div className="modal-panel" onClick={e => e.stopPropagation()}>
            <div className="flex items-start gap-4 mb-4">
              <div style={{ color: 'var(--fz-error)', flexShrink: 0 }}>
                <XCircle size={24} />
              </div>
              <div>
                <h3 className="text-md font-semibold mb-1">Void Pool {voidTarget.id}</h3>
                <p className="text-sm text-muted">
                  This will cancel the pool and refund {formatFET(voidTarget.total_pool_fet)} to {voidTarget.total_participants} participants. This action cannot be undone.
                </p>
              </div>
            </div>
            <div className="field-group mb-4">
              <label className="label">Reason (required)</label>
              <textarea
                className="input"
                placeholder="Why is this pool being voided?"
                rows={3}
                value={voidReason}
                onChange={e => setVoidReason(e.target.value)}
                style={{ resize: 'vertical' }}
              />
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => { setVoidTarget(null); setVoidReason(''); }} disabled={voidMutation.isPending}>Cancel</button>
              <button className="btn btn-danger" onClick={handleVoid} disabled={voidReason.trim().length < 3 || voidMutation.isPending}>
                {voidMutation.isPending ? 'Voiding...' : 'Void & Refund'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
