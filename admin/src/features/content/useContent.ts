// FANZONE Admin — Content (Banners) Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { ContentBanner } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO: ContentBanner[] = [
  { id: 'b-1', title: 'UCL Semi-Finals — Predict Now!', subtitle: 'Place your free prediction and win FET', image_url: null, action_url: '/predict', placement: 'home_hero', priority: 1, country: 'MT', is_active: true, valid_from: '2026-04-15', valid_until: '2026-04-25', created_by: 'a-001', created_at: '2026-04-14T10:00:00Z', updated_at: '2026-04-14T10:00:00Z' },
  { id: 'b-2', title: 'Malta Premier League — Top of Table Clash', subtitle: 'Valletta vs Floriana this Saturday', image_url: null, action_url: '/fixtures', placement: 'home_secondary', priority: 2, country: 'MT', is_active: true, valid_from: '2026-04-17', valid_until: '2026-04-20', created_by: 'a-001', created_at: '2026-04-16T08:00:00Z', updated_at: '2026-04-16T08:00:00Z' },
  { id: 'b-3', title: 'Earn FET — Welcome Bonus', subtitle: 'Sign up and claim 500 FET', image_url: null, action_url: '/earn', placement: 'home_hero', priority: 3, country: 'MT', is_active: false, valid_from: '2026-01-01', valid_until: '2026-03-31', created_by: 'a-002', created_at: '2025-12-20T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'b-4', title: 'New Partner: Café del Mar', subtitle: 'Redeem FET for exclusive deals', image_url: null, action_url: '/rewards', placement: 'rewards_hero', priority: 1, country: 'MT', is_active: true, valid_from: '2026-04-12', valid_until: '2026-05-31', created_by: 'a-002', created_at: '2026-04-12T12:00:00Z', updated_at: '2026-04-12T12:00:00Z' },
];

/* ── Hooks ── */
export function useBanners(pagination: PaginationOpts, filters?: { search?: string; placement?: string }) {
  return useSupabasePaginated<ContentBanner>(['banners', filters], 'content_banners', {
    pagination,
    order: { column: 'priority', ascending: true },
    demoData: DEMO.filter(b => {
      if (filters?.placement && filters.placement !== 'all' && b.placement !== filters.placement) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return b.title.toLowerCase().includes(q) || (b.subtitle ?? '').toLowerCase().includes(q);
      }
      return true;
    }),
  });
}

export function useToggleBannerActive() {
  return useRpcMutation<{ p_banner_id: string; p_is_active: boolean }>({
    fnName: 'admin_set_banner_active',
    invalidateKeys: [['banners']],
    successMessage: 'Banner status updated.',
    demoFn: async () => ({ toggled: true }),
  });
}

export function useDeleteBanner() {
  return useRpcMutation<{ p_banner_id: string }>({
    fnName: 'admin_delete_banner',
    invalidateKeys: [['banners']],
    successMessage: 'Banner deleted.',
    demoFn: async () => ({ deleted: true }),
  });
}
