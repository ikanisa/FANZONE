// FANZONE Admin — Moderation Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { ModerationReport } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_REPORTS: ModerationReport[] = [
  { id: 'rpt-1', reporter_user_id: null, target_type: 'transfer', target_id: 't-004', reason: 'Suspicious high-value transfer', description: 'Automated flag: 50,000 FET transfer from newly created account', status: 'open', severity: 'critical', assigned_to: null, resolution_notes: null, created_at: '2026-04-15T03:20:00Z', updated_at: '2026-04-15T03:20:00Z' },
  { id: 'rpt-2', reporter_user_id: null, target_type: 'user', target_id: 'u-007', reason: 'Account created solely for large transfer', description: 'Automated flag: Account age < 1h with transfer > 10K FET', status: 'investigating', severity: 'high', assigned_to: 'a-002', resolution_notes: null, created_at: '2026-04-15T03:25:00Z', updated_at: '2026-04-16T10:00:00Z' },
  { id: 'rpt-3', reporter_user_id: null, target_type: 'challenge', target_id: 'p-1475', reason: 'Pool with only 2 participants and 100K FET', description: 'Potential collusion or wash trading', status: 'open', severity: 'high', assigned_to: null, resolution_notes: null, created_at: '2026-04-16T08:00:00Z', updated_at: '2026-04-16T08:00:00Z' },
  { id: 'rpt-4', reporter_user_id: 'u-003', target_type: 'user', target_id: 'u-012', reason: 'Abusive display name', description: 'User report: offensive username', status: 'resolved', severity: 'low', assigned_to: 'a-003', resolution_notes: 'Display name changed by admin', created_at: '2026-04-14T12:00:00Z', updated_at: '2026-04-14T15:00:00Z' },
  { id: 'rpt-5', reporter_user_id: null, target_type: 'redemption', target_id: 'rd-044', reason: 'Disputed redemption from flagged account', description: 'Account was flagged for suspicious activity', status: 'escalated', severity: 'medium', assigned_to: 'a-001', resolution_notes: null, created_at: '2026-04-15T10:00:00Z', updated_at: '2026-04-16T12:00:00Z' },
];

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
    demoData: DEMO_REPORTS.filter(r => {
      if (filters?.status && filters.status !== 'all' && r.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return r.reason.toLowerCase().includes(q) || r.target_id.includes(q) || r.target_type.includes(q);
      }
      return true;
    }),
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
    demoFn: async () => ({ updated: true }),
  });
}
