// FANZONE Admin — Featured Events Management Page
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useFeaturedEvents, useToggleEventActive } from './useEvents';
import type { FeaturedEventRow } from './useEvents';
import { useAuditLog } from '../../hooks/useAuditLog';
import { formatDate } from '../../lib/formatters';
import {
  Calendar, Globe, Star, StarOff, Zap, MapPin,
} from 'lucide-react';

const REGION_OPTIONS = [
  { value: 'all', label: 'All Regions' },
  { value: 'global', label: '🌍 Global' },
  { value: 'africa', label: '🌍 Africa' },
  { value: 'europe', label: '🇪🇺 Europe' },
  { value: 'americas', label: '🌎 Americas' },
];

export function EventsPage() {
  const [page, setPage] = useState(0);
  const [region, setRegion] = useState('all');
  const [selected, setSelected] = useState<FeaturedEventRow | null>(null);

  const { data: result, isLoading, error, refetch } = useFeaturedEvents({ page }, { region });
  const toggleActiveMutation = useToggleEventActive();
  const { logAction } = useAuditLog();

  const events = result?.data ?? [];
  const activeCount = events.filter(e => e.is_active).length;
  const globalCount = events.filter(e => e.region === 'global').length;
  const africanCount = events.filter(e => e.region === 'africa').length;
  const americasCount = events.filter(e => e.region === 'americas').length;

  const handleToggleActive = async (event: FeaturedEventRow) => {
    const newActive = !event.is_active;
    await toggleActiveMutation.mutateAsync({ eventId: event.id, active: newActive });
    await logAction({
      action: newActive ? 'activate_event' : 'deactivate_event',
      module: 'events',
      targetType: 'featured_event',
      targetId: event.id,
      afterState: { is_active: newActive },
    });
  };

  const getRegionBadge = (r: string) => {
    const colors: Record<string, string> = {
      global: '#1565C0', africa: '#388E3C', europe: '#7B1FA2', americas: '#E65100',
    };
    return (
      <span className="badge" style={{
        background: (colors[r] ?? '#666') + '22',
        color: colors[r] ?? '#666',
        border: `1px solid ${colors[r] ?? '#666'}44`,
      }}>
        {r.toUpperCase()}
      </span>
    );
  };

  return (
    <div>
      <PageHeader
        title="Featured Events"
        subtitle="Manage World Cup, UCL Final, AFCON, and other global events"
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Total Events" value={result?.count ?? events.length} icon={<Calendar size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<Zap size={18} />} />
        <KpiCard label="Global" value={globalCount} icon={<Globe size={18} />} />
        <KpiCard label="Regional" value={africanCount + americasCount} icon={<MapPin size={18} />} />
      </div>

      <div className="filter-bar mb-4 flex items-center gap-3">
        <select
          className="input"
          style={{ maxWidth: 200 }}
          value={region}
          onChange={e => { setRegion(e.target.value); setPage(0); }}
        >
          {REGION_OPTIONS.map(opt => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      </div>

      {isLoading ? <LoadingState lines={4} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       events.length === 0 ? <EmptyState title="No events found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Event</th>
                <th>Tag</th>
                <th>Region</th>
                <th>Dates</th>
                <th>Active</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {events.map(e => {
                const now = new Date();
                const start = new Date(e.start_date);
                const end = new Date(e.end_date);
                const status = now < start ? 'upcoming' : now > end ? 'ended' : 'live';

                return (
                  <tr key={e.id} className="cursor-pointer" onClick={() => setSelected(e)}>
                    <td>
                      <div className="font-medium">{e.name}</div>
                      <div className="text-xs text-muted">{e.short_name}</div>
                    </td>
                    <td><code className="mono text-xs">{e.event_tag}</code></td>
                    <td>{getRegionBadge(e.region)}</td>
                    <td>
                      <div className="text-xs">{formatDate(e.start_date)}</div>
                      <div className="text-xs text-muted">→ {formatDate(e.end_date)}</div>
                    </td>
                    <td>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={ev => { ev.stopPropagation(); handleToggleActive(e); }}
                      >
                        {e.is_active
                          ? <Star size={16} className="text-warning" />
                          : <StarOff size={16} className="text-muted" />
                        }
                      </button>
                    </td>
                    <td><StatusBadge status={status} /></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <DetailDrawer
        open={!!selected}
        title={selected?.name ?? ''}
        subtitle={selected?.event_tag ?? undefined}
        onClose={() => setSelected(null)}
      >
        {selected && (
          <>
            <DrawerSection title="Event Info">
              <DrawerField label="Name" value={selected.name} />
              <DrawerField label="Short Name" value={selected.short_name} />
              <DrawerField label="Event Tag" value={<code className="mono">{selected.event_tag}</code>} />
              <DrawerField label="Region" value={getRegionBadge(selected.region)} />
              <DrawerField label="Active" value={selected.is_active ? '✅ Yes' : '❌ No'} />
              <DrawerField label="Banner Color" value={
                selected.banner_color ? (
                  <span className="flex items-center gap-2">
                    <span style={{
                      width: 16, height: 16, borderRadius: 4,
                      background: selected.banner_color,
                      display: 'inline-block',
                    }} />
                    <code className="mono text-xs">{selected.banner_color}</code>
                  </span>
                ) : '—'
              } />
            </DrawerSection>
            <DrawerSection title="Schedule">
              <DrawerField label="Start Date" value={formatDate(selected.start_date)} />
              <DrawerField label="End Date" value={formatDate(selected.end_date)} />
              <DrawerField label="Created" value={formatDate(selected.created_at)} />
            </DrawerSection>
            {selected.description && (
              <DrawerSection title="Description">
                <p className="text-sm text-muted" style={{ lineHeight: 1.5 }}>
                  {selected.description}
                </p>
              </DrawerSection>
            )}
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
