// FANZONE Admin — Dashboard Page — Live Data
import { PageHeader } from "../../components/layout/PageHeader";
import { renderFanzoneText } from "../../components/renderFanzoneText";
import { KpiCard } from "../../components/ui/KpiCard";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { LoadingState } from "../../components/ui/StateViews";
import {
  useDashboardKpis,
  useRecentActivity,
  useSystemAlerts,
} from "./useDashboard";
import { formatRelativeTime, formatFET } from "../../lib/formatters";
import {
  Coins,
  Wallet,
  ShoppingBag,
  Trophy,
  Shield,
  Activity,
  Clock,
  Globe2,
  Building2,
  AlertTriangle,
} from "lucide-react";
import { Link } from "react-router-dom";

export function DashboardPage() {
  const { data: kpis, isLoading: kpisLoading } = useDashboardKpis();
  const { data: activity, isLoading: activityLoading } = useRecentActivity();
  const { data: alerts } = useSystemAlerts();

  return (
    <div>
      <PageHeader
        title="Control Center"
        subtitle={renderFanzoneText("Curate matches, monitor pools, audit sensitive actions, and operate venues")}
        actions={
          <>
            <Link className="btn btn-secondary" to="/matches">
              Curate Matches
            </Link>
            <Link className="btn btn-primary" to="/pools">
              Pool Operations
            </Link>
          </>
        }
      />

      {/* KPI Grid */}
      {kpisLoading ? (
        <LoadingState lines={2} />
      ) : (
        kpis && (
          <div className="grid grid-4 gap-4 mb-6">
            <KpiCard
              label="Countries"
              value={kpis.activeCountries}
              icon={<Globe2 size={18} />}
            />
            <KpiCard
              label="Venues"
              value={kpis.activeVenues}
              icon={<Building2 size={18} />}
            />
            <KpiCard
              label="Active Pools"
              value={kpis.activePools}
              icon={<Trophy size={18} />}
            />
            <KpiCard
              label="FET Issued"
              value={kpis.totalFetIssued}
              format="fet"
              icon={<Coins size={18} />}
            />
            <KpiCard
              label="FET Staked"
              value={kpis.totalFetStaked}
              format="fet"
              icon={<Wallet size={18} />}
            />
            <KpiCard
              label="Pending Settlement"
              value={kpis.pendingSettlements}
              icon={<ShoppingBag size={18} />}
            />
            <KpiCard
              label="Failed Settlements"
              value={kpis.failedSettlements}
              icon={<AlertTriangle size={18} />}
            />
            <KpiCard
              label="Orders Today"
              value={kpis.todaysOrders}
              icon={<ShoppingBag size={18} />}
            />
            <KpiCard
              label="Risk Alerts"
              value={kpis.riskAlerts}
              icon={<Shield size={18} />}
            />
          </div>
        )
      )}

      <div className="grid grid-2 gap-6">
        {/* Recent Activity */}
        <div className="card">
          <div className="flex items-center gap-2 mb-4">
            <Activity size={18} className="text-primary" />
            <h2 className="text-md font-semibold">Recent Activity</h2>
          </div>
          {activityLoading ? (
            <LoadingState lines={5} />
          ) : (
            <div className="flex flex-col">
              {(activity ?? []).map((item) => (
                <div
                  key={item.id}
                  className="flex items-center justify-between py-3 border-b"
                  style={{ borderColor: "var(--fz-border)" }}
                >
                  <div className="flex-1 min-w-0">
                    <span className="text-sm">
                      <span className="font-medium">
                        {item.admin_name || "System"}
                      </span>{" "}
                      <code
                        className="mono text-xs"
                        style={{
                          background: "var(--fz-surface-2)",
                          padding: "1px 4px",
                          borderRadius: 3,
                        }}
                      >
                        {item.action}
                      </code>
                      {item.target_type && (
                        <>
                          {" on "}
                          <span
                            className="badge badge-neutral"
                            style={{ fontSize: 10, padding: "0 4px" }}
                          >
                            {item.target_type}
                          </span>{" "}
                          <span className="text-xs text-muted mono">
                            {item.target_id}
                          </span>
                        </>
                      )}
                    </span>
                  </div>
                  <span className="text-xs text-muted flex items-center gap-1 flex-shrink-0 ml-4">
                    <Clock size={12} />
                    {formatRelativeTime(item.created_at)}
                  </span>
                </div>
              ))}
              {(!activity || activity.length === 0) && (
                <p className="text-sm text-muted py-4 text-center">
                  No recent activity.
                </p>
              )}
            </div>
          )}
        </div>

        {/* Alerts & Action Items */}
        <div className="card">
          <div className="flex items-center gap-2 mb-4">
            <Shield size={18} className="text-warning" />
            <h2 className="text-md font-semibold">Alerts & Actions</h2>
          </div>
          <div className="flex flex-col gap-3">
            {(alerts ?? []).length > 0 ? (
              (alerts ?? []).map((alert) => (
                <div
                  key={alert.id}
                  className="flex items-start gap-3 p-3"
                  style={{
                    background:
                      alert.severity === "critical"
                        ? "var(--fz-error-bg)"
                        : alert.severity === "warning"
                          ? "var(--fz-warning-bg)"
                          : "var(--fz-info-bg)",
                    borderRadius: "var(--fz-radius)",
                  }}
                >
                  <StatusBadge status={alert.severity} />
                  <div className="flex-1">
                    <p className="text-sm font-medium">{alert.message}</p>
                    <p className="text-xs text-muted mt-1">{alert.module}</p>
                  </div>
                </div>
              ))
            ) : (
              <div
                className="flex items-center gap-3 p-3"
                style={{
                  background: "var(--fz-success-bg)",
                  borderRadius: "var(--fz-radius)",
                }}
              >
                <StatusBadge status="active" />
                <div>
                  <p className="text-sm font-medium">All clear</p>
                  <p className="text-xs text-muted mt-1">
                    No alerts or actions needed.
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Platform Health */}
          {kpis && (
            <div className="mt-6">
              <h3
                className="text-xs font-semibold text-muted uppercase mb-3"
                style={{ letterSpacing: "0.05em" }}
              >
                Platform Health
              </h3>
              <div className="flex flex-col gap-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted">FET Circulation</span>
                  <span className="font-medium">
                    {formatFET(kpis.totalFetIssued)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted">Open Pools</span>
                  <span className="font-medium">
                    {kpis.activePools}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted">Pending Settlements</span>
                  <span className="font-medium">{kpis.pendingSettlements}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted">Moderation Queue</span>
                  <span
                    className={`font-medium ${kpis.riskAlerts > 0 ? "text-warning" : "text-success"}`}
                  >
                    {kpis.riskAlerts}
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
