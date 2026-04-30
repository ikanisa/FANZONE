// FANZONE Admin — FET Token Operations Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useTokenTransactions, useFetSupply } from './useTokenOps';
import { formatFET, formatDateTime } from '../../lib/formatters';
import { Coins, ArrowUpDown, ArrowDownLeft, ArrowUpRight, AlertTriangle, Search } from 'lucide-react';

export function TokenOpsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  // Data
  const { data: result, isLoading, error, refetch } = useTokenTransactions({ page }, { search, type: typeFilter });
  const { data: supply } = useFetSupply();

  const transactions = result?.data ?? [];
  const flaggedCount = transactions.filter(t => t.flagged || (t.metadata && (t.metadata as Record<string, unknown>).flagged)).length;

  return (
    <div>
      <PageHeader
        title="FET Token Operations"
        subtitle="Token supply, issuance, transfers, and analytics"
        actions={
          <a className="btn btn-secondary" href="/wallets">Adjust User Balances</a>
        }
      />

      {/* Supply KPIs */}
      <div className="grid grid-5 gap-4 mb-6">
        <KpiCard label="Total Issued" value={supply?.totalIssued ?? 0} format="fet" icon={<Coins size={18} />} />
        <KpiCard label="Circulating" value={supply?.totalCirculating ?? 0} format="fet" icon={<ArrowUpDown size={18} />} />
        <KpiCard label="Locked" value={supply?.totalLocked ?? 0} format="fet" />
        <KpiCard label="Rewarded" value={supply?.totalRewarded ?? 0} format="fet" icon={<ArrowDownLeft size={18} />} />
        <KpiCard label="Flagged Tx" value={flaggedCount} icon={<AlertTriangle size={18} />} />
      </div>

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search transactions..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={typeFilter} onChange={e => { setTypeFilter(e.target.value); setPage(0); }}>
          <option value="all">All types</option>
          <option value="earn">Earn</option>
          <option value="transfer">Transfer</option>
          <option value="prediction_reward">Prediction rewards</option>
          <option value="foundation_grant">Foundation grants</option>
          <option value="admin_credit">Admin Credit</option>
          <option value="admin_debit">Admin Debit</option>
        </select>
      </div>

      {/* Transaction Table */}
      {isLoading ? <LoadingState lines={6} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       transactions.length === 0 ? <EmptyState title="No transactions found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>ID</th><th>User</th><th>Type</th><th>Direction</th><th>Amount</th><th>Description</th><th>Date</th><th>Flag</th></tr></thead>
            <tbody>
              {transactions.map(t => {
                const isFlagged = t.flagged || (t.metadata && (t.metadata as Record<string, unknown>).flagged);
                return (
                  <tr key={t.id} className={isFlagged ? 'selected' : ''}>
                    <td className="mono text-xs">{t.id}</td>
                    <td>
                      <div className="font-medium">{t.display_name || 'Unknown user'}</div>
                      <div className="text-xs text-muted mono">{t.user_id}</div>
                    </td>
                    <td><StatusBadge status={t.tx_type} /></td>
                    <td>{t.direction === 'credit' ? <span className="flex items-center gap-1 text-success"><ArrowDownLeft size={14} />Credit</span> : <span className="flex items-center gap-1 text-error"><ArrowUpRight size={14} />Debit</span>}</td>
                    <td className="mono font-semibold">{formatFET(t.amount_fet)}</td>
                    <td className="text-muted">{t.title || '—'}</td>
                    <td className="text-muted">{formatDateTime(t.created_at)}</td>
                    <td>{isFlagged ? <AlertTriangle size={16} className="text-error" /> : <span className="text-muted">—</span>}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {transactions.length} of {result?.count ?? 0} transactions</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={transactions.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
