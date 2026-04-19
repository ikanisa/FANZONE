// FANZONE Admin — Admin Access Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { AdminUser } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';
import type { AdminRole } from '../../config/constants';

/* ── Hooks ── */
export function useAdminUsers(pagination: PaginationOpts) {
  return useSupabasePaginated<AdminUser>(['admin-users'], 'admin_users', {
    pagination,
    order: { column: 'created_at', ascending: true },
  });
}

export function useInviteAdmin() {
  return useRpcMutation<{ p_phone: string; p_role: AdminRole }>({
    fnName: 'admin_grant_access',
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin access granted.',
  });
}

export function useRevokeAdmin() {
  return useRpcMutation<{ p_admin_id: string }>({
    fnName: 'admin_revoke_access',
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin access revoked.',
  });
}

export function useChangeAdminRole() {
  return useRpcMutation<{ p_admin_id: string; p_role: AdminRole }>({
    fnName: 'admin_change_admin_role',
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin role updated.',
  });
}
