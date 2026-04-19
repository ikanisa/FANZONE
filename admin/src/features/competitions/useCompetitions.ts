// FANZONE Admin — Competitions Data Hooks
import { useSupabasePaginated, useRpcMutation } from '../../hooks/useSupabaseQuery';
import type { Competition } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Extended type for admin display ── */
export interface CompetitionRow extends Competition {
  season?: string;
  matches_count?: number;
  is_featured?: boolean;
  status?: string;
}

/* ── Hooks ── */
export function useCompetitions(pagination: PaginationOpts, filters?: { search?: string }) {
  return useSupabasePaginated<CompetitionRow>(['competitions', filters], 'competitions', {
    pagination,
    order: { column: 'name', ascending: true },
  });
}

export function useToggleCompetitionFeatured() {
  return useRpcMutation<{ p_competition_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_competition_featured',
    invalidateKeys: [['competitions']],
    successMessage: 'Competition featured status updated.',
  });
}
