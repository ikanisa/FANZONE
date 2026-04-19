// FANZONE Admin — Analytics Data Hooks
import { useQuery } from '@tanstack/react-query';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';

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

/* ── Demo Data ── */
const DEMO_ENGAGEMENT: EngagementDay[] = [
  { day: 'Mon', dau: 1240, predictions: 340, pools: 45 },
  { day: 'Tue', dau: 1380, predictions: 380, pools: 52 },
  { day: 'Wed', dau: 1520, predictions: 420, pools: 48 },
  { day: 'Thu', dau: 1680, predictions: 510, pools: 63 },
  { day: 'Fri', dau: 2100, predictions: 620, pools: 78 },
  { day: 'Sat', dau: 3200, predictions: 890, pools: 112 },
  { day: 'Sun', dau: 2800, predictions: 780, pools: 95 },
];

const DEMO_FET_FLOW: FetFlowWeek[] = [
  { week: 'W13', issued: 180000, transferred: 45000, redeemed: 12000, staked: 32000 },
  { week: 'W14', issued: 195000, transferred: 52000, redeemed: 15000, staked: 38000 },
  { week: 'W15', issued: 210000, transferred: 68000, redeemed: 18000, staked: 45000 },
  { week: 'W16', issued: 245000, transferred: 78000, redeemed: 22000, staked: 52000 },
];

const DEMO_COMPETITION_PIE: CompetitionShare[] = [
  { name: 'MPL', value: 35, color: '#EF4444' },
  { name: 'UCL', value: 28, color: '#0EA5E9' },
  { name: 'EPL', value: 22, color: '#6366F1' },
  { name: 'LaLiga', value: 10, color: '#F59E0B' },
  { name: 'Other', value: 5, color: '#44403C' },
];

const DEMO_KPIS: EngagementKpis = {
  dau: 3847,
  wau: 8920,
  mau: 14200,
  predictions7d: 3940,
  fetVolume7d: 830000,
};

/* ── Hooks ── */
export function useEngagementKpis() {
  return useQuery<EngagementKpis>({
    queryKey: ['analytics-kpis'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_KPIS;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { data, error } = await supabase.rpc('admin_engagement_kpis');
      if (error) throw new Error(error.message);
      return data as EngagementKpis;
    },
    refetchInterval: 300_000,
  });
}

export function useEngagementChart() {
  return useQuery<EngagementDay[]>({
    queryKey: ['analytics-engagement'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_ENGAGEMENT;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { data, error } = await supabase.rpc('admin_engagement_daily', { p_days: 7 });
      if (error) throw new Error(error.message);
      return (data as EngagementDay[]) ?? DEMO_ENGAGEMENT;
    },
  });
}

export function useFetFlowChart() {
  return useQuery<FetFlowWeek[]>({
    queryKey: ['analytics-fet-flow'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_FET_FLOW;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { data, error } = await supabase.rpc('admin_fet_flow_weekly', { p_weeks: 4 });
      if (error) throw new Error(error.message);
      return (data as FetFlowWeek[]) ?? DEMO_FET_FLOW;
    },
  });
}

export function useCompetitionDistribution() {
  return useQuery<CompetitionShare[]>({
    queryKey: ['analytics-competition'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_COMPETITION_PIE;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { data, error } = await supabase.rpc('admin_competition_distribution', { p_days: 30 });
      if (error) throw new Error(error.message);
      return (data as CompetitionShare[])?.length ? (data as CompetitionShare[]) : DEMO_COMPETITION_PIE;
    },
  });
}
