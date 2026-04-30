// FANZONE Admin — Moderation Data Hooks
import {
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
