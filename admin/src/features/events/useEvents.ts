// FANZONE Admin — Featured Events Data Hooks
import { useSupabasePaginated, useRpcMutation } from '../../hooks/useSupabaseQuery';
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

/* ── Hooks ── */
export function useFeaturedEvents(pagination: PaginationOpts, filters?: { region?: string }) {
  return useSupabasePaginated<FeaturedEventRow>(['featured_events', filters], 'featured_events', {
    pagination,
    order: { column: 'start_date', ascending: false },
  });
}

export function useToggleEventActive() {
  return useRpcMutation<{ p_event_id: string; p_is_active: boolean }>({
    fnName: 'admin_set_featured_event_active',
    invalidateKeys: [['featured_events']],
    successMessage: 'Event active status updated.',
  });
}
