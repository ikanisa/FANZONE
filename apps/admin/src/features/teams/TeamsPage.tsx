import { Search, Star, ToggleLeft, Users } from 'lucide-react';
import { useState } from 'react';

import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { EmptyState, ErrorState, LoadingState } from '../../components/ui/StateViews';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { useRpcMutation, useSupabasePaginated, type AdminListQuery } from '../../hooks/useSupabaseQuery';
import type { Team } from '../../types';

export function TeamsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const updateTeam = useRpcMutation<{
    p_team_id: string;
    p_country_id: string | null;
    p_popularity_score: number | null;
    p_is_active: boolean | null;
    p_logo_url: string | null;
  }>({
    fnName: 'admin_update_team_control',
    invalidateKeys: [['teams'], ['dashboard-kpis']],
    successMessage: 'Team controls updated.',
  });

  const { data: result, isLoading, error, refetch } = useSupabasePaginated<Team>(
    ['teams', { search }],
    'teams',
    {
      pagination: { page },
      select: 'id,name,short_name,country,country_id,popularity_score,competition_ids,logo_url,crest_url,cover_image_url,description,league_name,is_active,is_featured,fan_count,created_at,updated_at',
      filters: (query: AdminListQuery<Team>) => {
        if (!search.trim()) return query;
        const term = `%${search.trim()}%`;
        return query.or(`name.ilike.${term},short_name.ilike.${term},country.ilike.${term},league_name.ilike.${term}`);
      },
      order: { column: 'name', ascending: true },
    },
  );

  const teams = result?.data ?? [];
  const activeCount = teams.filter((team) => team.is_active).length;
  const featuredCount = teams.filter((team) => team.is_featured).length;
  const fanCount = teams.reduce((sum, team) => sum + (team.fan_count ?? 0), 0);

  return (
    <div>
      <PageHeader
        title="Teams"
        subtitle="Team catalog used by favorite-team onboarding, match display, and pool discovery."
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Listed" value={result?.count ?? teams.length} icon={<Users size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<Users size={18} />} />
        <KpiCard label="Featured" value={featuredCount} icon={<Star size={18} />} />
        <KpiCard label="Fans" value={fanCount} icon={<Users size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search teams..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(0);
            }}
          />
        </div>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : teams.length === 0 ? (
        <EmptyState
          title="No teams found"
          description="Imported teams will appear here once football data is loaded."
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Team</th>
                <th>Country</th>
                <th>League</th>
                <th>Popularity</th>
                <th>Fans</th>
                <th>Featured</th>
                <th>Status</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {teams.map((team) => (
                <tr key={team.id}>
                  <td>
                    <div className="font-medium">{team.name}</div>
                    <div className="text-xs text-muted mono">{team.short_name ?? team.id}</div>
                  </td>
                  <td>{team.country ?? 'Global'}</td>
                  <td>{team.league_name ?? '—'}</td>
                  <td>{team.popularity_score ?? 0}</td>
                  <td>{team.fan_count ?? 0}</td>
                  <td>{team.is_featured ? <Star size={16} className="text-warning" /> : <span className="text-muted">—</span>}</td>
                  <td>
                    <StatusBadge status={team.is_active ? 'active' : 'inactive'} />
                  </td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      disabled={updateTeam.isPending}
                      onClick={() =>
                        updateTeam.mutateAsync({
                          p_team_id: team.id,
                          p_country_id: null,
                          p_popularity_score: null,
                          p_is_active: !team.is_active,
                          p_logo_url: null,
                        })
                      }
                    >
                      <ToggleLeft size={14} />
                      {team.is_active ? 'Disable' : 'Enable'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {teams.length} of {result?.count ?? 0} teams</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage((value) => value - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={teams.length < (result?.pageSize ?? 25)} onClick={() => setPage((value) => value + 1)}>→</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
