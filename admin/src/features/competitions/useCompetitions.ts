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

/* ── Demo Data ── */
const DEMO: CompetitionRow[] = [
  { id: 'mpl', name: 'Malta Premier League', short_name: 'MPL', country: 'MT', tier: 1, created_at: '2025-08-01T00:00:00Z', season: '2025-26', matches_count: 132, is_featured: true, status: 'active' },
  { id: 'ucl', name: 'UEFA Champions League', short_name: 'UCL', country: 'EU', tier: 1, created_at: '2025-09-01T00:00:00Z', season: '2025-26', matches_count: 125, is_featured: true, status: 'active' },
  { id: 'uel', name: 'UEFA Europa League', short_name: 'UEL', country: 'EU', tier: 2, created_at: '2025-09-01T00:00:00Z', season: '2025-26', matches_count: 141, is_featured: false, status: 'active' },
  { id: 'epl', name: 'English Premier League', short_name: 'EPL', country: 'EN', tier: 1, created_at: '2025-08-01T00:00:00Z', season: '2025-26', matches_count: 380, is_featured: true, status: 'active' },
  { id: 'laliga', name: 'La Liga', short_name: 'LaLiga', country: 'ES', tier: 1, created_at: '2025-08-01T00:00:00Z', season: '2025-26', matches_count: 380, is_featured: false, status: 'active' },
  { id: 'seriea', name: 'Serie A', short_name: 'Serie A', country: 'IT', tier: 1, created_at: '2025-08-01T00:00:00Z', season: '2025-26', matches_count: 380, is_featured: false, status: 'active' },
  { id: 'wc2026', name: '2026 FIFA World Cup', short_name: 'WC26', country: 'INT', tier: 1, created_at: '2026-01-01T00:00:00Z', season: '2026', matches_count: 0, is_featured: true, status: 'upcoming' },
];

/* ── Hooks ── */
export function useCompetitions(pagination: PaginationOpts, filters?: { search?: string }) {
  return useSupabasePaginated<CompetitionRow>(['competitions', filters], 'competitions', {
    pagination,
    order: { column: 'name', ascending: true },
    demoData: DEMO.filter(c => {
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return c.name.toLowerCase().includes(q) || (c.country ?? '').toLowerCase().includes(q);
      }
      return true;
    }),
  });
}

export function useToggleCompetitionFeatured() {
  return useRpcMutation<{ p_competition_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_competition_featured',
    invalidateKeys: [['competitions']],
    successMessage: 'Competition featured status updated.',
    demoFn: async () => ({ toggled: true }),
  });
}
