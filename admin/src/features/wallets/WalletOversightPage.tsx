// FANZONE Admin — Wallet Oversight Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { CreditDebitModal } from './CreditDebitModal';
import {
  useWallets, useWalletTransactions,
  useFreezeWallet, useUnfreezeWallet,
  useCreditFet, useDebitFet,
  type WalletRow,
} from './useWallets';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatFET, formatDateTime } from '../../lib/formatters';
import {
  Wallet, AlertTriangle, Search, TrendingUp,
  Lock, Unlock, ArrowDownLeft, ArrowUpRight, Eye,
} from 'lucide-react';

export function WalletOversightPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [selectedWallet, setSelectedWallet] = useState<WalletRow | null>(null);

  // Action states
  const [freezeTarget, setFreezeTarget] = useState<WalletRow | null>(null);
  const [freezeReason, setFreezeReason] = useState('');
  const [unfreezeTarget, setUnfreezeTarget] = useState<WalletRow | null>(null);
  const [creditTarget, setCreditTarget] = useState<WalletRow | null>(null);
  const [debitTarget, setDebitTarget] = useState<WalletRow | null>(null);

  // Data
  const { data: result, isLoading, error, refetch } = useWallets({ page }, { search, status: filterStatus });
  const { data: transactions } = useWalletTransactions(selectedWallet?.user_id ?? null);

  const freezeMutation = useFreezeWallet();
  const unfreezeMutation = useUnfreezeWallet();
  const creditMutation = useCreditFet();
  const debitMutation = useDebitFet();
  const { logAction } = useAuditLog();

  const wallets = result?.data ?? [];

  const handleFreeze = async () => {
    if (!freezeTarget) return;
    await freezeMutation.mutateAsync({ p_target_user_id: freezeTarget.user_id, p_reason: freezeReason });
    await logAction({ action: 'freeze_wallet', module: 'wallets', targetType: 'wallet', targetId: freezeTarget.user_id, afterState: { reason: freezeReason } });
    setFreezeTarget(null); setFreezeReason(''); setSelectedWallet(null);
  };

  const handleUnfreeze = async () => {
    if (!unfreezeTarget) return;
    await unfreezeMutation.mutateAsync({ p_target_user_id: unfreezeTarget.user_id });
    await logAction({ action: 'unfreeze_wallet', module: 'wallets', targetType: 'wallet', targetId: unfreezeTarget.user_id });
    setUnfreezeTarget(null); setSelectedWallet(null);
  };

  const handleCredit = async (amount: number, reason: string) => {
    if (!creditTarget) return;
    await creditMutation.mutateAsync({ p_target_user_id: creditTarget.user_id, p_amount: amount, p_reason: reason });
    await logAction({ action: 'credit_fet', module: 'wallets', targetType: 'wallet', targetId: creditTarget.user_id, afterState: { amount, reason } });
    setCreditTarget(null);
  };

  const handleDebit = async (amount: number, reason: string) => {
    if (!debitTarget) return;
    await debitMutation.mutateAsync({ p_target_user_id: debitTarget.user_id, p_amount: amount, p_reason: reason });
    await logAction({ action: 'debit_fet', module: 'wallets', targetType: 'wallet', targetId: debitTarget.user_id, afterState: { amount, reason } });
    setDebitTarget(null);
  };

  // KPIs
  const totalHeld = wallets.reduce((s, w) => s + w.available_balance_fet + w.locked_balance_fet, 0);
  const totalLocked = wallets.reduce((s, w) => s + w.locked_balance_fet, 0);
  const frozenCount = wallets.filter(w => w.status === 'frozen').length;

  return (
    <div>
      <PageHeader title="Wallet Oversight" subtitle="User balances, freeze controls, and token adjustments" />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Wallets" value={result?.count ?? wallets.length} icon={<Wallet size={18} />} />
        <KpiCard label="Total FET Held" value={totalHeld} format="fet" icon={<TrendingUp size={18} />} />
        <KpiCard label="Locked FET" value={totalLocked} format="fet" />
        <KpiCard label="Frozen Wallets" value={frozenCount} icon={<AlertTriangle size={18} />} />
      </div>

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search wallets..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={filterStatus} onChange={e => { setFilterStatus(e.target.value); setPage(0); }}>
          <option value="all">All</option>
          <option value="active">Active</option>
          <option value="frozen">Frozen</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={6} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       wallets.length === 0 ? <EmptyState title="No wallets found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Available</th>
                <th>Locked</th>
                <th>Total</th>
                <th>Status</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {wallets.map(w => (
                <tr key={w.user_id} className={`cursor-pointer ${w.status === 'frozen' ? 'selected' : ''}`} onClick={() => setSelectedWallet(w)}>
                  <td>
                    <div className="font-medium">{w.display_name}</div>
                    <div className="text-xs text-muted mono">{w.user_id}</div>
                  </td>
                  <td className="mono">{formatFET(w.available_balance_fet)}</td>
                  <td className="mono text-muted">{formatFET(w.locked_balance_fet)}</td>
                  <td className="mono font-semibold">{formatFET(w.available_balance_fet + w.locked_balance_fet)}</td>
                  <td><StatusBadge status={w.status} /></td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {w.status === 'active' ? (
                        <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setFreezeTarget(w); }} title="Freeze">
                          <Lock size={14} />
                        </button>
                      ) : (
                        <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); setUnfreezeTarget(w); }} title="Unfreeze">
                          <Unlock size={14} />
                        </button>
                      )}
                      <button className="btn btn-ghost btn-sm text-success" onClick={e => { e.stopPropagation(); setCreditTarget(w); }} title="Credit FET">
                        <ArrowDownLeft size={14} />
                      </button>
                      <button className="btn btn-ghost btn-sm text-error" onClick={e => { e.stopPropagation(); setDebitTarget(w); }} title="Debit FET">
                        <ArrowUpRight size={14} />
                      </button>
                      <button className="btn btn-ghost btn-sm" onClick={e => { e.stopPropagation(); setSelectedWallet(w); }} title="View">
                        <Eye size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {wallets.length} of {result?.count ?? 0} wallets</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={wallets.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Wallet Detail Drawer */}
      <DetailDrawer
        open={!!selectedWallet}
        title={selectedWallet?.display_name ?? ''}
        subtitle={selectedWallet?.user_id}
        onClose={() => setSelectedWallet(null)}
        actions={
          selectedWallet ? (
            <>
              <button className="btn btn-ghost btn-sm text-success" onClick={() => setCreditTarget(selectedWallet)}>
                <ArrowDownLeft size={14} /> Credit
              </button>
              <button className="btn btn-ghost btn-sm text-error" onClick={() => setDebitTarget(selectedWallet)}>
                <ArrowUpRight size={14} /> Debit
              </button>
              {selectedWallet.status === 'active' ? (
                <button className="btn btn-danger btn-sm" onClick={() => setFreezeTarget(selectedWallet)}>
                  <Lock size={14} /> Freeze
                </button>
              ) : (
                <button className="btn btn-primary btn-sm" onClick={() => setUnfreezeTarget(selectedWallet)}>
                  <Unlock size={14} /> Unfreeze
                </button>
              )}
            </>
          ) : undefined
        }
      >
        {selectedWallet && (
          <>
            <DrawerSection title="Balance">
              <DrawerField label="Available" value={formatFET(selectedWallet.available_balance_fet)} />
              <DrawerField label="Locked" value={formatFET(selectedWallet.locked_balance_fet)} />
              <DrawerField label="Total" value={formatFET(selectedWallet.available_balance_fet + selectedWallet.locked_balance_fet)} />
              <DrawerField label="Status" value={<StatusBadge status={selectedWallet.status} />} />
            </DrawerSection>

            <DrawerSection title={`Recent Transactions (${transactions?.length ?? 0})`}>
              {transactions && transactions.length > 0 ? (
                <div style={{ maxHeight: 300, overflow: 'auto' }}>
                  {transactions.map(tx => (
                    <div key={tx.id} className="flex items-center justify-between py-2 border-b" style={{ borderColor: 'var(--fz-border)' }}>
                      <div>
                        <div className="text-sm font-medium">{tx.title || tx.tx_type}</div>
                        <div className="text-xs text-muted">{formatDateTime(tx.created_at)}</div>
                      </div>
                      <span className={`mono text-sm font-semibold ${tx.direction === 'credit' ? 'text-success' : 'text-error'}`}>
                        {tx.direction === 'credit' ? '+' : '-'}{formatFET(tx.amount_fet)}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted">No transactions found.</p>
              )}
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      {/* Freeze Modal */}
      {freezeTarget && (
        <div className="modal-overlay" onClick={() => { setFreezeTarget(null); setFreezeReason(''); }}>
          <div className="modal-panel" onClick={e => e.stopPropagation()}>
            <div className="flex items-start gap-4 mb-4">
              <div style={{ color: 'var(--fz-error)', flexShrink: 0 }}><Lock size={24} /></div>
              <div>
                <h3 className="text-md font-semibold mb-1">Freeze Wallet</h3>
                <p className="text-sm text-muted">
                  Freeze {freezeTarget.display_name}'s wallet. They won't be able to transfer, stake, or redeem FET.
                </p>
              </div>
            </div>
            <div className="field-group mb-4">
              <label className="label">Reason (required)</label>
              <textarea className="input" placeholder="Why is this wallet being frozen?" rows={3} value={freezeReason} onChange={e => setFreezeReason(e.target.value)} style={{ resize: 'vertical' }} />
            </div>
            <div className="flex justify-end gap-3">
              <button className="btn btn-secondary" onClick={() => { setFreezeTarget(null); setFreezeReason(''); }} disabled={freezeMutation.isPending}>Cancel</button>
              <button className="btn btn-danger" onClick={handleFreeze} disabled={freezeReason.trim().length < 3 || freezeMutation.isPending}>
                {freezeMutation.isPending ? 'Freezing...' : 'Freeze Wallet'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Unfreeze Confirm */}
      <ConfirmDialog
        open={!!unfreezeTarget}
        title="Unfreeze Wallet"
        description={unfreezeTarget ? `Unfreeze ${unfreezeTarget.display_name}'s wallet? They will regain full access to their FET.` : ''}
        confirmLabel="Unfreeze"
        onConfirm={handleUnfreeze}
        onCancel={() => setUnfreezeTarget(null)}
      />

      {/* Credit Modal */}
      <CreditDebitModal
        open={!!creditTarget}
        mode="credit"
        userId={creditTarget?.user_id ?? ''}
        userName={creditTarget?.display_name ?? ''}
        onConfirm={handleCredit}
        onCancel={() => setCreditTarget(null)}
        isPending={creditMutation.isPending}
      />

      {/* Debit Modal */}
      <CreditDebitModal
        open={!!debitTarget}
        mode="debit"
        userId={debitTarget?.user_id ?? ''}
        userName={debitTarget?.display_name ?? ''}
        onConfirm={handleDebit}
        onCancel={() => setDebitTarget(null)}
        isPending={debitMutation.isPending}
      />
    </div>
  );
}
