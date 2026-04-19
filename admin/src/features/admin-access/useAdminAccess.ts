// FANZONE Admin — Admin Access Data Hooks
import { useRpcMutation, useSupabasePaginated } from '../../hooks/useSupabaseQuery';
import type { AdminUser } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';
import type { AdminRole } from '../../config/constants';

/* ── Demo Data ── */
const DEMO: AdminUser[] = [
  { id: 'a-001', user_id: 'auth-001', email: 'admin@fanzone.mt', display_name: 'Jean Bosco', role: 'super_admin', permissions: {}, is_active: true, invited_by: null, last_login_at: '2026-04-18T00:00:00Z', created_at: '2025-12-01T10:00:00Z', updated_at: '2026-04-18T00:00:00Z' },
  { id: 'a-002', user_id: 'auth-002', email: 'maria.c@fanzone.mt', display_name: 'Maria Camilleri', role: 'admin', permissions: {}, is_active: true, invited_by: 'a-001', last_login_at: '2026-04-17T14:00:00Z', created_at: '2026-01-15T10:00:00Z', updated_at: '2026-04-17T14:00:00Z' },
  { id: 'a-003', user_id: 'auth-003', email: 'luke.d@fanzone.mt', display_name: 'Luke Debono', role: 'moderator', permissions: {}, is_active: true, invited_by: 'a-001', last_login_at: '2026-04-16T09:00:00Z', created_at: '2026-02-01T10:00:00Z', updated_at: '2026-04-16T09:00:00Z' },
  { id: 'a-004', user_id: 'auth-004', email: 'sofia.a@fanzone.mt', display_name: 'Sofia Azzopardi', role: 'viewer', permissions: {}, is_active: false, invited_by: 'a-002', last_login_at: '2026-03-01T10:00:00Z', created_at: '2026-03-01T10:00:00Z', updated_at: '2026-03-15T10:00:00Z' },
];

/* ── Hooks ── */
export function useAdminUsers(pagination: PaginationOpts) {
  return useSupabasePaginated<AdminUser>(['admin-users'], 'admin_users', {
    pagination,
    order: { column: 'created_at', ascending: true },
    demoData: DEMO,
  });
}

export function useInviteAdmin() {
  return useRpcMutation<{ p_email: string; p_role: AdminRole }>({
    fnName: 'admin_grant_access',
    demoFn: async ({ p_email, p_role }) => ({
      id: `a-new-${Date.now()}`,
      email: p_email,
      role: p_role,
      is_active: true,
    }),
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin access granted.',
  });
}

export function useRevokeAdmin() {
  return useRpcMutation<{ p_admin_id: string }>({
    fnName: 'admin_revoke_access',
    demoFn: async () => ({ revoked: true }),
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin access revoked.',
  });
}

export function useChangeAdminRole() {
  return useRpcMutation<{ p_admin_id: string; p_role: AdminRole }>({
    fnName: 'admin_change_admin_role',
    demoFn: async () => ({ changed: true }),
    invalidateKeys: [['admin-users']],
    successMessage: 'Admin role updated.',
  });
}
