// FANZONE Admin — Fixtures Page — Live Data
import { useState } from 'react';
import { PageHeader } from '../../components/layout/PageHeader';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { DetailDrawer, DrawerSection, DrawerField } from '../../components/ui/DetailDrawer';
import { EnterResultModal } from './EnterResultModal';
import { useFixtures, useUpdateFixtureResult, useAutoSettlePools } from './useFixtures';
import { formatDate, formatDateTime } from '../../lib/formatters';
import { Search, Upload, Plus, Calendar, Star, Target, Gavel, Eye } from 'lucide-react';
import type { Match } from '../../types';

export function FixturesPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedFixture, setSelectedFixture] = useState<Match | null>(null);

  // Action states
  const [resultTarget, setResultTarget] = useState<Match | null>(null);
  const [settleAndResult, setSettleAndResult] = useState(false);

  // Data
  const { data: result, isLoading, error, refetch } = useFixtures({ page }, { status: statusFilter, search });
  const updateResult = useUpdateFixtureResult();
  const autoSettle = useAutoSettlePools();

  const fixtures = result?.data ?? [];

  const handleEnterResult = async (homeScore: number, awayScore: number) => {
    if (!resultTarget) return;

    // Update the fixture score
    await updateResult.mutateAsync({
      p_match_id: resultTarget.id,
      p_ft_home: homeScore,
      p_ft_away: awayScore,
    });

    // Optionally settle all pools
    if (settleAndResult) {
      await autoSettle.mutateAsync({
        p_match_id: resultTarget.id,
        p_home_score: homeScore,
        p_away_score: awayScore,
      });
    }

    setResultTarget(null);
    setSettleAndResult(false);
    setSelectedFixture(null);
  };

  return (
    <div>
      <PageHeader
        title="Fixtures"
        subtitle="Match schedule and results"
        actions={
          <>
            <button className="btn btn-secondary"><Upload size={16} /> Bulk Import</button>
            <button className="btn btn-primary"><Plus size={16} /> Add Fixture</button>
          </>
        }
      />

      {/* Filters */}
      <div className="filter-bar mb-4">
        <div style={{ position: 'relative', maxWidth: 320 }}>
          <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--fz-muted-2)' }} />
          <input className="input" style={{ paddingLeft: 36 }} placeholder="Search fixtures..." value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input select" style={{ maxWidth: 160 }} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }}>
          <option value="all">All statuses</option>
          <option value="upcoming">Upcoming</option>
          <option value="live">Live</option>
          <option value="finished">Finished</option>
          <option value="postponed">Postponed</option>
        </select>
      </div>

      {/* Content */}
      {isLoading ? <LoadingState lines={6} /> :
       error ? <ErrorState onRetry={() => refetch()} /> :
       fixtures.length === 0 ? <EmptyState title="No fixtures found" /> : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Match</th>
                <th>Date</th>
                <th>Kickoff</th>
                <th>Score</th>
                <th>Status</th>
                <th>Featured</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {fixtures.map(f => (
                <tr key={f.id} className="cursor-pointer" onClick={() => setSelectedFixture(f)}>
                  <td>
                    <div className="font-medium">{f.home_team} vs {f.away_team}</div>
                    <div className="text-xs text-muted mono">{f.id}</div>
                  </td>
                  <td><span className="flex items-center gap-1"><Calendar size={14} className="text-muted" />{formatDate(f.date)}</span></td>
                  <td>{f.kickoff_time || '—'}</td>
                  <td className="font-semibold mono">{f.ft_home !== null ? `${f.ft_home} - ${f.ft_away}` : '—'}</td>
                  <td>{f.status === 'live' ? <span className="badge badge-live">LIVE</span> : <StatusBadge status={f.status} />}</td>
                  <td>{f.home_multiplier ? <Star size={16} className="text-warning" /> : <span className="text-muted">—</span>}</td>
                  <td className="cell-actions">
                    <div className="flex gap-1">
                      {(f.status === 'upcoming' || f.status === 'live') && (
                        <button
                          className="btn btn-ghost btn-sm text-primary"
                          onClick={e => { e.stopPropagation(); setResultTarget(f); setSettleAndResult(false); }}
                          title="Enter Result"
                        >
                          <Target size={14} /> Result
                        </button>
                      )}
                      {f.status === 'finished' && f.ft_home !== null && (
                        <button
                          className="btn btn-ghost btn-sm text-success"
                          onClick={e => {
                            e.stopPropagation();
                            autoSettle.mutateAsync({ p_match_id: f.id, p_home_score: f.ft_home!, p_away_score: f.ft_away! });
                          }}
                          title="Settle All Pools"
                        >
                          <Gavel size={14} /> Settle
                        </button>
                      )}
                      <button className="btn btn-ghost btn-sm" onClick={e => { e.stopPropagation(); setSelectedFixture(f); }} title="View">
                        <Eye size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="pagination">
            <span>Showing {fixtures.length} of {result?.count ?? 0} fixtures</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={fixtures.length < (result?.pageSize ?? 25)} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      {/* Fixture Detail Drawer */}
      <DetailDrawer
        open={!!selectedFixture}
        title={selectedFixture ? `${selectedFixture.home_team} vs ${selectedFixture.away_team}` : ''}
        subtitle={selectedFixture?.id}
        onClose={() => setSelectedFixture(null)}
        actions={
          selectedFixture && (selectedFixture.status === 'upcoming' || selectedFixture.status === 'live') ? (
            <button
              className="btn btn-primary btn-sm"
              onClick={() => { setResultTarget(selectedFixture); setSettleAndResult(true); }}
            >
              <Target size={14} /> Enter Result & Settle Pools
            </button>
          ) : undefined
        }
      >
        {selectedFixture && (
          <>
            <DrawerSection title="Match Details">
              <DrawerField label="Home Team" value={selectedFixture.home_team} />
              <DrawerField label="Away Team" value={selectedFixture.away_team} />
              <DrawerField label="Competition" value={selectedFixture.competition_id} />
              <DrawerField label="Season" value={selectedFixture.season} />
              <DrawerField label="Round" value={selectedFixture.round || '—'} />
              <DrawerField label="Date" value={formatDateTime(selectedFixture.date)} />
              <DrawerField label="Kickoff" value={selectedFixture.kickoff_time || '—'} />
              <DrawerField label="Venue" value={selectedFixture.venue || '—'} />
              <DrawerField label="Status" value={selectedFixture.status === 'live' ? <span className="badge badge-live">LIVE</span> : <StatusBadge status={selectedFixture.status} />} />
            </DrawerSection>
            {selectedFixture.ft_home !== null && (
              <DrawerSection title="Result">
                <DrawerField label="Full Time" value={<span className="text-lg font-bold mono">{selectedFixture.ft_home} - {selectedFixture.ft_away}</span>} />
                {selectedFixture.ht_home !== null && <DrawerField label="Half Time" value={`${selectedFixture.ht_home} - ${selectedFixture.ht_away}`} />}
              </DrawerSection>
            )}
            <DrawerSection title="Odds">
              <DrawerField label="Home Win" value={selectedFixture.home_multiplier ?? '—'} />
              <DrawerField label="Draw" value={selectedFixture.draw_multiplier ?? '—'} />
              <DrawerField label="Away Win" value={selectedFixture.away_multiplier ?? '—'} />
            </DrawerSection>
            <DrawerSection title="Data Source">
              <DrawerField label="Source" value={selectedFixture.data_source} />
              <DrawerField label="Last Updated" value={formatDateTime(selectedFixture.updated_at)} />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      {/* Enter Result Modal */}
      <EnterResultModal
        open={!!resultTarget}
        matchId={resultTarget?.id ?? ''}
        matchLabel={resultTarget ? `${resultTarget.home_team} vs ${resultTarget.away_team}` : ''}
        onConfirm={handleEnterResult}
        onCancel={() => { setResultTarget(null); setSettleAndResult(false); }}
        isPending={updateResult.isPending || autoSettle.isPending}
        settlePoolsAfter={settleAndResult}
      />
    </div>
  );
}
