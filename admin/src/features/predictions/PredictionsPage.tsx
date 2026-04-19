// FANZONE Admin — Predictions Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { usePredictionMarkets, usePredictionKpis } from './usePredictions';
import type { PredictionMarket } from './usePredictions';
import { formatDateTime } from '../../lib/formatters';
import { Target, TrendingUp, Clock, CheckCircle, Search } from 'lucide-react';

export function PredictionsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState<PredictionMarket | null>(null);

  const { data: result, isLoading, error, refetch } = usePredictionMarkets({ page }, { status: statusFilter, search });
  const { data: kpis } = usePredictionKpis();
  const markets = result?.data ?? [];

  return (
    <div>
      <PageHeader title="Predictions" subtitle="Manage prediction markets and settlements" />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Active Markets" value={kpis?.activeMarkets ?? 0} icon={<Target size={18} />} />
        <KpiCard label="Predictions (24h)" value={kpis?.totalPredictions24h ?? 0} trend={15.3} trendDirection="up" icon={<TrendingUp size={18} />} />
        <KpiCard label="Pending Settlement" value={kpis?.pendingSettlement ?? 0} icon={<Clock size={18} />} />
        <KpiCard label="Settled Today" value={kpis?.settledToday ?? 0} icon={<CheckCircle size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search markets..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="open">Open</option>
          <option value="locked">Locked</option>
          <option value="settled">Settled</option>
        </select>
      </div>

      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       markets.length === 0 ? <EmptyState title="No prediction markets found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Match</th><th>Market Type</th><th>Options</th><th>Predictions</th><th>Closes</th><th>Status</th></tr></thead>
            <tbody>
              {markets.map(m => (
                <tr key={m.id} className="cursor-pointer" onClick={() => setSelected(m)}>
                  <td className="font-medium">{m.match_name}</td>
                  <td><span className="badge badge-neutral">{m.market_type}</span></td>
                  <td>{m.options_count}</td>
                  <td className="font-semibold">{m.predictions_count.toLocaleString()}</td>
                  <td className="text-muted">{formatDateTime(m.closes_at)}</td>
                  <td><StatusBadge status={m.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {markets.length} of {result?.count ?? 0}</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={markets.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      <DetailDrawer open={!!selected} title={selected?.match_name ?? ''} subtitle={selected?.id} onClose={() => setSelected(null)}>
        {selected && (
          <DrawerSection title="Market Details">
            <DrawerField label="Match" value={selected.match_name} />
            <DrawerField label="Market Type" value={<span className="badge badge-neutral">{selected.market_type}</span>} />
            <DrawerField label="Options" value={selected.options_count} />
            <DrawerField label="Predictions" value={selected.predictions_count.toLocaleString()} />
            <DrawerField label="Closes At" value={formatDateTime(selected.closes_at)} />
            <DrawerField label="Status" value={<StatusBadge status={selected.status} />} />
          </DrawerSection>
        )}
      </DetailDrawer>
    </div>
  );
}
