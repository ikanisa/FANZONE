import {
  useRpcMutation,
  useSupabaseMutation,
  useSupabaseRpc,
} from "../../hooks/useSupabaseQuery";
import { adminEnvError, isSupabaseConfigured, supabase } from "../../lib/supabase";

export interface PoolOperationsKpis {
  openPools: number;
  lockedPools: number;
  settlingPools: number;
  settled24h: number;
  failedSettlements: number;
  pendingFinalPools: number;
  staleSettlingPools: number;
  totalOpenStakeFet: number;
  socialCardsMissing: number;
  invites7d: number;
  inviteRewards7d: number;
}

export interface PoolOperationsRow {
  pool_id: string;
  title: string;
  scope: string;
  country_code: string | null;
  country_id: string | null;
  venue_id: string | null;
  venue_name: string | null;
  match_id: string;
  match_label: string;
  competition_name: string | null;
  kickoff_at: string | null;
  match_status: string | null;
  result_code: string | null;
  pool_status: string;
  total_members: number;
  total_staked_fet: number;
  camps: Array<{
    id: string;
    camp_key?: string;
    code?: string;
    label: string;
    member_count?: number;
    total_staked_fet?: number;
    is_winning_camp?: boolean;
  }>;
  settlement_status: string | null;
  settlement_started_at: string | null;
  settlement_completed_at: string | null;
  settlement_error: string | null;
  share_url: string | null;
  social_card_url: string | null;
  needs_settlement: boolean;
  needs_social_card: boolean;
  age_minutes: number;
}

function throwMissingAdminEnv(): never {
  throw new Error(adminEnvError);
}

export function usePoolOperationsKpis() {
  return useSupabaseRpc<PoolOperationsKpis>(
    ["pool-operations-kpis"],
    "admin_pool_operations_kpis",
    {},
    { enabled: true },
  );
}

export function usePoolOperationsQueue(limit = 75) {
  return useSupabaseRpc<PoolOperationsRow[]>(
    ["pool-operations-queue", limit],
    "admin_pool_operations_queue",
    { p_limit: limit },
    { enabled: true },
  );
}

export function useRunPoolSettlement() {
  return useRpcMutation<{ p_limit: number }>({
    fnName: "admin_run_pool_settlement",
    invalidateKeys: [
      ["pool-operations-kpis"],
      ["pool-operations-queue"],
      ["dashboard-kpis"],
    ],
    successMessage: "Pool settlement run completed.",
  });
}

export function useGeneratePoolSocialCard() {
  return useSupabaseMutation<{ poolId: string }, { social_card_url: string }>({
    mutationFn: async ({ poolId }) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { data, error } = await supabase.functions.invoke(
        "generate-pool-social-card",
        { body: { pool_id: poolId } },
      );

      if (error) throw new Error(error.message);
      return data as { social_card_url: string };
    },
    invalidateKeys: [
      ["pool-operations-kpis"],
      ["pool-operations-queue"],
      ["dashboard-kpis"],
    ],
    successMessage: "Social card generated.",
  });
}

export function useCancelRefundPool() {
  return useRpcMutation<{ p_pool_id: string; p_reason: string }>({
    fnName: "admin_cancel_refund_pool",
    invalidateKeys: [
      ["pool-operations-kpis"],
      ["pool-operations-queue"],
      ["dashboard-kpis"],
    ],
    successMessage: "Pool cancelled and refunded.",
  });
}

export function useRetryPoolSettlement() {
  return useRpcMutation<{ p_pool_id: string; p_reason: string }>({
    fnName: "admin_retry_pool_settlement",
    invalidateKeys: [
      ["pool-operations-kpis"],
      ["pool-operations-queue"],
      ["dashboard-kpis"],
    ],
    successMessage: "Settlement retry started.",
  });
}
