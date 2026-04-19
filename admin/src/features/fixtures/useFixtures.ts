// FANZONE Admin — Fixtures Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Match } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_FIXTURES: Match[] = [
  { id: 'f-001', competition_id: 'c-mpl', season: '2025-26', round: 'R28', match_group: null, date: '2026-04-19T14:00:00Z', kickoff_time: '16:00', home_team_id: 't-1', away_team_id: 't-2', home_team: 'Valletta FC', away_team: 'Floriana FC', ft_home: null, ft_away: null, ht_home: null, ht_away: null, et_home: null, et_away: null, status: 'upcoming', venue: 'National Stadium', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 1.8, draw_multiplier: 3.2, away_multiplier: 4.5, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-10T10:00:00Z' },
  { id: 'f-002', competition_id: 'c-mpl', season: '2025-26', round: 'R28', match_group: null, date: '2026-04-19T16:00:00Z', kickoff_time: '18:00', home_team_id: 't-3', away_team_id: 't-4', home_team: 'Hibernians', away_team: 'Sliema Wanderers', ft_home: null, ft_away: null, ht_home: null, ht_away: null, et_home: null, et_away: null, status: 'upcoming', venue: 'Hibernians Ground', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 1.5, draw_multiplier: 3.6, away_multiplier: 5.0, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-10T10:00:00Z' },
  { id: 'f-003', competition_id: 'c-ucl', season: '2025-26', round: 'QF', match_group: null, date: '2026-04-22T19:00:00Z', kickoff_time: '21:00', home_team_id: 't-10', away_team_id: 't-11', home_team: 'Liverpool', away_team: 'Barcelona', ft_home: null, ft_away: null, ht_home: null, ht_away: null, et_home: null, et_away: null, status: 'upcoming', venue: 'Anfield', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 2.1, draw_multiplier: 3.3, away_multiplier: 3.4, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-10T10:00:00Z' },
  { id: 'f-004', competition_id: 'c-epl', season: '2025-26', round: 'R35', match_group: null, date: '2026-04-18T14:30:00Z', kickoff_time: '16:30', home_team_id: 't-20', away_team_id: 't-21', home_team: 'Arsenal', away_team: 'Man City', ft_home: 1, ft_away: 1, ht_home: 0, ht_away: 1, et_home: null, et_away: null, status: 'live', venue: 'Emirates Stadium', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 2.0, draw_multiplier: 3.2, away_multiplier: 3.5, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-18T15:30:00Z' },
  { id: 'f-005', competition_id: 'c-laliga', season: '2025-26', round: 'R33', match_group: null, date: '2026-04-17T19:00:00Z', kickoff_time: '21:00', home_team_id: 't-30', away_team_id: 't-31', home_team: 'Real Madrid', away_team: 'Atletico Madrid', ft_home: 2, ft_away: 0, ht_home: 1, ht_away: 0, et_home: null, et_away: null, status: 'finished', venue: 'Santiago Bernabéu', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 1.6, draw_multiplier: 3.5, away_multiplier: 5.5, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-17T21:00:00Z' },
  { id: 'f-006', competition_id: 'c-seriea', season: '2025-26', round: 'R34', match_group: null, date: '2026-04-17T17:00:00Z', kickoff_time: '19:00', home_team_id: 't-40', away_team_id: 't-41', home_team: 'AC Milan', away_team: 'Inter Milan', ft_home: 3, ft_away: 2, ht_home: 2, ht_away: 1, et_home: null, et_away: null, status: 'finished', venue: 'San Siro', data_source: 'openfootball', source_url: null, home_logo_url: null, away_logo_url: null, home_multiplier: 2.8, draw_multiplier: 3.1, away_multiplier: 2.5, created_at: '2026-04-10T10:00:00Z', updated_at: '2026-04-17T19:00:00Z' },
];

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
    demoData: DEMO_FIXTURES.filter(f => {
      if (filters?.status && filters.status !== 'all' && f.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return f.home_team.toLowerCase().includes(q) || f.away_team.toLowerCase().includes(q);
      }
      return true;
    }),
  });
}

export function useUpdateFixtureResult() {
  return useRpcMutation<{ p_match_id: string; p_ft_home: number; p_ft_away: number }>({
    fnName: 'admin_update_match_result',
    invalidateKeys: [['fixtures']],
    successMessage: 'Match result recorded.',
    demoFn: async () => ({ updated: true }),
  });
}

export function useAutoSettlePools() {
  return useRpcMutation<{ p_match_id: string; p_home_score: number; p_away_score: number }>({
    fnName: 'admin_auto_settle_match',
    invalidateKeys: [['fixtures'], ['challenges'], ['wallets'], ['dashboard-kpis']],
    successMessage: 'All pools for this match have been settled.',
    errorMessage: 'Failed to auto-settle pools.',
    demoFn: async () => ({ settled_count: 3 }),
  });
}
