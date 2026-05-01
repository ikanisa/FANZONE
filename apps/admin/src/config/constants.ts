// FANZONE Admin — Shared Constants

export const ADMIN_ROLES = ['super_admin', 'admin', 'moderator', 'viewer'] as const;
export type AdminRole = typeof ADMIN_ROLES[number];

export const ROLE_HIERARCHY: Record<AdminRole, number> = {
  super_admin: 4,
  admin: 3,
  moderator: 2,
  viewer: 1,
};

export const PAGE_SIZE = 25;
export const MAX_PAGE_SIZE = 100;
