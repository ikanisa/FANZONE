// FANZONE Admin — Wallets Data Hooks
import {
  useSupabasePaginated,
  useSupabaseList,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Wallet, WalletTransaction } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

export type WalletRow = Wallet & { display_name: string; status: string };

/* ── Hooks ── */
export function useWallets(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<WalletRow>(['wallets', filters], 'wallet_overview_admin', {
    pagination,
    select: '*',
    order: { column: 'available_balance_fet', ascending: false },
    filters: (query: AdminListQuery<WalletRow>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      if (filters?.search) {
        const term = `%${filters.search}%`;
        q = q.or(`display_name.ilike.${term},email.ilike.${term},phone.ilike.${term}`);
      }
      return q;
    },
  });
}

export function useWalletTransactions(userId: string | null) {
  return useSupabaseList<WalletTransaction>(
    ['wallet-transactions', userId],
    'fet_transactions_admin',
    {
      filters: (query: AdminListQuery<WalletTransaction>) =>
        query.eq('user_id', userId),
      order: { column: 'created_at', ascending: false },
      limit: 50,
      enabled: !!userId,
    },
  );
}

export function useFreezeWallet() {
  return useRpcMutation<{ p_target_user_id: string; p_reason: string }>({
    fnName: 'admin_freeze_wallet',
    invalidateKeys: [['wallets'], ['dashboard-kpis']],
    successMessage: 'Wallet frozen successfully.',
    errorMessage: 'Failed to freeze wallet.',
  });
}

export function useUnfreezeWallet() {
  return useRpcMutation<{ p_target_user_id: string }>({
    fnName: 'admin_unfreeze_wallet',
    invalidateKeys: [['wallets']],
    successMessage: 'Wallet unfrozen successfully.',
    errorMessage: 'Failed to unfreeze wallet.',
  });
}

export function useCreditFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_credit_fet',
    invalidateKeys: [['wallets'], ['wallet-transactions'], ['dashboard-kpis']],
    successMessage: 'FET credited successfully.',
    errorMessage: 'Failed to credit FET.',
  });
}

export function useDebitFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_debit_fet',
    invalidateKeys: [['wallets'], ['wallet-transactions'], ['dashboard-kpis']],
    successMessage: 'FET debited successfully.',
    errorMessage: 'Failed to debit FET.',
  });
}
