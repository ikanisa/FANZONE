// FANZONE Admin — Redemptions Data Hooks
import { useMemo } from 'react';
import { useSupabasePaginated, useSupabaseMutation } from '../../hooks/useSupabaseQuery';
import { adminEnvError, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { Redemption } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Extended for display ── */
export interface RedemptionRow extends Redemption {
  user_name?: string;
  reward_title?: string;
  partner_name?: string;
}

interface RedemptionQueryRow extends RedemptionRow {
  rewards?: { title?: string | null } | null;
  partners?: { name?: string | null } | null;
}

/* ── Hooks ── */
export function useRedemptions(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  const query = useSupabasePaginated<RedemptionQueryRow>(['redemptions', filters], 'redemptions', {
    pagination,
    select: '*, rewards(title), partners(name)',
    order: { column: 'created_at', ascending: false },
  });

  const data = useMemo(() => {
    if (!query.data) {
      return query.data;
    }

    return {
      ...query.data,
      data: query.data.data.map((row) => ({
        ...row,
        reward_title: row.reward_title ?? row.rewards?.title ?? undefined,
        partner_name: row.partner_name ?? row.partners?.name ?? undefined,
      })),
    };
  }, [query.data]);

  return {
    ...query,
    data,
  };
}

export function useApproveRedemption() {
  return useSupabaseMutation<{ redemptionId: string; code?: string }>({
    mutationFn: async ({ redemptionId, code }) => {
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.rpc('admin_approve_redemption', {
        p_redemption_id: redemptionId,
        p_redemption_code: code || null,
      });
      if (error) throw new Error(error.message);
      return { approved: true };
    },
    invalidateKeys: [['redemptions'], ['dashboard-kpis']],
    successMessage: 'Redemption approved.',
  });
}

export function useRejectRedemption() {
  return useSupabaseMutation<{ redemptionId: string; reason: string }>({
    mutationFn: async ({ redemptionId, reason }) => {
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.rpc('admin_reject_redemption', {
        p_redemption_id: redemptionId,
        p_reason: reason,
      });
      if (error) throw new Error(error.message);
      return { rejected: true };
    },
    invalidateKeys: [['redemptions']],
    successMessage: 'Redemption rejected.',
  });
}

export function useFulfillRedemption() {
  return useSupabaseMutation<{ redemptionId: string }>({
    mutationFn: async ({ redemptionId }) => {
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.rpc('admin_fulfill_redemption', {
        p_redemption_id: redemptionId,
      });
      if (error) throw new Error(error.message);
      return { fulfilled: true };
    },
    invalidateKeys: [['redemptions']],
    successMessage: 'Redemption marked as fulfilled.',
  });
}
