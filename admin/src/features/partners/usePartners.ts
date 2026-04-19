// FANZONE Admin — Partners Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Partner } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function usePartners(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<Partner>(['partners', filters], 'partners', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<Partner>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
  });
}

export function useApprovePartner() {
  return useRpcMutation<{ p_partner_id: string }>({
    fnName: 'admin_approve_partner',
    invalidateKeys: [['partners'], ['dashboard-kpis']],
    successMessage: 'Partner approved successfully.',
  });
}

export function useRejectPartner() {
  return useRpcMutation<{ p_partner_id: string; p_reason: string }>({
    fnName: 'admin_reject_partner',
    invalidateKeys: [['partners']],
    successMessage: 'Partner rejected.',
  });
}

export function useToggleFeatured() {
  return useRpcMutation<{ p_partner_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_partner_featured',
    invalidateKeys: [['partners']],
    successMessage: 'Partner featured status updated.',
  });
}
