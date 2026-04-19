// FANZONE Admin — Redemptions Data Hooks
import { useSupabasePaginated, useSupabaseMutation } from '../../hooks/useSupabaseQuery';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { Redemption } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Extended for display ── */
export interface RedemptionRow extends Redemption {
  user_name?: string;
  reward_title?: string;
  partner_name?: string;
}

/* ── Demo Data ── */
const DEMO: RedemptionRow[] = [
  { id: 'rd-045', user_id: 'u-002', reward_id: 'r-1', partner_id: 'pt-1', fet_amount: 2000, status: 'fulfilled', redemption_code: 'FZ-2F1-A3R8', admin_notes: 'Verified at counter', reviewed_by: 'a-002', fraud_flag: false, created_at: '2026-04-17T12:00:00Z', updated_at: '2026-04-17T13:00:00Z', user_name: 'Sarah Borg', reward_title: '2-for-1 Drinks', partner_name: 'Bar Castello' },
  { id: 'rd-046', user_id: 'u-005', reward_id: 'r-2', partner_id: 'pt-2', fet_amount: 1500, status: 'pending', redemption_code: null, admin_notes: null, reviewed_by: null, fraud_flag: false, created_at: '2026-04-17T18:00:00Z', updated_at: '2026-04-17T18:00:00Z', user_name: 'Daniel Grech', reward_title: 'Free Appetizer', partner_name: 'Café del Mar' },
  { id: 'rd-047', user_id: 'u-006', reward_id: 'r-3', partner_id: 'pt-3', fet_amount: 5000, status: 'pending', redemption_code: null, admin_notes: null, reviewed_by: null, fraud_flag: false, created_at: '2026-04-17T20:00:00Z', updated_at: '2026-04-17T20:00:00Z', user_name: 'Isla Camilleri', reward_title: 'Spa Day 20% Off', partner_name: 'Fortina Spa' },
  { id: 'rd-048', user_id: 'u-001', reward_id: 'r-4', partner_id: null, fet_amount: 10000, status: 'approved', redemption_code: 'FZ-RAFL-X9K2', admin_notes: 'Raffle entry confirmed', reviewed_by: 'a-001', fraud_flag: false, created_at: '2026-04-16T14:00:00Z', updated_at: '2026-04-16T15:00:00Z', user_name: 'Marco Spiteri', reward_title: 'Season Ticket Raffle', partner_name: 'FANZONE' },
  { id: 'rd-044', user_id: 'u-007', reward_id: 'r-3', partner_id: 'pt-3', fet_amount: 5000, status: 'disputed', redemption_code: null, admin_notes: 'Account flagged for suspicious activity', reviewed_by: 'a-001', fraud_flag: true, created_at: '2026-04-15T04:00:00Z', updated_at: '2026-04-16T12:00:00Z', user_name: 'Flagged User', reward_title: 'Spa Day 20% Off', partner_name: 'Fortina Spa' },
  { id: 'rd-043', user_id: 'u-003', reward_id: 'r-1', partner_id: 'pt-1', fet_amount: 2000, status: 'rejected', redemption_code: null, admin_notes: 'Duplicate redemption attempt', reviewed_by: 'a-003', fraud_flag: false, created_at: '2026-04-14T10:00:00Z', updated_at: '2026-04-14T11:00:00Z', user_name: 'Josanne Vella', reward_title: '2-for-1 Drinks', partner_name: 'Bar Castello' },
];

/* ── Hooks ── */
export function useRedemptions(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<RedemptionRow>(['redemptions', filters], 'redemptions', {
    pagination,
    select: '*, rewards(title), partners(name)',
    order: { column: 'created_at', ascending: false },
    demoData: DEMO.filter(r => {
      if (filters?.status && filters.status !== 'all' && r.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return (r.user_name ?? '').toLowerCase().includes(q) || (r.reward_title ?? '').toLowerCase().includes(q) || r.id.includes(q);
      }
      return true;
    }),
  });
}

export function useApproveRedemption() {
  return useSupabaseMutation<{ redemptionId: string; code?: string }>({
    mutationFn: async ({ redemptionId, code }) => {
      if (isDemoMode) return { approved: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.from('redemptions').update({
        status: 'approved',
        redemption_code: code || `FZ-${Math.random().toString(36).slice(2, 6).toUpperCase()}`,
        updated_at: new Date().toISOString(),
      }).eq('id', redemptionId);
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
      if (isDemoMode) return { rejected: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.from('redemptions').update({
        status: 'rejected',
        admin_notes: reason,
        updated_at: new Date().toISOString(),
      }).eq('id', redemptionId);
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
      if (isDemoMode) return { fulfilled: true };
      if (!isSupabaseConfigured) throw new Error(adminEnvError);
      const { error } = await supabase.from('redemptions').update({
        status: 'fulfilled',
        updated_at: new Date().toISOString(),
      }).eq('id', redemptionId);
      if (error) throw new Error(error.message);
      return { fulfilled: true };
    },
    invalidateKeys: [['redemptions']],
    successMessage: 'Redemption marked as fulfilled.',
  });
}
