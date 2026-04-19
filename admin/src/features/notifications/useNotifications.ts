// FANZONE Admin — Notifications / Campaigns Data Hooks
import {
  useSupabasePaginated,
  useSupabaseMutation,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { Campaign } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_CAMPAIGNS: Campaign[] = [
  { id: 'cmp-1', title: 'Weekend Pool Bonanza', message: '🏆 Double FET rewards on all weekend pools! Create or join a pool before Saturday.', type: 'in_app', segment: { all_users: true }, status: 'sent', scheduled_at: '2026-04-18T08:00:00Z', sent_at: '2026-04-18T08:01:00Z', recipient_count: 3847, country: 'MT', created_by: 'a-001', created_at: '2026-04-17T14:00:00Z', updated_at: '2026-04-18T08:01:00Z' },
  { id: 'cmp-2', title: 'UCL Quarter-Finals Alert', message: '⚽ Liverpool vs Barcelona tonight! Place your free prediction and win up to 200 FET.', type: 'push', segment: { has_predicted_ucl: true }, status: 'sent', scheduled_at: '2026-04-22T16:00:00Z', sent_at: '2026-04-22T16:00:30Z', recipient_count: 1245, country: 'MT', created_by: 'a-001', created_at: '2026-04-20T10:00:00Z', updated_at: '2026-04-22T16:00:30Z' },
  { id: 'cmp-3', title: 'New Partner: Café del Mar', message: '☀️ Café del Mar is now on FANZONE! Redeem your FET for exclusive sunset sessions.', type: 'in_app', segment: { min_balance_fet: 500 }, status: 'scheduled', scheduled_at: '2026-04-25T10:00:00Z', sent_at: null, recipient_count: 0, country: 'MT', created_by: 'a-002', created_at: '2026-04-18T11:00:00Z', updated_at: '2026-04-18T11:00:00Z' },
  { id: 'cmp-4', title: 'Re-engage Dormant Users', message: '👋 We miss you! Come back and claim your 100 FET welcome-back bonus.', type: 'push', segment: { inactive_days: 14 }, status: 'draft', scheduled_at: null, sent_at: null, recipient_count: 0, country: 'MT', created_by: 'a-001', created_at: '2026-04-17T09:00:00Z', updated_at: '2026-04-17T09:00:00Z' },
  { id: 'cmp-5', title: 'MPL Season Finale', message: '🇲🇹 The Malta Premier League season finale is this weekend! Predict all 4 matches for a bonus.', type: 'in_app', segment: { all_users: true }, status: 'draft', scheduled_at: null, sent_at: null, recipient_count: 0, country: 'MT', created_by: 'a-002', created_at: '2026-04-16T15:00:00Z', updated_at: '2026-04-16T15:00:00Z' },
];

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
    demoData: DEMO_CAMPAIGNS.filter(c => {
      if (filters?.status && filters.status !== 'all' && c.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return c.title.toLowerCase().includes(q) || c.message.toLowerCase().includes(q);
      }
      return true;
    }),
  });
}

export function useCreateCampaign() {
  return useSupabaseMutation<{
    title: string;
    message: string;
    type: string;
    segment: Record<string, unknown>;
    scheduledAt: string | null;
  }>({
    mutationFn: async ({ title, message, type, segment, scheduledAt }) => {
      if (isDemoMode) return { created: true, id: `cmp-new-${Date.now()}` };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { data, error } = await supabase
        .from('campaigns')
        .insert({
          title,
          message,
          type,
          segment,
          status: scheduledAt ? 'scheduled' : 'draft',
          scheduled_at: scheduledAt ? new Date(scheduledAt).toISOString() : null,
          country: 'MT',
        })
        .select('id')
        .single();
      if (error) throw new Error(error.message);
      return data;
    },
    invalidateKeys: [['campaigns']],
    successMessage: 'Campaign created.',
  });
}

export function useUpdateCampaignStatus() {
  return useSupabaseMutation<{ campaignId: string; status: string }>({
    mutationFn: async ({ campaignId, status }) => {
      if (isDemoMode) return { updated: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const updates: Record<string, unknown> = { status, updated_at: new Date().toISOString() };
      if (status === 'sent') updates.sent_at = new Date().toISOString();
      const { error } = await supabase.from('campaigns').update(updates).eq('id', campaignId);
      if (error) throw new Error(error.message);
      return { updated: true };
    },
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
    demoFn: async () => ({ sent: true }),
  });
}

export function useDeleteCampaign() {
  return useSupabaseMutation<{ campaignId: string }>({
    mutationFn: async ({ campaignId }) => {
      if (isDemoMode) return { deleted: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.from('campaigns').delete().eq('id', campaignId);
      if (error) throw new Error(error.message);
      return { deleted: true };
    },
    invalidateKeys: [['campaigns']],
    successMessage: 'Campaign deleted.',
  });
}
