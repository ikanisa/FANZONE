// FANZONE Admin — Competitions Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useCompetitions, useToggleCompetitionFeatured, useUpdateCompetitionControl } from './useCompetitions';
import type { CompetitionRow } from './useCompetitions';
import { formatDate } from '../../lib/formatters';
import { Trophy, Search, Star, StarOff, Globe, Calendar, Layers } from 'lucide-react';

export function CompetitionsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [regionFilter, setRegionFilter] = useState('all');
  const [selected, setSelected] = useState<CompetitionRow | null>(null);

  const { data: result, isLoading, error, refetch } = useCompetitions({ page }, { search });
  const toggleFeaturedMutation = useToggleCompetitionFeatured();
  const updateCompetition = useUpdateCompetitionControl();

  const competitions = (result?.data ?? []).filter((competition) => {
    if (regionFilter === 'all') return true;
    return (competition.region ?? competition.country ?? '').toLowerCase() === regionFilter;
  });
  const activeRolloutCompetitions = competitions
    .filter((competition) => competition.is_active ?? competition.status === 'active')
    .slice(0, 12);
  const activeCount = competitions.filter(c => c.is_active ?? c.status === 'active').length;
  const featuredCount = competitions.filter(c => c.is_featured).length;
  const upcomingCount = competitions.filter(c => c.status === 'upcoming').length;

  const handleToggleFeatured = async (comp: CompetitionRow) => {
    const newFeatured = !comp.is_featured;
    await toggleFeaturedMutation.mutateAsync({
      p_competition_id: comp.id,
      p_is_featured: newFeatured,
    });
  };

  const handleToggleActive = async (comp: CompetitionRow) => {
    await updateCompetition.mutateAsync({
      p_competition_id: comp.id,
      p_is_active: !(comp.is_active ?? comp.status === 'active'),
      p_priority: comp.priority ?? null,
      p_type: comp.type ?? comp.competition_type ?? null,
      p_region: comp.region ?? null,
    });
  };

  return (
    <div>
      <PageHeader title="Competitions" subtitle="Approved competition catalog for curated sports-bar pool discovery" />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total" value={result?.count ?? competitions.length} icon={<Trophy size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<Calendar size={18} />} />
        <KpiCard label="Featured" value={featuredCount} icon={<Star size={18} />} />
        <KpiCard label="Upcoming" value={upcomingCount} icon={<Layers size={18} />} />
      </div>

      <div className="data-table-container mb-4" style={{ padding: 12 }}>
        <div className="text-xs font-semibold text-muted uppercase mb-2">Active Supabase rollout set</div>
        <div className="flex flex-wrap gap-2">
          {activeRolloutCompetitions.length === 0 ? (
            <span className="text-sm text-muted">No active competitions loaded from Supabase.</span>
          ) : (
            activeRolloutCompetitions.map((competition) => (
              <span key={competition.id} className="badge badge-neutral">{competition.name}</span>
            ))
          )}
        </div>
      </div>

      <div className="filter-bar mb-4 flex items-center gap-3">
        <div style={{ position: 'relative', maxWidth: 320, flex: 1 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search competitions..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select
          className="input"
          style={{ maxWidth: 180 }}
          value={regionFilter}
          onChange={e => { setRegionFilter(e.target.value); setPage(0); }}
        >
          <option value="all">All Regions</option>
          <option value="global">🌍 Global</option>
          <option value="africa">🌍 Africa</option>
          <option value="europe">🇪🇺 Europe</option>
          <option value="north_america">🌎 North America</option>
        </select>
      </div>

      {isLoading ? <LoadingState lines={5} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       competitions.length === 0 ? <EmptyState title="No competitions found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead><tr><th>Competition</th><th>Country</th><th>Type</th><th>Priority</th><th>Matches</th><th>Featured</th><th>Status</th><th className="cell-actions">Actions</th></tr></thead>
            <tbody>
              {competitions.map(c => (
                <tr key={c.id} className="cursor-pointer" onClick={() => setSelected(c)}>
                  <td><div className="font-medium">{c.name}</div><div className="text-xs text-muted mono">{c.short_name}</div></td>
                  <td><span className="flex items-center gap-1"><Globe size={14} className="text-muted" />{c.country}</span></td>
                  <td>{c.type ?? c.competition_type ?? 'league'}</td>
                  <td>{c.priority ?? c.tier ?? 100}</td>
                  <td>{c.matches_count ?? 0}</td>
                  <td>
                    <button className="btn btn-ghost btn-icon btn-sm" onClick={e => { e.stopPropagation(); handleToggleFeatured(c); }}>
                      {c.is_featured ? <Star size={16} className="text-warning" /> : <StarOff size={16} className="text-muted" />}
                    </button>
                  </td>
                  <td><StatusBadge status={(c.is_active ?? c.status === 'active') ? 'active' : 'disabled'} /></td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      disabled={updateCompetition.isPending}
                      onClick={e => { e.stopPropagation(); handleToggleActive(c); }}
                    >
                      {(c.is_active ?? c.status === 'active') ? 'Disable' : 'Enable'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <DetailDrawer open={!!selected} title={selected?.name ?? ''} subtitle={selected?.short_name ?? undefined} onClose={() => setSelected(null)}>
        {selected && (
          <>
            <DrawerSection title="Competition Info">
              <DrawerField label="Name" value={selected.name} />
              <DrawerField label="Short Name" value={selected.short_name || '—'} />
              <DrawerField label="Country" value={selected.country || '—'} />
              <DrawerField label="Type" value={selected.type ?? selected.competition_type ?? 'league'} />
              <DrawerField label="Priority" value={selected.priority ?? '—'} />
              <DrawerField label="Tier" value={<span className="badge badge-neutral">Tier {selected.tier}</span>} />
              <DrawerField label="Season" value={selected.season || '—'} />
              <DrawerField label="Matches" value={selected.matches_count ?? 0} />
              <DrawerField label="Featured" value={selected.is_featured ? '⭐ Yes' : 'No'} />
              <DrawerField label="Status" value={<StatusBadge status={selected.status || 'active'} />} />
              <DrawerField label="Created" value={formatDate(selected.created_at)} />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
