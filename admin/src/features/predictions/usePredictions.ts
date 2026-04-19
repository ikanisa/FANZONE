// FANZONE Admin — Predictions Data Hooks
import { useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import { useQuery } from '@tanstack/react-query';
import { countAdminRows } from '../../lib/adminData';
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

/* ── Hooks ── */
export function usePredictionMarkets(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<PredictionMarket>(['prediction-markets', filters], 'matches', {
    pagination,
    order: { column: 'date', ascending: false },
  });
}

export function usePredictionKpis() {
  return useQuery<PredictionKpis>({
    queryKey: ['prediction-kpis'],
    queryFn: async () => {
      const now = new Date();
      const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

      const [
        activeMarkets,
        slips24h,
        poolEntries24h,
        dailyEntries24h,
        pendingPools,
        pendingSlips,
        settledPoolsToday,
        settledSlipsToday,
      ] = await Promise.all([
        countAdminRows('matches', (query) =>
          query.gte('date', now.toISOString()).neq('status', 'finished'),
        ),
        countAdminRows('prediction_slips', (query) =>
          query.gte('submitted_at', last24h),
        ),
        countAdminRows('prediction_challenge_entries', (query) =>
          query.gte('joined_at', last24h),
        ),
        countAdminRows('daily_challenge_entries', (query) =>
          query.gte('submitted_at', last24h),
        ),
        countAdminRows('prediction_challenges', (query) =>
          query.in('status', ['open', 'locked']),
        ),
        countAdminRows('prediction_slips', (query) =>
          query.eq('status', 'submitted'),
        ),
        countAdminRows('prediction_challenges', (query) =>
          query.gte('settled_at', startOfDay),
        ),
        countAdminRows('prediction_slips', (query) =>
          query.gte('settled_at', startOfDay),
        ),
      ]);

      return {
        activeMarkets,
        totalPredictions24h: slips24h + poolEntries24h + dailyEntries24h,
        pendingSettlement: pendingPools + pendingSlips,
        settledToday: settledPoolsToday + settledSlipsToday,
      };
    },
    refetchInterval: 120_000,
  });
}
