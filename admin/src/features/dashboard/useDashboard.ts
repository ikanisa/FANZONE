// FANZONE Admin — Dashboard Data Hooks
import { useQuery } from '@tanstack/react-query';
import { countAdminRows, fetchAdminRows, runAdminRpc } from '../../lib/adminData';
import { isDemoMode } from '../../lib/supabase';
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

/* ── Demo Data ── */
const DEMO_KPIS: DashboardKpis = {
  activeUsers: 3847,
  activePools: 156,
  totalFetIssued: 12450000,
  fetTransferred24h: 245000,
  pendingRedemptions: 23,
  moderationAlerts: 5,
  competitionsCount: 12,
  upcomingFixtures: 8,
};

const DEMO_ACTIVITY: AuditLog[] = [
  { id: 'al-r1', admin_user_id: 'a-001', action: 'user_registered', module: 'users', target_type: 'user', target_id: 'u-new', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 120000).toISOString(), admin_name: 'System', admin_email: 'system' },
  { id: 'al-r2', admin_user_id: 'a-001', action: 'create_pool', module: 'challenges', target_type: 'challenge', target_id: 'p-1482', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 300000).toISOString(), admin_name: 'System', admin_email: 'system' },
  { id: 'al-r3', admin_user_id: 'a-002', action: 'submit_partner', module: 'partners', target_type: 'partner', target_id: 'pt-4', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 900000).toISOString(), admin_name: 'System', admin_email: 'system' },
  { id: 'al-r4', admin_user_id: 'a-002', action: 'fulfill_redemption', module: 'redemptions', target_type: 'redemption', target_id: 'rd-045', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 1800000).toISOString(), admin_name: 'Maria Camilleri', admin_email: 'maria@fanzone.mt' },
  { id: 'al-r5', admin_user_id: 'a-001', action: 'flag_transfer', module: 'moderation', target_type: 'transaction', target_id: 't-004', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 3600000).toISOString(), admin_name: 'System', admin_email: 'system' },
  { id: 'al-r6', admin_user_id: 'a-001', action: 'update_fixtures', module: 'fixtures', target_type: 'competition', target_id: 'mpl', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 7200000).toISOString(), admin_name: 'System', admin_email: 'system' },
  { id: 'al-r7', admin_user_id: 'a-001', action: 'toggle_feature_flag', module: 'settings', target_type: 'feature_flag', target_id: 'enable_rewards', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 14400000).toISOString(), admin_name: 'Jean Bosco', admin_email: 'admin@fanzone.mt' },
  { id: 'al-r8', admin_user_id: 'a-002', action: 'admin_login', module: 'auth', target_type: 'admin_user', target_id: 'a-002', before_state: null, after_state: null, metadata: {}, ip_address: null, created_at: new Date(Date.now() - 28800000).toISOString(), admin_name: 'Maria Camilleri', admin_email: 'maria@fanzone.mt' },
];

const DEMO_ALERTS: SystemAlert[] = [
  { id: 'sa-1', severity: 'critical', message: '3 high-value transfers pending review', module: 'Tokens' },
  { id: 'sa-2', severity: 'warning', message: '2 redemption disputes need resolution', module: 'Redemptions' },
  { id: 'sa-3', severity: 'info', message: 'UCL fixtures available for import', module: 'Fixtures' },
];

/* ── Hooks ── */
export function useDashboardKpis() {
  return useQuery<DashboardKpis>({
    queryKey: ['dashboard-kpis'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_KPIS;
      return runAdminRpc<DashboardKpis>('admin_dashboard_kpis');
    },
    refetchInterval: 60_000, // Refresh every minute
  });
}

export function useRecentActivity() {
  return useQuery<AuditLog[]>({
    queryKey: ['dashboard-activity'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_ACTIVITY;
      return fetchAdminRows<AuditLog>('admin_audit_logs_enriched', (query) =>
        query.order('created_at', { ascending: false }).limit(10),
      );
    },
    refetchInterval: 30_000,
  });
}

export function useSystemAlerts() {
  return useQuery<SystemAlert[]>({
    queryKey: ['dashboard-alerts'],
    queryFn: async () => {
      if (isDemoMode) return DEMO_ALERTS;

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
