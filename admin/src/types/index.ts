// FANZONE Admin — TypeScript Types
import type { AdminRole } from '../config/constants';

/* ── Admin ── */
export interface AdminUser {
  id: string;
  user_id: string;
  email: string;
  display_name: string;
  role: AdminRole;
  permissions: Record<string, boolean>;
  is_active: boolean;
  invited_by: string | null;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Platform User ── */
export interface PlatformUser {
  id: string;
  email: string | null;
  phone: string | null;
  raw_user_meta_data: Record<string, unknown>;
  created_at: string;
  last_sign_in_at: string | null;
  // Joined from fet_wallets
  display_name?: string | null;
  status?: string;
  ban_reason?: string | null;
  suspend_reason?: string | null;
  wallet_freeze_reason?: string | null;
  available_balance_fet?: number;
  locked_balance_fet?: number;
}

/* ── Competition ── */
export interface Competition {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  tier: number | null;
  created_at: string;
}

/* ── Match / Fixture ── */
export interface Match {
  id: string;
  competition_id: string;
  season: string;
  round: string | null;
  match_group: string | null;
  date: string;
  kickoff_time: string | null;
  home_team_id: string | null;
  away_team_id: string | null;
  home_team: string;
  away_team: string;
  ft_home: number | null;
  ft_away: number | null;
  ht_home: number | null;
  ht_away: number | null;
  et_home: number | null;
  et_away: number | null;
  status: string;
  venue: string | null;
  data_source: string;
  source_url: string | null;
  home_logo_url: string | null;
  away_logo_url: string | null;
  home_multiplier: number | null;
  draw_multiplier: number | null;
  away_multiplier: number | null;
  created_at: string;
  updated_at: string;
}

/* ── Team ── */
export interface Team {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  competition_ids: string[] | null;
  logo_url: string | null;
  slug: string | null;
  crest_url: string | null;
  cover_image_url: string | null;
  description: string | null;
  league_name: string | null;
  is_active: boolean;
  is_featured: boolean;
  fan_count: number;
  created_at: string;
  updated_at: string;
}

/* ── Challenge (Pool) ── */
export interface Challenge {
  id: string;
  match_id: string;
  creator_user_id: string;
  stake_fet: number;
  currency_code: string | null;
  status: string;
  lock_at: string;
  settled_at: string | null;
  cancelled_at: string | null;
  void_reason: string | null;
  total_participants: number;
  total_pool_fet: number;
  winner_count: number | null;
  loser_count: number | null;
  payout_per_winner_fet: number | null;
  official_home_score: number | null;
  official_away_score: number | null;
  created_at: string;
  updated_at: string;
}

/* ── Challenge Entry ── */
export interface ChallengeEntry {
  id: string;
  challenge_id: string;
  user_id: string;
  predicted_home_score: number;
  predicted_away_score: number;
  stake_fet: number;
  status: string;
  payout_fet: number | null;
  joined_at: string;
  settled_at: string | null;
}

/* ── Wallet ── */
export interface Wallet {
  user_id: string;
  available_balance_fet: number;
  locked_balance_fet: number;
  updated_at: string;
  created_at: string;
}

/* ── Wallet Transaction ── */
export interface WalletTransaction {
  id: string;
  user_id: string;
  tx_type: string;
  direction: string;
  amount_fet: number;
  balance_before_fet: number;
  balance_after_fet: number;
  reference_type: string | null;
  reference_id: string | null;
  metadata: Record<string, unknown> | null;
  title: string | null;
  created_at: string;
  display_name?: string;
  flagged?: boolean;
}

/* ── Partner ── */
export interface Partner {
  id: string;
  name: string;
  slug: string | null;
  category: string;
  description: string | null;
  logo_url: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  website_url: string | null;
  country: string;
  market: string;
  status: string;
  is_featured: boolean;
  approved_by: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

/* ── Reward ── */
export interface Reward {
  id: string;
  partner_id: string | null;
  title: string;
  description: string | null;
  category: string | null;
  fet_cost: number;
  original_value: string | null;
  currency: string;
  image_url: string | null;
  inventory_total: number | null;
  inventory_remaining: number | null;
  valid_from: string | null;
  valid_until: string | null;
  country: string;
  market: string;
  is_featured: boolean;
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Redemption ── */
export interface Redemption {
  id: string;
  user_id: string;
  reward_id: string | null;
  partner_id: string | null;
  fet_amount: number;
  status: string;
  redemption_code: string | null;
  admin_notes: string | null;
  reviewed_by: string | null;
  fraud_flag: boolean;
  created_at: string;
  updated_at: string;
}

/* ── Content Banner ── */
export interface ContentBanner {
  id: string;
  title: string;
  subtitle: string | null;
  image_url: string | null;
  action_url: string | null;
  placement: string;
  priority: number;
  country: string;
  is_active: boolean;
  valid_from: string | null;
  valid_until: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Campaign ── */
export interface Campaign {
  id: string;
  title: string;
  message: string;
  type: string;
  segment: Record<string, unknown>;
  status: string;
  scheduled_at: string | null;
  sent_at: string | null;
  recipient_count: number;
  country: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Moderation Report ── */
export interface ModerationReport {
  id: string;
  reporter_user_id: string | null;
  target_type: string;
  target_id: string;
  reason: string;
  description: string | null;
  status: string;
  severity: string;
  assigned_to: string | null;
  resolution_notes: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Feature Flag ── */
export interface FeatureFlag {
  id: string;
  key: string;
  label: string;
  description: string | null;
  is_enabled: boolean;
  market: string;
  module: string | null;
  config: Record<string, unknown>;
  updated_by: string | null;
  created_at: string;
  updated_at: string;
}

/* ── Audit Log ── */
export interface AuditLog {
  id: string;
  admin_user_id: string;
  action: string;
  module: string;
  target_type: string | null;
  target_id: string | null;
  before_state: Record<string, unknown> | null;
  after_state: Record<string, unknown> | null;
  metadata: Record<string, unknown>;
  ip_address: string | null;
  created_at: string;
  // Joined
  admin_name?: string;
  admin_email?: string;
}

/* ── Admin Note ── */
export interface AdminNote {
  id: string;
  admin_user_id: string;
  target_type: string;
  target_id: string;
  content: string;
  created_at: string;
  admin_name?: string;
}

/* ── Generic paginated response ── */
export interface PaginatedResult<T> {
  data: T[];
  count: number;
  page: number;
  pageSize: number;
}

/* ── Dashboard KPI ── */
export interface DashboardKpi {
  label: string;
  value: number;
  trend?: number; // percentage change
  trendDirection?: 'up' | 'down' | 'neutral';
  icon?: string;
}
