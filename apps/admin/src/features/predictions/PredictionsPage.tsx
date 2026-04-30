import { useState } from "react";
import { CheckCircle, Clock, Search, Target, TrendingUp } from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { DetailDrawer, DrawerField, DrawerSection } from "../../components/ui/DetailDrawer";
import { KpiCard } from "../../components/ui/KpiCard";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateViews";
import { formatDateTime } from "../../lib/formatters";
import { usePredictionFixtures, usePredictionKpis, type PredictionFixtureSurface } from "./usePredictions";

function formatResultCode(resultCode: string | null) {
  if (resultCode === "H") return "Home";
  if (resultCode === "D") return "Draw";
  if (resultCode === "A") return "Away";
  return "—";
}

export function PredictionsPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [selected, setSelected] = useState<PredictionFixtureSurface | null>(null);

  const { data: result, isLoading, error, refetch } = usePredictionFixtures(
    { page },
    { status: statusFilter, search },
  );
  const { data: kpis } = usePredictionKpis();
  const fixtures = result?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Predictions"
        subtitle="Lean engine outputs, pick participation, and scoring status"
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Open Fixtures" value={kpis?.openFixtures ?? 0} icon={<Target size={18} />} />
        <KpiCard label="Picks (24h)" value={kpis?.totalPredictions24h ?? 0} trend={12.4} trendDirection="up" icon={<TrendingUp size={18} />} />
        <KpiCard label="Pending Scoring" value={kpis?.pendingSettlement ?? 0} icon={<Clock size={18} />} />
        <KpiCard label="Rewards Today" value={kpis?.settledToday ?? 0} icon={<CheckCircle size={18} />} />
      </div>

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
            placeholder="Search prediction fixtures..."
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
          <option value="upcoming">Upcoming</option>
          <option value="live">Live</option>
          <option value="finished">Finished</option>
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={5} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : fixtures.length === 0 ? (
        <EmptyState title="No prediction fixtures found" />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Match</th>
                <th>Competition</th>
                <th>Picks</th>
                <th>Engine</th>
                <th>Kickoff</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {fixtures.map((fixture) => (
                <tr
                  key={fixture.id}
                  className="cursor-pointer"
                  onClick={() => setSelected(fixture)}
                >
                  <td className="font-medium">{fixture.match_name}</td>
                  <td>{fixture.competition_name}</td>
                  <td className="font-semibold">{fixture.predictions_count.toLocaleString()}</td>
                  <td>
                    {fixture.engine_status === "ready" ? (
                      <span className="badge badge-success">
                        {fixture.confidence_label ?? "ready"}
                      </span>
                    ) : (
                      <span className="badge badge-neutral">missing</span>
                    )}
                  </td>
                  <td className="text-muted">{formatDateTime(fixture.closes_at)}</td>
                  <td><StatusBadge status={fixture.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="pagination">
            <span>Showing {fixtures.length} of {result?.count ?? 0} fixtures</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage((value) => value - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button className="pagination-btn" disabled={fixtures.length < (result?.pageSize ?? 25)} onClick={() => setPage((value) => value + 1)}>→</button>
            </div>
          </div>
        </div>
      )}

      <DetailDrawer
        open={!!selected}
        title={selected?.match_name ?? "Prediction"}
        subtitle={selected?.match_id}
        onClose={() => setSelected(null)}
      >
        {selected && (
          <>
            <DrawerSection title="Prediction Surface">
              <DrawerField label="Competition" value={selected.competition_name} />
              <DrawerField label="Kickoff" value={formatDateTime(selected.closes_at)} />
              <DrawerField label="Status" value={<StatusBadge status={selected.status} />} />
              <DrawerField label="User picks" value={selected.predictions_count.toLocaleString()} />
            </DrawerSection>
            <DrawerSection title="Engine Output">
              <DrawerField label="Engine status" value={selected.engine_status} />
              <DrawerField label="Confidence" value={selected.confidence_label ?? "—"} />
              <DrawerField label="Top result" value={formatResultCode(selected.top_result_code)} />
            </DrawerSection>
            <DrawerSection title="Crowd Consensus">
              <DrawerField label="Home" value={selected.consensus_home_pct !== null ? `${selected.consensus_home_pct}%` : "—"} />
              <DrawerField label="Draw" value={selected.consensus_draw_pct !== null ? `${selected.consensus_draw_pct}%` : "—"} />
              <DrawerField label="Away" value={selected.consensus_away_pct !== null ? `${selected.consensus_away_pct}%` : "—"} />
            </DrawerSection>
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
