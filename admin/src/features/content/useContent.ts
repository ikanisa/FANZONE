// FANZONE Admin — Content (Banners) Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { ContentBanner } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useBanners(pagination: PaginationOpts, filters?: { search?: string; placement?: string }) {
  return useSupabasePaginated<ContentBanner>(['banners', filters], 'content_banners', {
    pagination,
    order: { column: 'priority', ascending: true },
  });
}

export function useToggleBannerActive() {
  return useRpcMutation<{ p_banner_id: string; p_is_active: boolean }>({
    fnName: 'admin_set_banner_active',
    invalidateKeys: [['banners']],
    successMessage: 'Banner status updated.',
  });
}

export function useDeleteBanner() {
  return useRpcMutation<{ p_banner_id: string }>({
    fnName: 'admin_delete_banner',
    invalidateKeys: [['banners']],
    successMessage: 'Banner deleted.',
  });
}
