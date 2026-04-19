// FANZONE Admin — Rewards Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useRewards, useToggleRewardActive, useToggleRewardFeatured } from './useRewards';
import { formatFET, formatDate } from '../../lib/formatters';
import { Gift, Search, Star, StarOff, Plus, ToggleLeft, ToggleRight, AlertTriangle } from 'lucide-react';
import type { Reward } from '../../types';

export function RewardsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState<Reward | null>(null);

  const { data: result, isLoading, error, refetch } = useRewards({ page }, { search, status: statusFilter });
  const toggleActiveMutation = useToggleRewardActive();
  const toggleFeaturedMutation = useToggleRewardFeatured();

  const rewards = result?.data ?? [];
  const activeCount = rewards.filter(r => r.is_active).length;
  const featuredCount = rewards.filter(r => r.is_featured).length;
  const lowStockCount = rewards.filter(r => r.inventory_remaining != null && r.inventory_total != null && r.inventory_remaining <= r.inventory_total * 0.2).length;

  const handleToggleActive = async (reward: Reward) => {
    const newActive = !reward.is_active;
    await toggleActiveMutation.mutateAsync({ p_reward_id: reward.id, p_is_active: newActive });
  };

  const handleToggleFeatured = async (reward: Reward) => {
    const newFeatured = !reward.is_featured;
    await toggleFeaturedMutation.mutateAsync({ p_reward_id: reward.id, p_is_featured: newFeatured });
  };

  return (
    <div>
      <PageHeader title="Rewards" subtitle="Manage FET redemption offers" actions={<button className="btn btn-primary"><Plus size={16} /> Create Reward</button>} />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Rewards" value={result?.count ?? rewards.length} icon={<Gift size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<ToggleRight size={18} />} />
        <KpiCard label="Featured" value={featuredCount} icon={<Star size={18} />} />
        <KpiCard label="Low Stock" value={lowStockCount} icon={<AlertTriangle size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search rewards..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All</option><option value="active">Active</option><option value="archived">Archived</option>
        </select>
      </div>

      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       rewards.length === 0 ? <EmptyState title="No rewards found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Reward</th><th>Category</th><th>FET Cost</th><th>Inventory</th><th>Valid Until</th><th>Featured</th><th>Status</th><th className="cell-actions">Toggle</th></tr></thead>
            <tbody>
              {rewards.map(r => (
                <tr key={r.id} className="cursor-pointer" onClick={() => setSelected(r)}>
                  <td><div className="flex items-center gap-2"><Gift size={16} className="text-accent" /><div><div className="font-medium">{r.title}</div><div className="text-xs text-muted mono">{r.id}</div></div></div></td>
                  <td><span className="badge badge-neutral">{r.category || '—'}</span></td>
                  <td className="mono font-semibold">{formatFET(r.fet_cost)}</td>
                  <td>{r.inventory_total ? `${r.inventory_remaining}/${r.inventory_total}` : '∞'}</td>
                  <td className="text-muted">{r.valid_until ? formatDate(r.valid_until) : '—'}</td>
                  <td>
                    <button className="btn btn-ghost btn-icon btn-sm" onClick={e => { e.stopPropagation(); handleToggleFeatured(r); }}>
                      {r.is_featured ? <Star size={16} className="text-warning" /> : <StarOff size={16} className="text-muted" />}
                    </button>
                  </td>
                  <td><StatusBadge status={r.is_active ? 'active' : 'archived'} /></td>
                  <td className="cell-actions">
                    <button className="btn btn-ghost btn-icon btn-sm" onClick={e => { e.stopPropagation(); handleToggleActive(r); }} title={r.is_active ? 'Deactivate' : 'Activate'}>
                      {r.is_active ? <ToggleRight size={20} className="text-success" /> : <ToggleLeft size={20} className="text-muted" />}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <DetailDrawer open={!!selected} title={selected?.title ?? ''} subtitle={selected?.id} onClose={() => setSelected(null)}>
        {selected && (
          <>
            <DrawerSection title="Reward Info">
              <DrawerField label="Title" value={selected.title} />
              <DrawerField label="Category" value={<span className="badge badge-neutral">{selected.category || '—'}</span>} />
              <DrawerField label="FET Cost" value={formatFET(selected.fet_cost)} />
              <DrawerField label="Original Value" value={selected.original_value || '—'} />
              <DrawerField label="Currency" value={selected.currency} />
              <DrawerField label="Status" value={<StatusBadge status={selected.is_active ? 'active' : 'archived'} />} />
              <DrawerField label="Featured" value={selected.is_featured ? '⭐ Yes' : 'No'} />
            </DrawerSection>
            <DrawerSection title="Inventory">
              <DrawerField label="Total" value={selected.inventory_total ?? '∞'} />
              <DrawerField label="Remaining" value={selected.inventory_remaining ?? '∞'} />
              {selected.inventory_total && selected.inventory_remaining != null && (
                <div className="mt-2" style={{ background: 'var(--fz-surface-2)', borderRadius: 4, height: 8, overflow: 'hidden' }}>
                  <div style={{ width: `${(selected.inventory_remaining / selected.inventory_total) * 100}%`, height: '100%', background: selected.inventory_remaining <= selected.inventory_total * 0.2 ? 'var(--fz-error)' : 'var(--fz-accent)', borderRadius: 4, transition: 'width 300ms ease' }} />
                </div>
              )}
            </DrawerSection>
            <DrawerSection title="Validity">
              <DrawerField label="Valid From" value={selected.valid_from ? formatDate(selected.valid_from) : '—'} />
              <DrawerField label="Valid Until" value={selected.valid_until ? formatDate(selected.valid_until) : '—'} />
            </DrawerSection>
            {selected.description && (
              <DrawerSection title="Description">
                <p className="text-sm">{selected.description}</p>
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
