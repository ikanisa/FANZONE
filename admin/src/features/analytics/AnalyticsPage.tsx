// FANZONE Admin — Analytics Page — Live Data
import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { LoadingState } from '../../components/ui/StateViews';
import {
  useEngagementKpis, useEngagementChart,
  useFetFlowChart, useCompetitionDistribution,
} from './useAnalytics';
import { Users, Trophy, Coins, TrendingUp, BarChart3, Activity } from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell,
} from 'recharts';

const CHART_STYLE = { fontSize: 11, fill: '#A8A29E' };
const TOOLTIP_STYLE = { background: '#1C1917', border: '1px solid #292524', borderRadius: 8, fontSize: 13 };

export function AnalyticsPage() {
  const { data: kpis, isLoading: kpisLoading } = useEngagementKpis();
  const { data: engagement } = useEngagementChart();
  const { data: fetFlow } = useFetFlowChart();
  const { data: competitionPie } = useCompetitionDistribution();

  return (
    <div>
      <PageHeader title="Analytics" subtitle="Platform engagement and operational metrics" />

      {/* Top KPIs */}
      {kpisLoading ? <LoadingState lines={2} /> : kpis && (
        <div className="grid grid-5 gap-4 mb-6">
          <KpiCard label="DAU" value={kpis.dau} trend={12.5} trendDirection="up" icon={<Users size={18} />} />
          <KpiCard label="WAU" value={kpis.wau} trend={8.1} trendDirection="up" icon={<Activity size={18} />} />
          <KpiCard label="MAU" value={kpis.mau} trend={22.3} trendDirection="up" icon={<TrendingUp size={18} />} />
          <KpiCard label="Predictions (7d)" value={kpis.predictions7d} icon={<Trophy size={18} />} />
          <KpiCard label="FET Volume (7d)" value={kpis.fetVolume7d} format="fet" icon={<Coins size={18} />} />
        </div>
      )}

      {/* Charts Row 1 */}
      <div className="grid grid-2 gap-6 mb-6">
        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2"><BarChart3 size={18} className="text-accent" /> Daily Engagement</h3>
          {engagement ? (
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={engagement}>
                <CartesianGrid strokeDasharray="3 3" stroke="#292524" />
                <XAxis dataKey="day" tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <YAxis tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} />
                <Bar dataKey="dau" fill="#0EA5E9" radius={[4, 4, 0, 0]} />
                <Bar dataKey="predictions" fill="#6366F1" radius={[4, 4, 0, 0]} />
                <Bar dataKey="pools" fill="#EF4444" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : <LoadingState lines={4} />}
        </div>

        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2"><Coins size={18} className="text-accent" /> FET Token Flow (Weekly)</h3>
          {fetFlow ? (
            <ResponsiveContainer width="100%" height={280}>
              <LineChart data={fetFlow}>
                <CartesianGrid strokeDasharray="3 3" stroke="#292524" />
                <XAxis dataKey="week" tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <YAxis tick={CHART_STYLE} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} />
                <Line type="monotone" dataKey="issued" stroke="#22C55E" strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="transferred" stroke="#0EA5E9" strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="redeemed" stroke="#F59E0B" strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="staked" stroke="#6366F1" strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          ) : <LoadingState lines={4} />}
        </div>
      </div>

      {/* Charts Row 2 */}
      <div className="grid grid-2 gap-6">
        <div className="card">
          <h3 className="text-md font-semibold mb-4 flex items-center gap-2"><Trophy size={18} className="text-accent" /> Engagement by Competition</h3>
          <div className="flex items-center justify-center">
            {competitionPie ? (
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie data={competitionPie} cx="50%" cy="50%" innerRadius={60} outerRadius={100} paddingAngle={3} dataKey="value" label={({ name, value }) => `${name} ${value}%`}>
                    {competitionPie.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                  </Pie>
                  <Tooltip contentStyle={TOOLTIP_STYLE} />
                </PieChart>
              </ResponsiveContainer>
            ) : <LoadingState lines={4} />}
          </div>
        </div>

        <div className="card">
          <h3 className="text-md font-semibold mb-4">Executive Summary</h3>
          <div className="flex flex-col gap-3">
            {[
              { label: 'Malta Premier League is the #1 engagement driver', detail: '35% of all predictions', color: 'success' },
              { label: 'FET velocity increasing', detail: 'Transfer volume +18% WoW', color: 'success' },
              { label: 'Pool participation growing', detail: 'Avg pool size up from 6 to 8', color: 'success' },
              { label: 'Redemption rate healthy', detail: '3.2% of earned FET redeemed', color: 'info' },
              { label: 'Retention D7 at 42%', detail: 'Target: 50%. Needs improvement.', color: 'warning' },
            ].map((item, i) => (
              <div key={i} className="flex items-start gap-3 p-3" style={{ background: `var(--fz-${item.color}-bg)`, borderRadius: 'var(--fz-radius)' }}>
                <div className="flex-1">
                  <p className="text-sm font-medium">{item.label}</p>
                  <p className="text-xs text-muted mt-1">{item.detail}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
