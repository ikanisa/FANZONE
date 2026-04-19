// FANZONE Admin — Notifications / Campaigns Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Campaign } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useCampaigns(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<Campaign>(['campaigns', filters], 'campaigns', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<Campaign>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') q = q.eq('status', filters.status);
      if (filters?.search) {
        const term = `%${filters.search}%`;
        q = q.or(`title.ilike.${term},message.ilike.${term}`);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
  });
}

export function useCreateCampaign() {
  return useRpcMutation<{
    p_title: string;
    p_message: string;
    p_type: string;
    p_segment: Record<string, unknown>;
    p_scheduled_at: string | null;
  }>({
    fnName: 'admin_create_campaign',
    invalidateKeys: [['campaigns']],
    successMessage: 'Campaign created.',
  });
}

export function useUpdateCampaignStatus() {
  return useRpcMutation<{ p_campaign_id: string; p_status: string }>({
    fnName: 'admin_update_campaign_status',
    invalidateKeys: [['campaigns']],
    successMessage: 'Campaign status updated.',
  });
}

export function useSendCampaign() {
  return useRpcMutation<{ p_campaign_id: string; p_force?: boolean }>({
    fnName: 'admin_send_campaign',
    invalidateKeys: [['campaigns'], ['dashboard-alerts']],
    successMessage: 'Campaign dispatched.',
    errorMessage: 'Failed to dispatch campaign.',
  });
}

export function useDeleteCampaign() {
  return useRpcMutation<{ p_campaign_id: string }>({
    fnName: 'admin_delete_campaign',
    invalidateKeys: [['campaigns']],
    successMessage: 'Campaign deleted.',
  });
}
