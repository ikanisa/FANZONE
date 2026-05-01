import { Building2, Coins, MapPin, Search, ShieldCheck } from 'lucide-react';
import { useMemo, useState } from 'react';

import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { EmptyState, ErrorState, LoadingState } from '../../components/ui/StateViews';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { useRpcMutation } from '../../hooks/useSupabaseQuery';
import { formatDate } from '../../lib/formatters';
import { useVenues } from '../hospitality-audit/useHospitality';

export function VenuesPage() {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const { data: venues = [], isLoading, error, refetch } = useVenues();
  const updateVenue = useRpcMutation<{
    p_venue_id: string;
    p_status: string | null;
    p_is_active: boolean | null;
    p_country_id: string | null;
    p_city: string | null;
    p_fet_reward_percent: number | null;
    p_accepts_fet_spend: boolean | null;
  }>({
    fnName: 'admin_update_venue_control',
    invalidateKeys: [['venues'], ['dashboard-kpis']],
    successMessage: 'Venue control updated.',
  });

  const filteredVenues = useMemo(() => {
    const query = search.trim().toLowerCase();
    return venues.filter((venue) => {
      if (statusFilter !== 'all') {
        const status = venue.status ?? (venue.is_active ? 'active' : 'inactive');
        if (statusFilter === 'active' && !venue.is_active) return false;
        if (statusFilter !== 'active' && status !== statusFilter) return false;
      }
      if (!query) return true;
      return [venue.name, venue.slug, venue.country_code, venue.city ?? '', venue.owner_email ?? '']
        .join(' ')
        .toLowerCase()
        .includes(query);
    });
  }, [search, statusFilter, venues]);

  const activeCount = venues.filter((venue) => venue.is_active).length;
  const openCount = venues.filter((venue) => venue.is_open).length;
  const fetSpendCount = venues.filter((venue) => venue.accepts_fet_spend).length;

  async function setVenueStatus(id: string, status: 'approved' | 'suspended') {
    await updateVenue.mutateAsync({
      p_venue_id: id,
      p_status: status,
      p_is_active: status === 'approved',
      p_country_id: null,
      p_city: null,
      p_fet_reward_percent: null,
      p_accepts_fet_spend: null,
    });
  }

  return (
    <div>
      <PageHeader
        title="Venues"
        subtitle="Sports-bar venue records, claim state, and ordering availability."
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Venues" value={venues.length} icon={<Building2 size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<ShieldCheck size={18} />} />
        <KpiCard label="Open" value={openCount} icon={<MapPin size={18} />} />
        <KpiCard label="FET Spend" value={fetSpendCount} icon={<Coins size={18} />} />
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search venues..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </div>
        <select className="input select" style={{ maxWidth: 180 }} value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="approved">Approved</option>
          <option value="suspended">Suspended</option>
          <option value="draft">Draft</option>
          <option value="pending">Pending</option>
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : filteredVenues.length === 0 ? (
        <EmptyState
          title="No venues found"
          description="Approved sports bars will appear here once they are onboarded."
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Venue</th>
                <th>Country</th>
                <th>City</th>
                <th>Category</th>
                <th>FET Reward</th>
                <th>FET Spend</th>
                <th>Status</th>
                <th>Created</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredVenues.map((venue) => (
                <tr key={venue.id}>
                  <td>
                    <div className="font-medium">{venue.name}</div>
                    <div className="text-xs text-muted mono">{venue.slug}</div>
                  </td>
                  <td>{venue.country_code}</td>
                  <td>{venue.city ?? '—'}</td>
                  <td>{venue.primary_category ?? 'Sports bar'}</td>
                  <td>
                    {Number(venue.fet_reward_percent ?? 0).toFixed(2)}%
                  </td>
                  <td>
                    <StatusBadge status={venue.accepts_fet_spend ? 'enabled' : 'disabled'} />
                  </td>
                  <td>
                    <StatusBadge status={venue.status ?? (venue.is_active ? 'active' : 'inactive')} />
                  </td>
                  <td className="text-xs text-muted">{formatDate(venue.created_at)}</td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      type="button"
                      disabled={updateVenue.isPending}
                      onClick={() => setVenueStatus(venue.id, 'approved')}
                    >
                      Approve
                    </button>
                    <button
                      className="btn btn-ghost btn-sm text-error"
                      type="button"
                      disabled={updateVenue.isPending}
                      onClick={() => setVenueStatus(venue.id, 'suspended')}
                    >
                      Suspend
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
