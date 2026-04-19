// FANZONE Admin — Rewards Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { Reward } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO: Reward[] = [
  { id: 'r-1', partner_id: 'pt-1', title: '2-for-1 Drinks', description: 'Buy one get one free on all cocktails at Bar Castello. Valid weekdays only.', category: 'drinks', fet_cost: 2000, original_value: '€15', currency: 'EUR', image_url: null, inventory_total: 50, inventory_remaining: 38, valid_from: '2026-01-01', valid_until: '2026-06-30', country: 'MT', market: 'malta', is_featured: true, is_active: true, created_by: 'a-001', created_at: '2026-01-15T10:00:00Z', updated_at: '2026-04-10T14:00:00Z' },
  { id: 'r-2', partner_id: 'pt-2', title: 'Free Appetizer', description: 'Complimentary appetizer with any main course at Café del Mar.', category: 'food', fet_cost: 1500, original_value: '€12', currency: 'EUR', image_url: null, inventory_total: 100, inventory_remaining: 82, valid_from: '2026-02-01', valid_until: '2026-05-31', country: 'MT', market: 'malta', is_featured: false, is_active: true, created_by: 'a-001', created_at: '2026-02-01T10:00:00Z', updated_at: '2026-04-12T16:00:00Z' },
  { id: 'r-3', partner_id: 'pt-3', title: 'Spa Day 20% Off', description: '20% discount on any full-day spa package at Fortina Resort.', category: 'leisure', fet_cost: 5000, original_value: '€25 off', currency: 'EUR', image_url: null, inventory_total: 20, inventory_remaining: 15, valid_from: '2026-03-01', valid_until: '2026-07-31', country: 'MT', market: 'malta', is_featured: true, is_active: true, created_by: 'a-002', created_at: '2026-03-01T10:00:00Z', updated_at: '2026-04-05T11:00:00Z' },
  { id: 'r-4', partner_id: null, title: 'Season Ticket Raffle', description: 'Enter the draw for a Malta Premier League season ticket for next season.', category: 'exclusive', fet_cost: 10000, original_value: '€200', currency: 'EUR', image_url: null, inventory_total: 1, inventory_remaining: 1, valid_from: '2026-04-01', valid_until: '2026-04-30', country: 'MT', market: 'malta', is_featured: true, is_active: true, created_by: 'a-001', created_at: '2026-04-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'r-5', partner_id: 'pt-5', title: 'Travel Insurance 10%', description: '10% off your next travel insurance policy with GasanMamo.', category: 'insurance', fet_cost: 3000, original_value: '10% off', currency: 'EUR', image_url: null, inventory_total: null, inventory_remaining: null, valid_from: '2026-01-01', valid_until: '2026-12-31', country: 'MT', market: 'malta', is_featured: false, is_active: false, created_by: 'a-001', created_at: '2026-01-01T10:00:00Z', updated_at: '2026-03-15T10:00:00Z' },
];

/* ── Hooks ── */
export function useRewards(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<Reward>(['rewards', filters], 'rewards', {
    pagination,
    order: { column: 'created_at', ascending: false },
    demoData: DEMO.filter(r => {
      if (filters?.status === 'active' && !r.is_active) return false;
      if (filters?.status === 'archived' && r.is_active) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return r.title.toLowerCase().includes(q) || (r.category ?? '').toLowerCase().includes(q);
      }
      return true;
    }),
  });
}

export function useToggleRewardActive() {
  return useRpcMutation<{ p_reward_id: string; p_is_active: boolean }>({
    fnName: 'admin_set_reward_active',
    invalidateKeys: [['rewards']],
    successMessage: 'Reward status updated.',
    demoFn: async () => ({ toggled: true }),
  });
}

export function useToggleRewardFeatured() {
  return useRpcMutation<{ p_reward_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_reward_featured',
    invalidateKeys: [['rewards']],
    successMessage: 'Reward featured status updated.',
    demoFn: async () => ({ toggled: true }),
  });
}
