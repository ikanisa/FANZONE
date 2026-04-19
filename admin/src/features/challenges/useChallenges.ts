// FANZONE Admin — Challenges (Pools) Data Hooks
import {
  useSupabasePaginated,
  useSupabaseList,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Challenge, ChallengeEntry } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */

export function useChallenges(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<Challenge>(['challenges', filters], 'prediction_challenges', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<Challenge>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
  });
}

export function useChallengeEntries(challengeId: string | null) {
  return useSupabaseList<ChallengeEntry>(
    ['challenge-entries', challengeId],
    'prediction_challenge_entries',
    {
      filters: (query: AdminListQuery<ChallengeEntry>) =>
        query.eq('challenge_id', challengeId),
      order: { column: 'joined_at', ascending: true },
      enabled: !!challengeId,
    },
  );
}

export function useSettlePool() {
  return useRpcMutation<{ p_pool_id: string; p_official_home_score: number; p_official_away_score: number }>({
    fnName: 'settle_pool',
    invalidateKeys: [['challenges'], ['challenge-entries'], ['dashboard-kpis']],
    successMessage: 'Pool settled successfully. FET distributed to winners.',
    errorMessage: 'Failed to settle pool.',
  });
}

export function useVoidPool() {
  return useRpcMutation<{ p_pool_id: string; p_reason: string }>({
    fnName: 'void_pool',
    invalidateKeys: [['challenges'], ['challenge-entries'], ['dashboard-kpis']],
    successMessage: 'Pool voided. All stakes refunded.',
    errorMessage: 'Failed to void pool.',
  });
}
