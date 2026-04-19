// FANZONE Admin — Settings (Feature Flags) Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { FeatureFlag } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useFeatureFlags(pagination: PaginationOpts) {
  return useSupabasePaginated<FeatureFlag>(['feature-flags'], 'admin_feature_flags', {
    pagination,
    order: { column: 'module', ascending: true },
  });
}

export function useToggleFeatureFlag() {
  return useRpcMutation<{ p_flag_id: string; p_is_enabled: boolean }>({
    fnName: 'admin_set_feature_flag',
    invalidateKeys: [['feature-flags']],
    successMessage: 'Feature flag updated.',
  });
}
