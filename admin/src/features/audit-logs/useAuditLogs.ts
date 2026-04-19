// FANZONE Admin — Audit Logs Data Hooks
import { useSupabasePaginated, type AdminListQuery } from '../../hooks/useSupabaseQuery';
import type { AuditLog } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_LOGS: AuditLog[] = [
  { id: 'al-001', admin_user_id: 'a-001', action: 'toggle_feature_flag', module: 'settings', target_type: 'feature_flag', target_id: 'ff-4', before_state: { is_enabled: false }, after_state: { is_enabled: true }, metadata: {}, ip_address: '192.168.1.1', created_at: '2026-04-17T22:00:00Z', admin_name: 'Jean Bosco', admin_email: 'admin@fanzone.mt' },
  { id: 'al-002', admin_user_id: 'a-002', action: 'approve_partner', module: 'partners', target_type: 'partner', target_id: 'pt-1', before_state: { status: 'pending' }, after_state: { status: 'approved' }, metadata: {}, ip_address: '192.168.1.2', created_at: '2026-04-17T14:30:00Z', admin_name: 'Maria Camilleri', admin_email: 'maria@fanzone.mt' },
  { id: 'al-003', admin_user_id: 'a-002', action: 'fulfill_redemption', module: 'redemptions', target_type: 'redemption', target_id: 'rd-045', before_state: { status: 'approved' }, after_state: { status: 'fulfilled' }, metadata: {}, ip_address: '192.168.1.2', created_at: '2026-04-17T13:00:00Z', admin_name: 'Maria Camilleri', admin_email: 'maria@fanzone.mt' },
  { id: 'al-004', admin_user_id: 'a-003', action: 'resolve_report', module: 'moderation', target_type: 'report', target_id: 'rpt-4', before_state: { status: 'open' }, after_state: { status: 'resolved' }, metadata: { resolution_notes: 'Display name changed' }, ip_address: '192.168.1.3', created_at: '2026-04-16T16:00:00Z', admin_name: 'Luke Debono', admin_email: 'luke@fanzone.mt' },
  { id: 'al-005', admin_user_id: 'a-001', action: 'ban_user', module: 'users', target_type: 'user', target_id: 'u-004', before_state: { is_banned: false }, after_state: { is_banned: true, reason: 'Multiple fraud reports' }, metadata: {}, ip_address: '192.168.1.1', created_at: '2026-04-16T10:00:00Z', admin_name: 'Jean Bosco', admin_email: 'admin@fanzone.mt' },
  { id: 'al-006', admin_user_id: 'a-001', action: 'create_reward', module: 'rewards', target_type: 'reward', target_id: 'r-4', before_state: null, after_state: { title: 'Free coffee at Bar Castello', fet_cost: 500 }, metadata: {}, ip_address: '192.168.1.1', created_at: '2026-04-15T11:00:00Z', admin_name: 'Jean Bosco', admin_email: 'admin@fanzone.mt' },
  { id: 'al-007', admin_user_id: 'a-002', action: 'update_fixture_result', module: 'fixtures', target_type: 'match', target_id: 'f-005', before_state: { status: 'live', ft_home: null, ft_away: null }, after_state: { status: 'finished', ft_home: 2, ft_away: 0 }, metadata: {}, ip_address: '192.168.1.2', created_at: '2026-04-15T09:30:00Z', admin_name: 'Maria Camilleri', admin_email: 'maria@fanzone.mt' },
  { id: 'al-008', admin_user_id: 'a-001', action: 'invite_admin', module: 'admin-access', target_type: 'admin_user', target_id: 'a-003', before_state: null, after_state: { email: 'luke@fanzone.mt', role: 'moderator' }, metadata: {}, ip_address: '192.168.1.1', created_at: '2026-02-01T10:00:00Z', admin_name: 'Jean Bosco', admin_email: 'admin@fanzone.mt' },
];

/* ── Hooks ── */
export function useAuditLogs(pagination: PaginationOpts, filters?: { module?: string; search?: string }) {
  return useSupabasePaginated<AuditLog>(['audit-logs', filters], 'admin_audit_logs_enriched', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<AuditLog>) => {
      let q = query;
      if (filters?.module && filters.module !== 'all') q = q.eq('module', filters.module);
      if (filters?.search) {
        const term = `%${filters.search}%`;
        q = q.or(`admin_name.ilike.${term},action.ilike.${term},target_id.ilike.${term}`);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
    demoData: DEMO_LOGS.filter(l => {
      if (filters?.module && filters.module !== 'all' && l.module !== filters.module) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return (l.admin_name ?? '').toLowerCase().includes(q) ||
          l.action.includes(q) ||
          (l.target_id ?? '').includes(q);
      }
      return true;
    }),
  });
}

export const AUDIT_MODULES = [
  'users', 'challenges', 'fixtures', 'wallets', 'tokens',
  'partners', 'rewards', 'redemptions', 'moderation',
  'settings', 'admin-access', 'content', 'auth',
] as const;
