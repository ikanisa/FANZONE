// FANZONE Admin — Fixtures Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Match } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useFixtures(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<Match>(['fixtures', filters], 'matches', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<Match>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      return q;
    },
    order: { column: 'date', ascending: false },
  });
}

export function useUpdateFixtureResult() {
  return useRpcMutation<{ p_match_id: string; p_ft_home: number; p_ft_away: number }>({
    fnName: 'admin_update_match_result',
    invalidateKeys: [['fixtures']],
    successMessage: 'Match result recorded.',
  });
}

export function useAutoSettlePools() {
  return useRpcMutation<{ p_match_id: string; p_home_score: number; p_away_score: number }>({
    fnName: 'admin_auto_settle_match',
    invalidateKeys: [['fixtures'], ['challenges'], ['wallets'], ['dashboard-kpis']],
    successMessage: 'All pools for this match have been settled.',
    errorMessage: 'Failed to auto-settle pools.',
  });
}
