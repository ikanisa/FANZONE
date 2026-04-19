// FANZONE Admin — Settings (Feature Flags) Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { FeatureFlag } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO: FeatureFlag[] = [
  { id: 'ff-1', key: 'enable_predictions', label: 'Predictions', description: 'Allow users to make match predictions', is_enabled: true, market: 'MT', module: 'Predictions', config: {}, updated_by: 'a-001', created_at: '2025-12-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'ff-2', key: 'enable_wallet', label: 'FET Wallet', description: 'Show wallet and FET balance to users', is_enabled: true, market: 'MT', module: 'Wallet', config: {}, updated_by: 'a-001', created_at: '2025-12-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'ff-3', key: 'enable_leaderboard', label: 'Leaderboard', description: 'Show global FET leaderboard', is_enabled: true, market: 'MT', module: 'Leaderboard', config: {}, updated_by: 'a-001', created_at: '2025-12-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'ff-4', key: 'enable_rewards', label: 'Rewards', description: 'Allow FET redemption with partners', is_enabled: true, market: 'MT', module: 'Rewards', config: {}, updated_by: 'a-001', created_at: '2025-12-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
  { id: 'ff-5', key: 'enable_membership', label: 'Membership Tiers', description: 'Show membership tier system', is_enabled: false, market: 'MT', module: 'Membership', config: {}, updated_by: null, created_at: '2026-01-15T10:00:00Z', updated_at: '2026-01-15T10:00:00Z' },
  { id: 'ff-6', key: 'enable_notifications', label: 'Push Notifications', description: 'Enable push notification campaigns', is_enabled: false, market: 'MT', module: 'Notifications', config: {}, updated_by: null, created_at: '2026-02-01T10:00:00Z', updated_at: '2026-02-01T10:00:00Z' },
  { id: 'ff-7', key: 'enable_team_communities', label: 'Team Communities', description: 'Fan team pages and FET contributions', is_enabled: true, market: 'MT', module: 'Teams', config: {}, updated_by: 'a-001', created_at: '2026-03-01T10:00:00Z', updated_at: '2026-04-10T10:00:00Z' },
  { id: 'ff-8', key: 'enable_eu_market', label: 'EU Market Expansion', description: 'Enable features for wider EU market', is_enabled: false, market: 'EU', module: 'System', config: {}, updated_by: null, created_at: '2026-04-01T10:00:00Z', updated_at: '2026-04-01T10:00:00Z' },
];

/* ── Hooks ── */
export function useFeatureFlags(pagination: PaginationOpts) {
  return useSupabasePaginated<FeatureFlag>(['feature-flags'], 'admin_feature_flags', {
    pagination,
    order: { column: 'module', ascending: true },
    demoData: DEMO,
  });
}

export function useToggleFeatureFlag() {
  return useRpcMutation<{ p_flag_id: string; p_is_enabled: boolean }>({
    fnName: 'admin_set_feature_flag',
    invalidateKeys: [['feature-flags']],
    successMessage: 'Feature flag updated.',
    demoFn: async () => ({ toggled: true }),
  });
}
