// FANZONE Admin — Audit Logs Data Hooks
import { useSupabasePaginated, type AdminListQuery } from '../../hooks/useSupabaseQuery';
import type { AuditLog } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useAuditLogs(
  pagination: PaginationOpts,
  filters?: {
    module?: string;
    search?: string;
    action?: string;
    entity?: string;
    dateFrom?: string;
    dateTo?: string;
  },
) {
  return useSupabasePaginated<AuditLog>(['audit-logs', filters], 'admin_audit_logs_enriched', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<AuditLog>) => {
      let q = query;
      if (filters?.module && filters.module !== 'all') q = q.eq('module', filters.module);
      if (filters?.action?.trim()) q = q.ilike('action', `%${filters.action.trim()}%`);
      if (filters?.entity?.trim()) {
        const term = `%${filters.entity.trim()}%`;
        q = q.or(`target_type.ilike.${term},target_id.ilike.${term}`);
      }
      if (filters?.dateFrom) q = q.gte('created_at', new Date(filters.dateFrom).toISOString());
      if (filters?.dateTo) q = q.lte('created_at', new Date(filters.dateTo).toISOString());
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
  'countries', 'venues', 'competitions', 'teams',
  'curated-matches', 'pools', 'wallets', 'settlements',
  'reward-rules', 'risk-abuse', 'feature-flags', 'auth',
] as const;
