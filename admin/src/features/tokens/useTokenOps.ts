// FANZONE Admin — Token Operations Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import { useQuery } from '@tanstack/react-query';
import { adminEnvError, isSupabaseConfigured, supabase } from '../../lib/supabase';
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
  });
}

export function useFetSupply() {
  return useQuery<FetSupply>({
    queryKey: ['fet-supply'],
    queryFn: async () => {
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
  });
}

export function useBurnFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_debit_fet',
    invalidateKeys: [['token-transactions'], ['fet-supply'], ['dashboard-kpis']],
    successMessage: 'FET burned successfully.',
  });
}
