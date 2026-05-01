// FANZONE Admin — Moderation Data Hooks
import {
  useSupabaseRpc,
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { ModerationReport } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useReports(pagination: PaginationOpts, filters?: { status?: string; search?: string }) {
  return useSupabasePaginated<ModerationReport>(['reports', filters], 'moderation_reports', {
    pagination,
    select: '*, admin_users(display_name)',
    filters: (query: AdminListQuery<ModerationReport>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') q = q.eq('status', filters.status);
      return q;
    },
    order: { column: 'created_at', ascending: false },
  });
}

export function useUpdateReportStatus() {
  return useRpcMutation<{
    p_report_id: string;
    p_status: string;
    p_resolution_notes?: string | null;
  }>({
    fnName: 'admin_update_moderation_report_status',
    invalidateKeys: [['reports'], ['dashboard-kpis'], ['dashboard-alerts']],
    successMessage: 'Report status updated.',
  });
}

export interface AdminRiskSignal {
  signal_type: string;
  severity: 'critical' | 'warning' | 'info' | string;
  entity_type: string;
  entity_id: string;
  message: string;
  created_at: string;
  metadata: Record<string, unknown>;
}

export function useAdminRiskSignals(limit = 50) {
  return useSupabaseRpc<AdminRiskSignal[]>(
    ['admin-risk-signals', limit],
    'admin_risk_signals',
    { p_limit: limit },
  );
}
