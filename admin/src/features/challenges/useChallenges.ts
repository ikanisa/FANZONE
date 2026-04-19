// FANZONE Admin — Challenges (Pools) Data Hooks
import {
  useSupabasePaginated,
  useSupabaseList,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Challenge, ChallengeEntry } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_POOLS: Challenge[] = [
  { id: 'p-1482', match_id: 'f-001', creator_user_id: 'u-001', stake_fet: 500, currency_code: 'FET', status: 'open', lock_at: '2026-04-19T14:00:00Z', settled_at: null, cancelled_at: null, void_reason: null, total_participants: 8, total_pool_fet: 4000, winner_count: null, loser_count: null, payout_per_winner_fet: null, official_home_score: null, official_away_score: null, created_at: '2026-04-17T10:00:00Z', updated_at: '2026-04-17T10:00:00Z' },
  { id: 'p-1481', match_id: 'f-003', creator_user_id: 'u-002', stake_fet: 1000, currency_code: 'FET', status: 'open', lock_at: '2026-04-22T19:00:00Z', settled_at: null, cancelled_at: null, void_reason: null, total_participants: 15, total_pool_fet: 15000, winner_count: null, loser_count: null, payout_per_winner_fet: null, official_home_score: null, official_away_score: null, created_at: '2026-04-17T08:00:00Z', updated_at: '2026-04-17T08:00:00Z' },
  { id: 'p-1480', match_id: 'f-004', creator_user_id: 'u-005', stake_fet: 200, currency_code: 'FET', status: 'locked', lock_at: '2026-04-18T14:30:00Z', settled_at: null, cancelled_at: null, void_reason: null, total_participants: 12, total_pool_fet: 2400, winner_count: null, loser_count: null, payout_per_winner_fet: null, official_home_score: null, official_away_score: null, created_at: '2026-04-16T12:00:00Z', updated_at: '2026-04-18T14:30:00Z' },
  { id: 'p-1478', match_id: 'f-005', creator_user_id: 'u-006', stake_fet: 2000, currency_code: 'FET', status: 'settled', lock_at: '2026-04-17T19:00:00Z', settled_at: '2026-04-17T21:30:00Z', cancelled_at: null, void_reason: null, total_participants: 10, total_pool_fet: 20000, winner_count: 2, loser_count: 8, payout_per_winner_fet: 10000, official_home_score: 2, official_away_score: 0, created_at: '2026-04-15T14:00:00Z', updated_at: '2026-04-17T21:30:00Z' },
  { id: 'p-1475', match_id: 'f-006', creator_user_id: 'u-007', stake_fet: 50000, currency_code: 'FET', status: 'open', lock_at: '2026-04-17T17:00:00Z', settled_at: null, cancelled_at: null, void_reason: null, total_participants: 2, total_pool_fet: 100000, winner_count: null, loser_count: null, payout_per_winner_fet: null, official_home_score: null, official_away_score: null, created_at: '2026-04-15T03:00:00Z', updated_at: '2026-04-15T03:00:00Z' },
];

const DEMO_ENTRIES: ChallengeEntry[] = [
  { id: 'ce-001', challenge_id: 'p-1482', user_id: 'u-001', predicted_home_score: 2, predicted_away_score: 1, stake_fet: 500, status: 'active', payout_fet: null, joined_at: '2026-04-17T10:10:00Z', settled_at: null },
  { id: 'ce-002', challenge_id: 'p-1482', user_id: 'u-002', predicted_home_score: 1, predicted_away_score: 0, stake_fet: 500, status: 'active', payout_fet: null, joined_at: '2026-04-17T10:15:00Z', settled_at: null },
  { id: 'ce-003', challenge_id: 'p-1482', user_id: 'u-003', predicted_home_score: 0, predicted_away_score: 0, stake_fet: 500, status: 'active', payout_fet: null, joined_at: '2026-04-17T10:20:00Z', settled_at: null },
  { id: 'ce-004', challenge_id: 'p-1482', user_id: 'u-005', predicted_home_score: 2, predicted_away_score: 1, stake_fet: 500, status: 'active', payout_fet: null, joined_at: '2026-04-17T10:25:00Z', settled_at: null },
  { id: 'ce-005', challenge_id: 'p-1482', user_id: 'u-006', predicted_home_score: 1, predicted_away_score: 1, stake_fet: 500, status: 'active', payout_fet: null, joined_at: '2026-04-17T10:30:00Z', settled_at: null },
];

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
    demoData: DEMO_POOLS.filter(p => {
      if (filters?.status && filters.status !== 'all' && p.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return p.id.includes(q) || p.match_id.includes(q);
      }
      return true;
    }),
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
      demoData: DEMO_ENTRIES.filter(e => e.challenge_id === challengeId),
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
    demoFn: async () => ({ settled: true, winner_count: 2, payout_per_winner: 5000 }),
  });
}

export function useVoidPool() {
  return useRpcMutation<{ p_pool_id: string; p_reason: string }>({
    fnName: 'void_pool',
    invalidateKeys: [['challenges'], ['challenge-entries'], ['dashboard-kpis']],
    successMessage: 'Pool voided. All stakes refunded.',
    errorMessage: 'Failed to void pool.',
    demoFn: async () => ({ voided: true }),
  });
}
