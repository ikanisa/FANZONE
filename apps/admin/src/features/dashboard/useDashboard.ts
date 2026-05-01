// FANZONE Admin — Dashboard Data Hooks
import { useQuery } from '@tanstack/react-query';
import { countAdminRows, fetchAdminRows, runAdminRpc } from '../../lib/adminData';
import type { AuditLog } from '../../types';

/* ── KPI Types ── */
export interface DashboardKpis {
  activeCountries: number;
  activeVenues: number;
  activePools: number;
  activeUsers: number;
  openPools: number;
  totalFetIssued: number;
  totalFetStaked: number;
  fetTransferred24h: number;
  pendingSettlements: number;
  failedSettlements: number;
  todaysOrders: number;
  riskAlerts: number;
  moderationAlerts: number;
  competitionsCount: number;
  upcomingFixtures: number;
}

export interface SystemAlert {
  id: string;
  severity: 'critical' | 'warning' | 'info';
  message: string;
  module: string;
}

/* ── Hooks ── */
export function useDashboardKpis() {
  return useQuery<DashboardKpis>({
    queryKey: ['dashboard-kpis'],
    queryFn: async () => runAdminRpc<DashboardKpis>('admin_dashboard_kpis'),
    refetchInterval: 60_000, // Refresh every minute
  });
}

export function useRecentActivity() {
  return useQuery<AuditLog[]>({
    queryKey: ['dashboard-activity'],
    queryFn: async () => fetchAdminRows<AuditLog>('admin_audit_logs_enriched', (query) =>
      query.order('created_at', { ascending: false }).limit(10),
    ),
    refetchInterval: 30_000,
  });
}

export function useSystemAlerts() {
  return useQuery<SystemAlert[]>({
    queryKey: ['dashboard-alerts'],
    queryFn: async () => {
      const alerts: SystemAlert[] = [];

      const flaggedTx = await countAdminRows('moderation_reports', (query) =>
        query.eq('status', 'open').eq('severity', 'critical'),
      );

      if (flaggedTx > 0) {
        alerts.push({ id: 'sa-crit', severity: 'critical', message: `${flaggedTx} critical reports need immediate attention`, module: 'Moderation' });
      }

      const pendingSettlements = await countAdminRows('match_pools', (query) =>
        query.in('status', ['open', 'locked', 'live', 'settling']),
      );

      if (pendingSettlements > 0) {
        alerts.push({
          id: 'sa-pool-settlement',
          severity: 'warning',
          message: `${pendingSettlements} pool${pendingSettlements > 1 ? 's are' : ' is'} awaiting settlement or active monitoring`,
          module: 'Pools',
        });
      }

      return alerts;
    },
    refetchInterval: 120_000,
  });
}
