// FANZONE Admin — Analytics Data Hooks
import { useQuery } from '@tanstack/react-query';
import { runAdminRpc } from '../../lib/adminData';

/* ── Types ── */
export interface EngagementDay {
  day: string;
  dau: number;
  predictions: number;
  pools: number;
}

export interface FetFlowWeek {
  week: string;
  issued: number;
  transferred: number;
  redeemed: number;
  staked: number;
}

export interface CompetitionShare {
  name: string;
  value: number;
  color: string;
}

export interface EngagementKpis {
  dau: number;
  wau: number;
  mau: number;
  predictions7d: number;
  fetVolume7d: number;
}

/* ── Hooks ── */
export function useEngagementKpis() {
  return useQuery<EngagementKpis>({
    queryKey: ['analytics-kpis'],
    queryFn: async () => runAdminRpc<EngagementKpis>('admin_engagement_kpis'),
    refetchInterval: 300_000,
  });
}

export function useEngagementChart() {
  return useQuery<EngagementDay[]>({
    queryKey: ['analytics-engagement'],
    queryFn: async () =>
      (await runAdminRpc<EngagementDay[]>('admin_engagement_daily', {
        p_days: 7,
      })) ?? [],
  });
}

export function useFetFlowChart() {
  return useQuery<FetFlowWeek[]>({
    queryKey: ['analytics-fet-flow'],
    queryFn: async () =>
      (await runAdminRpc<FetFlowWeek[]>('admin_fet_flow_weekly', {
        p_weeks: 4,
      })) ?? [],
  });
}

export function useCompetitionDistribution() {
  return useQuery<CompetitionShare[]>({
    queryKey: ['analytics-competition'],
    queryFn: async () => {
      const data = await runAdminRpc<CompetitionShare[]>(
        'admin_competition_distribution',
        { p_days: 30 },
      );
      return data ?? [];
    },
  });
}
