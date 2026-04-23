import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { BarChart3, Coins, Trophy } from "lucide-react";

import { LoadingState } from "../../components/ui/StateViews";
import type {
  CompetitionShare,
  EngagementDay,
  FetFlowWeek,
} from "./useAnalytics";

const CHART_STYLE = { fontSize: 11, fill: "#A8A29E" };
const TOOLTIP_STYLE = {
  background: "#1C1917",
  border: "1px solid #292524",
  borderRadius: 8,
  fontSize: 13,
};

const PIE_COLORS = [
  "var(--fz-primary)",
  "var(--fz-secondary)",
  "var(--fz-error)",
  "var(--fz-primary-strong)",
  "var(--fz-secondary-strong)",
];

interface AnalyticsChartsProps {
  engagement?: EngagementDay[];
  fetFlow?: FetFlowWeek[];
  competitionPie?: CompetitionShare[];
}

export function AnalyticsCharts({
  engagement,
  fetFlow,
  competitionPie,
}: AnalyticsChartsProps) {
  return (
    <>
      <div className="grid grid-2 gap-6 mb-6">
        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
            <BarChart3 size={18} className="text-primary" /> Daily Engagement
          </h3>
          {engagement ? (
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={engagement}>
                <CartesianGrid strokeDasharray="3 3" stroke="#292524" />
                <XAxis
                  dataKey="day"
                  tick={CHART_STYLE}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} />
                <Bar
                  dataKey="dau"
                  fill="var(--fz-primary)"
                  radius={[4, 4, 0, 0]}
                />
                <Bar
                  dataKey="predictions"
                  fill="var(--fz-secondary)"
                  radius={[4, 4, 0, 0]}
                />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <LoadingState lines={4} />
          )}
        </div>

        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
            <Coins size={18} className="text-primary" /> FET Token Flow (Weekly)
          </h3>
          {fetFlow ? (
            <ResponsiveContainer width="100%" height={280}>
              <LineChart data={fetFlow}>
                <CartesianGrid strokeDasharray="3 3" stroke="#292524" />
                <XAxis
                  dataKey="week"
                  tick={CHART_STYLE}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} />
                <Line
                  type="monotone"
                  dataKey="issued"
                  stroke="var(--fz-primary)"
                  strokeWidth={2}
                  dot={false}
                />
                <Line
                  type="monotone"
                  dataKey="transferred"
                  stroke="var(--fz-secondary)"
                  strokeWidth={2}
                  dot={false}
                />
                <Line
                  type="monotone"
                  dataKey="adjusted"
                  stroke="var(--fz-error)"
                  strokeWidth={2}
                  dot={false}
                />
                <Line
                  type="monotone"
                  dataKey="rewarded"
                  stroke="var(--fz-primary-strong)"
                  strokeWidth={2}
                  dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <LoadingState lines={4} />
          )}
        </div>
      </div>

      <div className="grid grid-2 gap-6">
        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
            <Trophy size={18} className="text-primary" /> Engagement by
            Competition
          </h3>
          <div className="flex items-center justify-center">
            {competitionPie ? (
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie
                    data={competitionPie}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    paddingAngle={3}
                    dataKey="value"
                    label={({ name, value }) => `${name} ${value}%`}
                  >
                    {competitionPie.map((_, index) => (
                      <Cell
                        key={index}
                        fill={PIE_COLORS[index % PIE_COLORS.length]}
                      />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={TOOLTIP_STYLE} />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <LoadingState lines={4} />
            )}
          </div>
        </div>

        <div className="card">
          <h3 className="text-md font-semibold mb-4">Executive Summary</h3>
          <div className="flex flex-col gap-3">
            {[
              {
                label: "Top competition engagement remains concentrated",
                detail: "35% of all predictions",
                color: "success",
              },
              {
                label: "FET velocity increasing",
                detail: "Transfer volume +18% WoW",
                color: "success",
              },
              {
                label: "Prediction participation growing",
                detail: "More users are saving match picks each week",
                color: "success",
              },
              {
                label: "Reward flow is settling cleanly",
                detail: "Weekly FET awards are landing without legacy redemption debt",
                color: "info",
              },
              {
                label: "Retention D7 at 42%",
                detail: "Target: 50%. Needs improvement.",
                color: "warning",
              },
            ].map((item, index) => (
              <div
                key={index}
                className="flex items-start gap-3 p-3"
                style={{
                  background: `var(--fz-${item.color}-bg)`,
                  borderRadius: "var(--fz-radius)",
                }}
              >
                <div className="flex-1">
                  <p className="text-sm font-medium">{item.label}</p>
                  <p className="text-xs text-muted mt-1">{item.detail}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
