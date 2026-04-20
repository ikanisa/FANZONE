// FANZONE Admin — Content (Banners) Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { ConfirmDialog } from '../../components/ui/ConfirmDialog';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useBanners, useToggleBannerActive, useDeleteBanner } from './useContent';
import { formatDate } from '../../lib/formatters';
import { Plus, Search, Image, Globe, ToggleLeft, ToggleRight, Trash2, Eye } from 'lucide-react';
import type { ContentBanner } from '../../types';

export function ContentPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [placementFilter, setPlacementFilter] = useState('all');
  const [selected, setSelected] = useState<ContentBanner | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<ContentBanner | null>(null);

  const { data: result, isLoading, error, refetch } = useBanners({ page }, { search, placement: placementFilter });
  const toggleActiveMutation = useToggleBannerActive();
  const deleteMutation = useDeleteBanner();

  const banners = result?.data ?? [];
  const activeCount = banners.filter(b => b.is_active).length;

  const handleToggleActive = async (banner: ContentBanner) => {
    const newActive = !banner.is_active;
    await toggleActiveMutation.mutateAsync({ p_banner_id: banner.id, p_is_active: newActive });
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    await deleteMutation.mutateAsync({ p_banner_id: deleteTarget.id });
    setDeleteTarget(null); setSelected(null);
  };

  return (
    <div>
      <PageHeader title="Content — Banners" subtitle="Manage promotional banners and notices" actions={<button className="btn btn-primary"><Plus size={16} /> Add Banner</button>} />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Banners" value={result?.count ?? banners.length} icon={<Image size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<ToggleRight size={18} />} />
        <KpiCard label="Placements" value={[...new Set(banners.map(b => b.placement))].length} icon={<Globe size={18} />} />
        <KpiCard label="Expired" value={banners.filter(b => b.valid_until && new Date(b.valid_until) < new Date()).length} icon={<ToggleLeft size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search banners..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 180 }} value={placementFilter} onChange={e => { setPlacementFilter(e.target.value); setPage(0); }}>
          <option value="all">All placements</option>
          <option value="home_hero">Home Hero</option>
          <option value="home_secondary">Home Secondary</option>
          <option value="rewards_hero">Rewards Hero</option>
        </select>
      </div>

      {isLoading ? <LoadingState lines={4} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       banners.length === 0 ? <EmptyState title="No banners" description="Create your first promotional banner." icon={<Image size={48} />} /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Banner</th><th>Placement</th><th>Country</th><th>Priority</th><th>Valid Until</th><th>Status</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {banners.map(b => (
                <tr key={b.id} className="cursor-pointer" onClick={() => setSelected(b)}>
                  <td><div className="font-medium">{b.title}</div>{b.subtitle && <div className="text-xs text-muted">{b.subtitle}</div>}</td>
                  <td><span className="badge badge-neutral">{b.placement.replace(/_/g, ' ')}</span></td>
                  <td><span className="flex items-center gap-1"><Globe size={14} className="text-muted" />{b.country}</span></td>
                  <td className="mono">#{b.priority}</td>
                  <td className="text-muted">{b.valid_until ? formatDate(b.valid_until) : '—'}</td>
                  <td><StatusBadge status={b.is_active ? 'active' : 'archived'} /></td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      <button className="btn btn-ghost btn-icon btn-sm" onClick={e => { e.stopPropagation(); handleToggleActive(b); }} title={b.is_active ? 'Deactivate' : 'Activate'}>
                        {b.is_active ? <ToggleRight size={18} className="text-success" /> : <ToggleLeft size={18} className="text-muted" />}
                      </button>
                      <button className="btn btn-ghost btn-icon btn-sm text-error" onClick={e => { e.stopPropagation(); setDeleteTarget(b); }} title="Delete">
                        <Trash2 size={14} />
                      </button>
                      <button className="btn btn-ghost btn-icon btn-sm" onClick={e => { e.stopPropagation(); setSelected(b); }} title="View">
                        <Eye size={14} />
                      </button>
                    </div>
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
            <DrawerSection title="Banner Info">
              <DrawerField label="Title" value={selected.title} />
              <DrawerField label="Subtitle" value={selected.subtitle || '—'} />
              <DrawerField label="Placement" value={<span className="badge badge-neutral">{selected.placement.replace(/_/g, ' ')}</span>} />
              <DrawerField label="Priority" value={`#${selected.priority}`} />
              <DrawerField label="Country" value={selected.country} />
              <DrawerField label="Status" value={<StatusBadge status={selected.is_active ? 'active' : 'archived'} />} />
              <DrawerField label="Action URL" value={selected.action_url ? <a href={selected.action_url} className="text-primary">{selected.action_url}</a> : '—'} />
            </DrawerSection>
            <DrawerSection title="Validity">
              <DrawerField label="Valid From" value={selected.valid_from ? formatDate(selected.valid_from) : '—'} />
              <DrawerField label="Valid Until" value={selected.valid_until ? formatDate(selected.valid_until) : '—'} />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      <ConfirmDialog open={!!deleteTarget} title="Delete Banner" description={deleteTarget ? `Delete "${deleteTarget.title}"? This cannot be undone.` : ''} confirmLabel="Delete" danger onConfirm={handleDelete} onCancel={() => setDeleteTarget(null)} />
    </div>
  );
}
