// FANZONE Admin — Users Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { PlatformUser } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Hooks ── */
export function useUsers(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<PlatformUser>(['users', filters], 'user_profiles_admin', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<PlatformUser>) => {
      let q = query;
      if (filters?.search) {
        const term = `%${filters.search}%`;
        q = q.or(`display_name.ilike.${term},email.ilike.${term},phone.ilike.${term}`);
      }
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
  });
}

export function useBanUser() {
  return useRpcMutation<{ p_target_user_id: string; p_reason: string; p_banned_until: string | null }>({
    fnName: 'admin_ban_user',
    invalidateKeys: [['users'], ['dashboard-kpis']],
    successMessage: 'User banned successfully.',
    errorMessage: 'Failed to ban user.',
  });
}

export function useUnbanUser() {
  return useRpcMutation<{ p_target_user_id: string }>({
    fnName: 'admin_unban_user',
    invalidateKeys: [['users']],
    successMessage: 'User unbanned successfully.',
    errorMessage: 'Failed to unban user.',
  });
}
