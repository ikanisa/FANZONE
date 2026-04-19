// FANZONE Admin — Featured Events Data Hooks
import { useSupabasePaginated, useSupabaseMutation } from '../../hooks/useSupabaseQuery';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Types ── */
export interface FeaturedEventRow {
  id: string;
  name: string;
  short_name: string;
  event_tag: string;
  region: 'global' | 'africa' | 'europe' | 'americas';
  competition_id?: string;
  start_date: string;
  end_date: string;
  is_active: boolean;
  banner_color?: string;
  description?: string;
  logo_url?: string;
  created_at: string;
  updated_at: string;
}

/* ── Demo Data ── */
const DEMO: FeaturedEventRow[] = [
  {
    id: 'wc2026', name: 'FIFA World Cup 2026', short_name: 'WC 2026',
    event_tag: 'worldcup2026', region: 'global',
    start_date: '2026-06-11T00:00:00Z', end_date: '2026-07-19T23:59:59Z',
    is_active: true, banner_color: '#1A237E',
    description: 'The 23rd FIFA World Cup across USA, Canada, and Mexico.',
    created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
  },
  {
    id: 'ucl2026', name: 'UEFA Champions League Final 2025/26', short_name: 'UCL Final',
    event_tag: 'ucl-final-2026', region: 'global',
    start_date: '2026-05-20T00:00:00Z', end_date: '2026-05-31T23:59:59Z',
    is_active: true, banner_color: '#1565C0',
    description: 'The pinnacle of European club football.',
    created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
  },
  {
    id: 'afcon2025', name: 'Africa Cup of Nations 2025', short_name: 'AFCON 2025',
    event_tag: 'afcon2025', region: 'africa',
    start_date: '2025-12-21T00:00:00Z', end_date: '2026-01-18T23:59:59Z',
    is_active: true, banner_color: '#388E3C',
    description: 'The continent\'s premier national team tournament.',
    created_at: '2025-08-01T00:00:00Z', updated_at: '2025-08-01T00:00:00Z',
  },
  {
    id: 'cafcl2026', name: 'CAF Champions League 2025/26', short_name: 'CAFCL',
    event_tag: 'cafcl-2026', region: 'africa',
    start_date: '2025-08-01T00:00:00Z', end_date: '2026-06-30T23:59:59Z',
    is_active: true, banner_color: '#2E7D32',
    description: 'Africa\'s premier club competition.',
    created_at: '2025-07-01T00:00:00Z', updated_at: '2025-07-01T00:00:00Z',
  },
];

/* ── Hooks ── */
export function useFeaturedEvents(pagination: PaginationOpts, filters?: { region?: string }) {
  return useSupabasePaginated<FeaturedEventRow>(['featured_events', filters], 'featured_events', {
    pagination,
    order: { column: 'start_date', ascending: false },
    demoData: DEMO.filter(e => {
      if (filters?.region && filters.region !== 'all') {
        return e.region === filters.region;
      }
      return true;
    }),
  });
}

export function useToggleEventActive() {
  return useSupabaseMutation<{ eventId: string; active: boolean }>({
    mutationFn: async ({ eventId, active }) => {
      if (isDemoMode) return { toggled: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase
        .from('featured_events')
        .update({ is_active: active, updated_at: new Date().toISOString() })
        .eq('id', eventId);
      if (error) throw new Error(error.message);
      return { toggled: true };
    },
    invalidateKeys: [['featured_events']],
    successMessage: 'Event active status updated.',
  });
}
