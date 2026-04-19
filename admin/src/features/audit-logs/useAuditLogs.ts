// FANZONE Admin — Audit Logs Data Hooks
import { useSupabasePaginated, type AdminListQuery } from '../../hooks/useSupabaseQuery';
import type { AuditLog } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

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
  });
}

export const AUDIT_MODULES = [
  'users', 'challenges', 'fixtures', 'wallets', 'tokens',
  'partners', 'rewards', 'redemptions', 'moderation',
  'settings', 'admin-access', 'content', 'auth',
] as const;
