// FANZONE Admin — Redemptions Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useRedemptions, useApproveRedemption, useRejectRedemption, useFulfillRedemption } from './useRedemptions';
import type { RedemptionRow } from './useRedemptions';
import { formatFET, formatDateTime } from '../../lib/formatters';
import { Clock, CheckCircle, XCircle, AlertTriangle, Check, X as XIcon, Search, Package } from 'lucide-react';

export function RedemptionsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState<RedemptionRow | null>(null);
  const [rejectTarget, setRejectTarget] = useState<RedemptionRow | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [fulfillTarget, setFulfillTarget] = useState<RedemptionRow | null>(null);

  const { data: result, isLoading, error, refetch } = useRedemptions({ page }, { status: statusFilter, search });
  const approveMutation = useApproveRedemption();
  const rejectMutation = useRejectRedemption();
  const fulfillMutation = useFulfillRedemption();

  const redemptions = result?.data ?? [];
  const pendingCount = redemptions.filter(r => r.status === 'pending').length;
  const fulfilledCount = redemptions.filter(r => r.status === 'fulfilled').length;
  const rejectedCount = redemptions.filter(r => r.status === 'rejected').length;
  const disputedCount = redemptions.filter(r => r.status === 'disputed').length;

  const handleApprove = async (r: RedemptionRow) => {
    await approveMutation.mutateAsync({ redemptionId: r.id });
    setSelected(null);
  };

  const handleReject = async () => {
    if (!rejectTarget) return;
    await rejectMutation.mutateAsync({ redemptionId: rejectTarget.id, reason: rejectReason });
    setRejectTarget(null); setRejectReason(''); setSelected(null);
  };

  const handleFulfill = async () => {
    if (!fulfillTarget) return;
    await fulfillMutation.mutateAsync({ redemptionId: fulfillTarget.id });
    setFulfillTarget(null); setSelected(null);
  };

  return (
    <div>
      <PageHeader title="Redemptions" subtitle="FET reward redemption queue" />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Pending" value={pendingCount} icon={<Clock size={18} />} />
        <KpiCard label="Fulfilled" value={fulfilledCount} icon={<CheckCircle size={18} />} />
        <KpiCard label="Rejected" value={rejectedCount} icon={<XCircle size={18} />} />
        <KpiCard label="Disputed" value={disputedCount} icon={<AlertTriangle size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search redemptions..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option><option value="pending">Pending</option><option value="approved">Approved</option><option value="fulfilled">Fulfilled</option><option value="rejected">Rejected</option><option value="disputed">Disputed</option>
        </select>
      </div>

      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       redemptions.length === 0 ? <EmptyState title="No redemptions" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>ID</th><th>User</th><th>Reward</th><th>Partner</th><th>FET</th><th>Status</th><th>Fraud</th><th>Date</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {redemptions.map(r => (
                <tr key={r.id} className={`cursor-pointer ${r.fraud_flag ? 'selected' : ''}`} onClick={() => setSelected(r)}>
                  <td className="mono text-xs">{r.id}</td>
                  <td className="font-medium">{r.user_name || r.user_id.slice(0, 8)}</td>
                  <td>{r.reward_title || r.reward_id?.slice(0, 8) || '—'}</td>
                  <td className="text-muted">{r.partner_name || '—'}</td>
                  <td className="mono">{formatFET(r.fet_amount)}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td>{r.fraud_flag ? <AlertTriangle size={16} className="text-error" /> : '—'}</td>
                  <td className="text-muted">{formatDateTime(r.created_at)}</td>
                  <td className="cell-actions">
                    {r.status === 'pending' && (
                      <div className="flex gap-1">
                        <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); handleApprove(r); }}><Check size={14} /></button>
                        <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setRejectTarget(r); }}><XIcon size={14} /></button>
                      </div>
                    )}
                    {r.status === 'approved' && (
                      <button className="btn btn-ghost btn-sm text-accent" onClick={e => { e.stopPropagation(); setFulfillTarget(r); }}><Package size={14} /> Fulfill</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {redemptions.length} of {result?.count ?? 0}</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={redemptions.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Drawer */}
      <DetailDrawer open={!!selected} title={`Redemption ${selected?.id ?? ''}`} onClose={() => setSelected(null)}
        actions={selected?.status === 'pending' ? (
          <>
            <button className="btn btn-primary btn-sm" onClick={() => handleApprove(selected)}><Check size={14} /> Approve</button>
            <button className="btn btn-danger btn-sm" onClick={() => setRejectTarget(selected)}><XIcon size={14} /> Reject</button>
          </>
        ) : selected?.status === 'approved' ? (
          <button className="btn btn-primary btn-sm" onClick={() => setFulfillTarget(selected)}><Package size={14} /> Mark Fulfilled</button>
        ) : undefined}
      >
        {selected && (
          <>
            <DrawerSection title="Redemption Info">
              <DrawerField label="User" value={selected.user_name || selected.user_id} />
              <DrawerField label="Reward" value={selected.reward_title || selected.reward_id || '—'} />
              <DrawerField label="Partner" value={selected.partner_name || '—'} />
              <DrawerField label="FET Amount" value={formatFET(selected.fet_amount)} />
              <DrawerField label="Status" value={<StatusBadge status={selected.status} />} />
              <DrawerField label="Code" value={selected.redemption_code || '—'} />
              <DrawerField label="Fraud Flag" value={selected.fraud_flag ? <span className="text-error font-semibold">⚠️ FLAGGED</span> : 'Clean'} />
              <DrawerField label="Date" value={formatDateTime(selected.created_at)} />
            </DrawerSection>
            {selected.admin_notes && (
              <DrawerSection title="Admin Notes">
                <p className="text-sm">{selected.admin_notes}</p>
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>

      {/* Reject Modal */}
      {rejectTarget && (
        <div className="modal-overlay" onClick={() => { setRejectTarget(null); setRejectReason(''); }}>
          <div className="modal-panel" onClick={e => e.stopPropagation()}>
            <h3 className="text-md font-semibold mb-2">Reject Redemption</h3>
            <p className="text-sm text-muted mb-4">Reject {rejectTarget.user_name}'s redemption for "{rejectTarget.reward_title}"?</p>
            <div className="field-group mb-4">
              <label className="label">Reason</label>
              <textarea className="input" rows={2} value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="Rejection reason..." style={{ resize: 'vertical' }} />
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => { setRejectTarget(null); setRejectReason(''); }}>Cancel</button>
              <button className="btn btn-danger" onClick={handleReject} disabled={rejectReason.trim().length < 3}>Reject</button>
            </div>
          </div>
        </div>
      )}

      {/* Fulfill Confirmation */}
      <ConfirmDialog open={!!fulfillTarget} title="Mark as Fulfilled" description={fulfillTarget ? `Confirm that ${fulfillTarget.user_name}'s redemption has been physically fulfilled?` : ''} confirmLabel="Mark Fulfilled" onConfirm={handleFulfill} onCancel={() => setFulfillTarget(null)} />
    </div>
  );
}
