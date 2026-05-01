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
  is_active?: boolean;
  type?: string | null;
  priority?: number | null;
  region?: string | null;
}

/* ── Hooks ── */
export function useCompetitions(pagination: PaginationOpts, filters?: { search?: string }) {
  return useSupabasePaginated<CompetitionRow>(['competitions', filters], 'competitions', {
    pagination,
    order: { column: 'name', ascending: true },
    filters: (query) => {
      if (!filters?.search?.trim()) return query;
      const term = `%${filters.search.trim().replaceAll(',', '\\,')}%`;
      return query.or(`name.ilike.${term},short_name.ilike.${term},country.ilike.${term},region.ilike.${term},type.ilike.${term}`);
    },
  });
}

export function useToggleCompetitionFeatured() {
  return useRpcMutation<{ p_competition_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_competition_featured',
    invalidateKeys: [['competitions']],
    successMessage: 'Competition featured status updated.',
  });
}

export function useUpdateCompetitionControl() {
  return useRpcMutation<{
    p_competition_id: string;
    p_is_active: boolean | null;
    p_priority: number | null;
    p_type: string | null;
    p_region: string | null;
  }>({
    fnName: 'admin_update_competition_control',
    invalidateKeys: [['competitions'], ['dashboard-kpis']],
    successMessage: 'Competition rollout updated.',
  });
}
