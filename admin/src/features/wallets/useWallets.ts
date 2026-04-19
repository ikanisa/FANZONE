// FANZONE Admin — Wallets Data Hooks
import {
  useSupabasePaginated,
  useSupabaseList,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Wallet, WalletTransaction } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_WALLETS: (Wallet & { display_name: string; status: string })[] = [
  { user_id: 'u-005', available_balance_fet: 56700, locked_balance_fet: 2000, status: 'active', display_name: 'Daniel Grech', updated_at: '2026-04-17T22:00:00Z', created_at: '2025-12-01T10:00:00Z' },
  { user_id: 'u-002', available_balance_fet: 35000, locked_balance_fet: 1000, status: 'active', display_name: 'Sarah Borg', updated_at: '2026-04-17T18:00:00Z', created_at: '2026-02-03T09:00:00Z' },
  { user_id: 'u-006', available_balance_fet: 19300, locked_balance_fet: 0, status: 'active', display_name: 'Isla Camilleri', updated_at: '2026-04-17T16:00:00Z', created_at: '2026-02-14T14:00:00Z' },
  { user_id: 'u-007', available_balance_fet: 150000, locked_balance_fet: 50000, status: 'frozen', display_name: 'TestUser_flagged', updated_at: '2026-04-15T03:30:00Z', created_at: '2026-04-15T03:00:00Z' },
  { user_id: 'u-001', available_balance_fet: 12500, locked_balance_fet: 500, status: 'active', display_name: 'Marco Spiteri', updated_at: '2026-04-17T14:30:00Z', created_at: '2026-01-15T10:00:00Z' },
  { user_id: 'u-003', available_balance_fet: 8200, locked_balance_fet: 0, status: 'active', display_name: 'Jake Calleja', updated_at: '2026-04-16T20:00:00Z', created_at: '2026-03-10T12:00:00Z' },
  { user_id: 'u-004', available_balance_fet: 0, locked_balance_fet: 0, status: 'frozen', display_name: 'Maria Fenech', updated_at: '2026-04-10T09:00:00Z', created_at: '2026-01-20T08:00:00Z' },
];

const DEMO_TRANSACTIONS: WalletTransaction[] = [
  { id: 't-001', user_id: 'u-001', tx_type: 'earn', direction: 'credit', amount_fet: 5000, balance_before_fet: 7500, balance_after_fet: 12500, reference_type: 'welcome_bonus', reference_id: null, metadata: null, title: 'Welcome bonus', created_at: '2026-04-17T14:00:00Z' },
  { id: 't-002', user_id: 'u-002', tx_type: 'transfer', direction: 'debit', amount_fet: 2000, balance_before_fet: 37000, balance_after_fet: 35000, reference_type: 'peer_transfer', reference_id: 'u-005', metadata: null, title: 'Transfer to Daniel G.', created_at: '2026-04-17T15:30:00Z' },
  { id: 't-003', user_id: 'u-005', tx_type: 'transfer', direction: 'credit', amount_fet: 2000, balance_before_fet: 54700, balance_after_fet: 56700, reference_type: 'peer_transfer', reference_id: 'u-002', metadata: null, title: 'Transfer received', created_at: '2026-04-17T15:30:00Z' },
  { id: 't-004', user_id: 'u-007', tx_type: 'transfer', direction: 'debit', amount_fet: 50000, balance_before_fet: 200000, balance_after_fet: 150000, reference_type: 'peer_transfer', reference_id: 'unknown', metadata: { flagged: true }, title: 'Transfer to unknown', created_at: '2026-04-15T03:15:00Z' },
  { id: 't-005', user_id: 'u-003', tx_type: 'contribution', direction: 'debit', amount_fet: 1000, balance_before_fet: 9200, balance_after_fet: 8200, reference_type: 'team_contribution', reference_id: null, metadata: null, title: 'Team contribution', created_at: '2026-04-17T10:00:00Z' },
  { id: 't-006', user_id: 'u-006', tx_type: 'challenge_stake', direction: 'debit', amount_fet: 2000, balance_before_fet: 21300, balance_after_fet: 19300, reference_type: 'pool', reference_id: 'p-1478', metadata: null, title: 'Pool #1478 entry', created_at: '2026-04-16T20:00:00Z' },
  { id: 't-007', user_id: 'u-006', tx_type: 'challenge_payout', direction: 'credit', amount_fet: 4000, balance_before_fet: 19300, balance_after_fet: 23300, reference_type: 'pool', reference_id: 'p-1478', metadata: null, title: 'Pool #1478 winnings', created_at: '2026-04-17T21:30:00Z' },
];

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
    demoData: DEMO_WALLETS.filter(w => {
      if (filters?.status && filters.status !== 'all' && w.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return w.display_name.toLowerCase().includes(q) || w.user_id.includes(q);
      }
      return true;
    }),
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
      demoData: DEMO_TRANSACTIONS.filter(t => t.user_id === userId),
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
    demoFn: async () => ({ frozen: true }),
  });
}

export function useUnfreezeWallet() {
  return useRpcMutation<{ p_target_user_id: string }>({
    fnName: 'admin_unfreeze_wallet',
    invalidateKeys: [['wallets']],
    successMessage: 'Wallet unfrozen successfully.',
    errorMessage: 'Failed to unfreeze wallet.',
    demoFn: async () => ({ unfrozen: true }),
  });
}

export function useCreditFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_credit_fet',
    invalidateKeys: [['wallets'], ['wallet-transactions'], ['dashboard-kpis']],
    successMessage: 'FET credited successfully.',
    errorMessage: 'Failed to credit FET.',
    demoFn: async () => ({ credited: true }),
  });
}

export function useDebitFet() {
  return useRpcMutation<{ p_target_user_id: string; p_amount: number; p_reason: string }>({
    fnName: 'admin_debit_fet',
    invalidateKeys: [['wallets'], ['wallet-transactions'], ['dashboard-kpis']],
    successMessage: 'FET debited successfully.',
    errorMessage: 'Failed to debit FET.',
    demoFn: async () => ({ debited: true }),
  });
}
