// FANZONE Admin — Rewards Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { Reward } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useRewards(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<Reward>(['rewards', filters], 'rewards', {
    pagination,
    order: { column: 'created_at', ascending: false },
  });
}

export function useToggleRewardActive() {
  return useRpcMutation<{ p_reward_id: string; p_is_active: boolean }>({
    fnName: 'admin_set_reward_active',
    invalidateKeys: [['rewards']],
    successMessage: 'Reward status updated.',
  });
}

export function useToggleRewardFeatured() {
  return useRpcMutation<{ p_reward_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_reward_featured',
    invalidateKeys: [['rewards']],
    successMessage: 'Reward featured status updated.',
  });
}
