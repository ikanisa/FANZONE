// FANZONE Admin — Dashboard Data Hooks
import { useQuery } from '@tanstack/react-query';
import { countAdminRows, fetchAdminRows, runAdminRpc } from '../../lib/adminData';
import type { AuditLog } from '../../types';

/* ── KPI Types ── */
export interface DashboardKpis {
  activeUsers: number;
  activePools: number;
  totalFetIssued: number;
  fetTransferred24h: number;
  pendingRedemptions: number;
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

interface PoolSettlementIntegritySummary {
  checked_pool_count: number;
  reconciled_pool_count: number;
  unreconciled_pool_count: number;
  total_expected_credit_fet: number;
  total_entry_payout_fet: number;
  total_wallet_credit_fet: number;
  sample_unreconciled_pool_ids: string[];
  since: string | null;
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

      const pendingRd = await countAdminRows('redemptions', (query) =>
        query.eq('status', 'disputed'),
      );

      if (pendingRd > 0) {
        alerts.push({ id: 'sa-disp', severity: 'warning', message: `${pendingRd} redemption disputes need resolution`, module: 'Redemptions' });
      }

      const dueCampaigns = await countAdminRows('campaigns', (query) =>
        query
          .eq('status', 'scheduled')
          .lte('scheduled_at', new Date().toISOString()),
      );

      if (dueCampaigns > 0) {
        alerts.push({
          id: 'sa-campaigns',
          severity: 'info',
          message: `${dueCampaigns} scheduled campaign${dueCampaigns > 1 ? 's are' : ' is'} ready to dispatch`,
          module: 'Notifications',
        });
      }

      const settlementIntegrity =
        await runAdminRpc<PoolSettlementIntegritySummary | null>(
          'get_pool_settlement_integrity_summary',
          {
          p_since: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
          },
        );

      const unreconciledCount = settlementIntegrity?.unreconciled_pool_count ?? 0;
      if (unreconciledCount > 0) {
        const samplePool = settlementIntegrity?.sample_unreconciled_pool_ids?.[0];
        alerts.push({
          id: 'sa-settlement-integrity',
          severity: 'critical',
          message: unreconciledCount === 1
            ? `1 pool settlement failed reconciliation${samplePool ? ` (${samplePool})` : ''}`
            : `${unreconciledCount} pool settlements failed reconciliation`,
          module: 'Settlement',
        });
      }

      return alerts;
    },
    refetchInterval: 120_000,
  });
}
