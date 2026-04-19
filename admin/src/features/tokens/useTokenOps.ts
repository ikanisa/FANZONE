// FANZONE Admin — Token Operations Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import { useQuery } from '@tanstack/react-query';
import { adminEnvError, isDemoMode, isSupabaseConfigured, supabase } from '../../lib/supabase';
import type { WalletTransaction } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Types ── */
export interface FetSupply {
  totalIssued: number;
  totalCirculating: number;
  totalRedeemed: number;
  totalStaked: number;
  totalTransferred7d: number;
}

interface AmountRow {
  amount_fet: number | null;
}

interface FetSupplyOverviewRow {
  total_available: number | null;
  total_locked: number | null;
  total_supply: number | null;
}

/* ── Demo Data ── */
const DEMO_TX: WalletTransaction[] = [
  { id: 't-001', user_id: 'u-001', tx_type: 'earn', direction: 'credit', amount_fet: 5000, balance_before_fet: 7500, balance_after_fet: 12500, reference_type: 'welcome_bonus', reference_id: null, metadata: null, title: 'Welcome bonus', created_at: '2026-04-17T14:00:00Z' },
  { id: 't-002', user_id: 'u-002', tx_type: 'transfer', direction: 'debit', amount_fet: 2000, balance_before_fet: 37000, balance_after_fet: 35000, reference_type: 'peer_transfer', reference_id: 'u-005', metadata: null, title: 'Transfer to Daniel G.', created_at: '2026-04-17T15:30:00Z' },
  { id: 't-003', user_id: 'u-005', tx_type: 'transfer', direction: 'credit', amount_fet: 2000, balance_before_fet: 54700, balance_after_fet: 56700, reference_type: 'peer_transfer', reference_id: 'u-002', metadata: null, title: 'Transfer received', created_at: '2026-04-17T15:30:00Z' },
  { id: 't-004', user_id: 'u-007', tx_type: 'transfer', direction: 'debit', amount_fet: 50000, balance_before_fet: 200000, balance_after_fet: 150000, reference_type: 'peer_transfer', reference_id: 'unknown', metadata: { flagged: true }, title: 'Transfer to unknown', created_at: '2026-04-15T03:15:00Z' },
  { id: 't-005', user_id: 'u-003', tx_type: 'contribution', direction: 'debit', amount_fet: 1000, balance_before_fet: 9200, balance_after_fet: 8200, reference_type: 'team_contribution', reference_id: null, metadata: null, title: 'Team contribution', created_at: '2026-04-17T10:00:00Z' },
  { id: 't-006', user_id: 'u-006', tx_type: 'challenge_stake', direction: 'debit', amount_fet: 2000, balance_before_fet: 21300, balance_after_fet: 19300, reference_type: 'pool', reference_id: 'p-1478', metadata: null, title: 'Pool #1478 entry', created_at: '2026-04-16T20:00:00Z' },
  { id: 't-007', user_id: 'u-006', tx_type: 'challenge_payout', direction: 'credit', amount_fet: 4000, balance_before_fet: 19300, balance_after_fet: 23300, reference_type: 'pool', reference_id: 'p-1478', metadata: null, title: 'Pool #1478 winnings', created_at: '2026-04-17T21:30:00Z' },
];

const DEMO_SUPPLY: FetSupply = {
  totalIssued: 12450000,
  totalCirculating: 8200000,
  totalRedeemed: 450000,
  totalStaked: 380000,
  totalTransferred7d: 348000,
};

/* ── Hooks ── */
export function useTokenTransactions(pagination: PaginationOpts, filters?: { search?: string; type?: string }) {
  return useSupabasePaginated<WalletTransaction>(['token-transactions', filters], 'fet_transactions_admin', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<WalletTransaction>) => {
      let q = query;
      if (filters?.type && filters.type !== 'all') {
        q = q.eq('tx_type', filters.type);
      }
      if (filters?.search) {
        const term = `%${filters.search}%`;
        q = q.or(`display_name.ilike.${term},title.ilike.${term},user_id.ilike.${term}`);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
    demoData: DEMO_TX.filter(t => {
      if (filters?.type && filters.type !== 'all' && t.tx_type !== filters.type) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return t.user_id.includes(q) || (t.title ?? '').toLowerCase().includes(q) || t.id.includes(q);
      }
      return true;
    }),
  });
}

export function useFetSupply() {
  return useQuery<FetSupply>({
    queryKey: ['fet-supply'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_SUPPLY;
      if (!isSupabaseConfigured) throw new Error(adminEnvError);

      const [overviewRes, redeemedRes, transferredRes] = await Promise.all([
        supabase.from('fet_supply_overview_admin').select('*').single(),
        supabase
          .from('fet_transactions_admin')
          .select('amount_fet')
          .or('tx_type.eq.redemption,reference_type.eq.marketplace_redemption'),
        supabase
          .from('fet_transactions_admin')
          .select('amount_fet')
          .in('tx_type', ['transfer', 'transfer_fet'])
          .eq('direction', 'debit')
          .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()),
      ]);

      if (overviewRes.error) throw new Error(overviewRes.error.message);

      const overview = overviewRes.data as FetSupplyOverviewRow;
      const redeemedRows = (redeemedRes.data ?? []) as AmountRow[];
      const transferredRows = (transferredRes.data ?? []) as AmountRow[];
      const totalRedeemed = redeemedRows.reduce(
        (sum, row) => sum + (row.amount_fet ?? 0),
        0,
      );
      const totalTransferred7d = transferredRows.reduce(
        (sum, row) => sum + (row.amount_fet ?? 0),
        0,
      );

      return {
        totalIssued: overview.total_supply ?? 0,
        totalCirculating: overview.total_available ?? 0,
        totalRedeemed,
        totalStaked: overview.total_locked ?? 0,
        totalTransferred7d,
      };
    },
    refetchInterval: 120_000,
  });
}

export function useMintFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_credit_fet',
    invalidateKeys: [['token-transactions'], ['fet-supply'], ['dashboard-kpis']],
    successMessage: 'FET minted successfully.',
    demoFn: async () => ({ minted: true }),
  });
}

export function useBurnFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_debit_fet',
    invalidateKeys: [['token-transactions'], ['fet-supply'], ['dashboard-kpis']],
    successMessage: 'FET burned successfully.',
    demoFn: async () => ({ burned: true }),
  });
}
