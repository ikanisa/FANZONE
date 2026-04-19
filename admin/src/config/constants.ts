// FANZONE Admin — Shared Constants

export const ADMIN_ROLES = ['super_admin', 'admin', 'moderator', 'viewer'] as const;
export type AdminRole = typeof ADMIN_ROLES[number];

export const ROLE_HIERARCHY: Record<AdminRole, number> = {
  super_admin: 4,
  admin: 3,
  moderator: 2,
  viewer: 1,
};

export const CHALLENGE_STATUSES = ['open', 'locked', 'settled', 'cancelled'] as const;
export const ENTRY_STATUSES = ['active', 'won', 'lost', 'cancelled'] as const;
export const PARTNER_STATUSES = ['pending', 'approved', 'rejected', 'suspended', 'archived'] as const;
export const PARTNER_CATEGORIES = ['bar', 'hospitality', 'insurance', 'leisure', 'merchant', 'other'] as const;
export const REDEMPTION_STATUSES = ['pending', 'approved', 'fulfilled', 'rejected', 'disputed'] as const;
export const REPORT_STATUSES = ['open', 'investigating', 'resolved', 'dismissed', 'escalated'] as const;
export const REPORT_SEVERITIES = ['low', 'medium', 'high', 'critical'] as const;
export const CAMPAIGN_TYPES = ['push', 'in_app', 'email'] as const;
export const CAMPAIGN_STATUSES = ['draft', 'scheduled', 'sent', 'cancelled'] as const;
export const MATCH_STATUSES = ['upcoming', 'live', 'finished', 'postponed', 'cancelled'] as const;
export const MARKETS = ['MT', 'EU'] as const;

export const PAGE_SIZE = 25;
export const MAX_PAGE_SIZE = 100;
