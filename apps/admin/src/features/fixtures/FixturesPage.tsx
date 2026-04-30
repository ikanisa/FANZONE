import { useState } from "react";
import { Calendar, Eye, Plus, Search, Target, Upload } from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { DetailDrawer, DrawerField, DrawerSection } from "../../components/ui/DetailDrawer";
import { UnavailableActionButton } from "../../components/ui/UnavailableActionButton";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateViews";
import { formatDate, formatDateTime, formatKickoffTime } from "../../lib/formatters";
import type { Match } from "../../types";
import { EnterResultModal } from "./EnterResultModal";
import { useFixtures, useUpdateFixtureResult } from "./useFixtures";

export function FixturesPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedFixture, setSelectedFixture] = useState<Match | null>(null);
  const [resultTarget, setResultTarget] = useState<Match | null>(null);

  const {
    data: result,
    isLoading,
    error,
    refetch,
  } = useFixtures({ page }, { status: statusFilter, search });
  const updateResult = useUpdateFixtureResult();

  const fixtures = result?.data ?? [];

  async function handleEnterResult(homeGoals: number, awayGoals: number) {
    if (!resultTarget) return;

    await updateResult.mutateAsync({
      p_match_id: resultTarget.id,
      p_home_goals: homeGoals,
      p_away_goals: awayGoals,
    });

    setResultTarget(null);
    setSelectedFixture(null);
  }

  return (
    <div>
      <PageHeader
        title="Fixtures"
        subtitle="Lean match schedule, result entry, and scoring control"
        actions={
          <>
            <UnavailableActionButton
              icon={<Upload size={16} />}
              label="CSV Import"
              title="Use the new football data import edge function for bulk CSV ingestion."
              variant="secondary"
            />
            <UnavailableActionButton
              icon={<Plus size={16} />}
              label="Manual Add"
              title="Fixtures are expected to be loaded through the CSV import workflow."
            />
          </>
        }
      />

      <div className="filter-bar mb-4">
        <div style={{ position: "relative", maxWidth: 320 }}>
          <Search
            size={16}
            style={{
              position: "absolute",
              left: 12,
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--fz-muted-2)",
            }}
          />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search fixtures..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(0);
            }}
          />
        </div>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={statusFilter}
          onChange={(event) => {
            setStatusFilter(event.target.value);
            setPage(0);
          }}
        >
          <option value="all">All statuses</option>
          <option value="scheduled">Scheduled</option>
          <option value="live">Live</option>
          <option value="finished">Finished</option>
          <option value="postponed">Postponed</option>
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : fixtures.length === 0 ? (
        <EmptyState title="No fixtures found" />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Match</th>
                <th>Competition</th>
                <th>Date</th>
                <th>Kickoff</th>
                <th>Score</th>
                <th>Status</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {fixtures.map((fixture) => {
                const isFinished = fixture.status === "finished";
                return (
                  <tr
                    key={fixture.id}
                    className="cursor-pointer"
                    onClick={() => setSelectedFixture(fixture)}
                  >
                    <td>
                      <div className="font-medium">
                        {fixture.home_team} vs {fixture.away_team}
                      </div>
                      <div className="text-xs text-muted mono">{fixture.id}</div>
                    </td>
                    <td>{fixture.competition_name ?? fixture.competition_id}</td>
                    <td>
                      <span className="flex items-center gap-1">
                        <Calendar size={14} className="text-muted" />
                        {formatDate(fixture.date)}
                      </span>
                    </td>
                    <td>{formatKickoffTime(fixture.date, fixture.kickoff_time)}</td>
                    <td className="font-semibold mono">
                      {fixture.ft_home !== null ? `${fixture.ft_home} - ${fixture.ft_away}` : "—"}
                    </td>
                    <td>
                      {fixture.status === "live" ? (
                        <span className="badge badge-live">LIVE</span>
                      ) : (
                        <StatusBadge status={fixture.status} />
                      )}
                    </td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        {!isFinished && (
                          <button
                            className="btn btn-ghost btn-sm text-success"
                            onClick={(event) => {
                              event.stopPropagation();
                              setResultTarget(fixture);
                            }}
                            title="Enter Result"
                          >
                            <Target size={14} /> Result
                          </button>
                        )}
                        <button
                          className="btn btn-ghost btn-sm"
                          onClick={(event) => {
                            event.stopPropagation();
                            setSelectedFixture(fixture);
                          }}
                          title="View Details"
                        >
                          <Eye size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          <div className="pagination">
            <span>Showing {fixtures.length} of {result?.count ?? 0} fixtures</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage((value) => value - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button
                className="pagination-btn"
                disabled={fixtures.length < (result?.pageSize ?? 25)}
                onClick={() => setPage((value) => value + 1)}
              >
                →
              </button>
            </div>
          </div>
        </div>
      )}

      <DetailDrawer
        open={!!selectedFixture}
        title={
          selectedFixture
            ? `${selectedFixture.home_team} vs ${selectedFixture.away_team}`
            : "Fixture"
        }
        subtitle={selectedFixture?.id}
        onClose={() => setSelectedFixture(null)}
        actions={
          selectedFixture && selectedFixture.status !== "finished" ? (
            <button
              className="btn btn-primary btn-sm"
              onClick={() => setResultTarget(selectedFixture)}
            >
              <Target size={14} /> Enter Result
            </button>
          ) : undefined
        }
      >
        {selectedFixture && (
          <>
            <DrawerSection title="Fixture">
              <DrawerField label="Competition" value={selectedFixture.competition_name ?? selectedFixture.competition_id} />
              <DrawerField label="Season" value={selectedFixture.season_label ?? selectedFixture.season ?? "—"} />
              <DrawerField label="Stage / Round" value={selectedFixture.stage ?? selectedFixture.round ?? "—"} />
              <DrawerField label="Kickoff" value={formatDateTime(selectedFixture.date)} />
              <DrawerField label="Status" value={<StatusBadge status={selectedFixture.status} />} />
              <DrawerField label="Result code" value={selectedFixture.result_code ?? "—"} />
              <DrawerField
                label="Score"
                value={
                  selectedFixture.ft_home !== null
                    ? `${selectedFixture.ft_home} - ${selectedFixture.ft_away}`
                    : "—"
                }
              />
            </DrawerSection>
            <DrawerSection title="Source">
              <DrawerField label="Source" value={selectedFixture.source_name ?? selectedFixture.data_source ?? "—"} />
              <DrawerField label="Source URL" value={selectedFixture.source_url ?? "—"} />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>

      <EnterResultModal
        open={!!resultTarget}
        matchId={resultTarget?.id ?? ""}
        matchLabel={
          resultTarget
            ? `${resultTarget.home_team} vs ${resultTarget.away_team}`
            : ""
        }
        onConfirm={handleEnterResult}
        onCancel={() => setResultTarget(null)}
        isPending={updateResult.isPending}
      />
    </div>
  );
}
