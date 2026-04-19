// FANZONE Admin — Predictions Data Hooks
import { useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import { useQuery } from '@tanstack/react-query';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Types ── */
export interface PredictionMarket {
  id: string;
  match_id: string;
  match_name: string;
  market_type: string;
  status: string;
  options_count: number;
  predictions_count: number;
  closes_at: string;
}

export interface PredictionKpis {
  activeMarkets: number;
  totalPredictions24h: number;
  pendingSettlement: number;
  settledToday: number;
}

/* ── Demo Data ── */
const DEMO_MARKETS: PredictionMarket[] = [
  { id: 'm-1', match_id: 'f-001', match_name: 'Valletta vs Floriana', market_type: 'Full-Time Result', status: 'open', options_count: 3, predictions_count: 124, closes_at: '2026-04-19T14:00:00Z' },
  { id: 'm-2', match_id: 'f-003', match_name: 'Liverpool vs Barcelona', market_type: 'Full-Time Result', status: 'open', options_count: 3, predictions_count: 892, closes_at: '2026-04-22T19:00:00Z' },
  { id: 'm-3', match_id: 'f-004', match_name: 'Arsenal vs Man City', market_type: 'Full-Time Result', status: 'locked', options_count: 3, predictions_count: 567, closes_at: '2026-04-18T14:30:00Z' },
  { id: 'm-4', match_id: 'f-005', match_name: 'Real Madrid vs Atletico', market_type: 'Correct Score', status: 'settled', options_count: 15, predictions_count: 234, closes_at: '2026-04-17T19:00:00Z' },
  { id: 'm-5', match_id: 'f-002', match_name: 'Birkirkara vs Ħamrun', market_type: 'Full-Time Result', status: 'open', options_count: 3, predictions_count: 78, closes_at: '2026-04-19T16:00:00Z' },
  { id: 'm-6', match_id: 'f-006', match_name: 'Inter vs Juventus', market_type: 'Full-Time Result', status: 'settled', options_count: 3, predictions_count: 445, closes_at: '2026-04-16T19:45:00Z' },
];

const DEMO_KPIS: PredictionKpis = { activeMarkets: 12, totalPredictions24h: 1847, pendingSettlement: 3, settledToday: 8 };

/* ── Hooks ── */
export function usePredictionMarkets(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<PredictionMarket>(['prediction-markets', filters], 'matches', {
    pagination,
    order: { column: 'date', ascending: false },
    demoData: DEMO_MARKETS.filter(m => {
      if (filters?.status && filters.status !== 'all' && m.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return m.match_name.toLowerCase().includes(q) || m.id.includes(q);
      }
      return true;
    }),
  });
}

export function usePredictionKpis() {
  return useQuery<PredictionKpis>({
    queryKey: ['prediction-kpis'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_KPIS;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);

      const now = new Date();
      const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

      const [
        activeMarketsRes,
        slips24hRes,
        poolEntries24hRes,
        dailyEntries24hRes,
        pendingPoolsRes,
        pendingSlipsRes,
        settledPoolsTodayRes,
        settledSlipsTodayRes,
      ] = await Promise.all([
        supabase
          .from('matches')
          .select('id', { count: 'exact', head: true })
          .gte('date', now.toISOString())
          .neq('status', 'finished'),
        supabase
          .from('prediction_slips')
          .select('id', { count: 'exact', head: true })
          .gte('submitted_at', last24h),
        supabase
          .from('prediction_challenge_entries')
          .select('id', { count: 'exact', head: true })
          .gte('joined_at', last24h),
        supabase
          .from('daily_challenge_entries')
          .select('id', { count: 'exact', head: true })
          .gte('submitted_at', last24h),
        supabase
          .from('prediction_challenges')
          .select('id', { count: 'exact', head: true })
          .in('status', ['open', 'locked']),
        supabase
          .from('prediction_slips')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'submitted'),
        supabase
          .from('prediction_challenges')
          .select('id', { count: 'exact', head: true })
          .gte('settled_at', startOfDay),
        supabase
          .from('prediction_slips')
          .select('id', { count: 'exact', head: true })
          .gte('settled_at', startOfDay),
      ]);

      const responses = [
        activeMarketsRes,
        slips24hRes,
        poolEntries24hRes,
        dailyEntries24hRes,
        pendingPoolsRes,
        pendingSlipsRes,
        settledPoolsTodayRes,
        settledSlipsTodayRes,
      ];
      const failed = responses.find((response) => response.error);
      if (failed?.error) throw new Error(failed.error.message);

      return {
        activeMarkets: activeMarketsRes.count ?? 0,
        totalPredictions24h:
          (slips24hRes.count ?? 0) +
          (poolEntries24hRes.count ?? 0) +
          (dailyEntries24hRes.count ?? 0),
        pendingSettlement:
          (pendingPoolsRes.count ?? 0) +
          (pendingSlipsRes.count ?? 0),
        settledToday:
          (settledPoolsTodayRes.count ?? 0) +
          (settledSlipsTodayRes.count ?? 0),
      };
    },
    refetchInterval: 120_000,
  });
}
