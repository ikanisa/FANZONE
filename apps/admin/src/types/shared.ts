export interface PaginatedResult<T> {
  data: T[];
  count: number;
  page: number;
  pageSize: number;
}

export interface DashboardKpi {
  label: string;
  value: number;
  trend?: number;
  trendDirection?: 'up' | 'down' | 'neutral';
  icon?: string;
}

export interface Venue {
  id: string;
  name: string;
  slug: string;
  description?: string | null;
  address_line1?: string | null;
  country_code: string;
  country_id?: string | null;
  city?: string | null;
  status?: string | null;
  type?: string | null;
  fet_reward_percent?: number | null;
  accepts_fet_spend?: boolean | null;
  payment_methods?: string[] | null;
  logo_url?: string | null;
  cover_url?: string | null;
  is_active: boolean;
  is_open: boolean;
  primary_category?: string | null;
  rating?: number | null;
  price_level?: number | null;
  claimed: boolean;
  owner_email?: string | null;
  created_at: string;
}

export interface HospitalityAuditStats {
  totalOrders: number;
  totalRevenueEur: number;
  totalFetRedeemed: number;
  totalStakesCreated: number;
  totalStakedFet: number;
  activeVenuesCount: number;
}
