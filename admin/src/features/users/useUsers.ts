// FANZONE Admin — Users Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { PlatformUser } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';
import { getUserDisplayName, getUserStatus } from './userHelpers';

/* ── Demo Data ── */
const DEMO_USERS: PlatformUser[] = [
  { id: 'u-001', email: 'marco@gmail.com', phone: '+356 7912 3456', raw_user_meta_data: { display_name: 'Marco Spiteri' }, created_at: '2026-01-15T10:00:00Z', last_sign_in_at: '2026-04-17T14:30:00Z', available_balance_fet: 12500, locked_balance_fet: 500 },
  { id: 'u-002', email: 'sarah.borg@outlook.com', phone: '+356 7945 6789', raw_user_meta_data: { display_name: 'Sarah Borg' }, created_at: '2026-02-03T09:00:00Z', last_sign_in_at: '2026-04-17T18:00:00Z', available_balance_fet: 35000, locked_balance_fet: 1000 },
  { id: 'u-003', email: null, phone: '+356 7934 5678', raw_user_meta_data: { display_name: 'Jake Calleja' }, created_at: '2026-03-10T12:00:00Z', last_sign_in_at: '2026-04-16T20:00:00Z', available_balance_fet: 8200, locked_balance_fet: 0 },
  { id: 'u-004', email: 'maria.f@gmail.com', phone: '+356 7923 4567', raw_user_meta_data: { display_name: 'Maria Fenech', is_banned: true, ban_reason: 'Multiple fraud reports' }, created_at: '2026-01-20T08:00:00Z', last_sign_in_at: '2026-04-10T09:00:00Z', available_balance_fet: 0, locked_balance_fet: 0 },
  { id: 'u-005', email: 'dgrech@hotmail.com', phone: '+356 7956 7890', raw_user_meta_data: { display_name: 'Daniel Grech' }, created_at: '2025-12-01T10:00:00Z', last_sign_in_at: '2026-04-17T22:00:00Z', available_balance_fet: 56700, locked_balance_fet: 2000 },
  { id: 'u-006', email: 'isla.c@gmail.com', phone: '+356 7967 8901', raw_user_meta_data: { display_name: 'Isla Camilleri' }, created_at: '2026-02-14T14:00:00Z', last_sign_in_at: '2026-04-17T16:00:00Z', available_balance_fet: 19300, locked_balance_fet: 0 },
  { id: 'u-007', email: null, phone: '+356 7978 9012', raw_user_meta_data: { display_name: 'TestUser_flagged', is_banned: false }, created_at: '2026-04-15T03:00:00Z', last_sign_in_at: '2026-04-15T03:30:00Z', available_balance_fet: 150000, locked_balance_fet: 50000 },
];

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
    demoData: DEMO_USERS.filter(u => {
      if (filters?.status && filters.status !== 'all') {
        const s = getUserStatus(u);
        if (s !== filters.status) return false;
      }
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        const name = getUserDisplayName(u).toLowerCase();
        return name.includes(q) || u.email?.toLowerCase().includes(q) || u.phone?.includes(q) || u.id.includes(q);
      }
      return true;
    }),
  });
}

export function useBanUser() {
  return useRpcMutation<{ p_target_user_id: string; p_reason: string; p_banned_until: string | null }>({
    fnName: 'admin_ban_user',
    invalidateKeys: [['users'], ['dashboard-kpis']],
    successMessage: 'User banned successfully.',
    errorMessage: 'Failed to ban user.',
    demoFn: async () => ({ banned: true }),
  });
}

export function useUnbanUser() {
  return useRpcMutation<{ p_target_user_id: string }>({
    fnName: 'admin_unban_user',
    invalidateKeys: [['users']],
    successMessage: 'User unbanned successfully.',
    errorMessage: 'Failed to unban user.',
    demoFn: async () => ({ unbanned: true }),
  });
}
