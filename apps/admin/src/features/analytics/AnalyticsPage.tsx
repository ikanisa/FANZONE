import { lazy, Suspense } from 'react';

import { PageHeader } from '../../components/layout/PageHeader';
import { KpiCard } from '../../components/ui/KpiCard';
import { LoadingState } from '../../components/ui/StateViews';
import {
  useEngagementKpis, useEngagementChart,
  useFetFlowChart, useCompetitionDistribution,
} from './useAnalytics';
import { Users, Trophy, Coins, TrendingUp, Activity } from 'lucide-react';

const AnalyticsCharts = lazy(async () => {
  const module = await import('./AnalyticsCharts');
  return { default: module.AnalyticsCharts };
});

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

      <Suspense fallback={<LoadingState lines={8} />}>
        <AnalyticsCharts
          engagement={engagement}
          fetFlow={fetFlow}
          competitionPie={competitionPie}
        />
      </Suspense>
    </div>
  );
}
