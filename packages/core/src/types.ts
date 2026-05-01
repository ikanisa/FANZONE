export type MatchStatus = 'upcoming' | 'live' | 'finished' | string;

export interface User {
  id: string;
  name: string;
  phone: string;
  isVerified: boolean;
}

export interface Match {
  id: string;
  competitionId: string;
  competitionName: string;
  competitionLabel: string;
  seasonId?: string | null;
  seasonLabel?: string | null;
  stage?: string | null;
  round?: string | null;
  matchdayOrRound?: string | null;
  date: string;
  startTime?: string;
  kickoffTime?: string | null;
  kickoffLabel: string;
  dateLabel: string;
  timeLabel: string;
  homeTeamId?: string | null;
  awayTeamId?: string | null;
  homeTeam: string;
  awayTeam: string;
  homeLogoUrl?: string | null;
  awayLogoUrl?: string | null;
  ftHome?: number | null;
  ftAway?: number | null;
  score?: string | null;
  liveMinute?: number | null;
  status: MatchStatus;
  resultCode?: string | null;
  isNeutral: boolean;
  dataSource: string;
  notes?: string | null;
  isLive: boolean;
  isFinished: boolean;
  isUpcoming: boolean;
}

export interface Competition {
  id: string;
  name: string;
  shortName: string;
  country: string;
  tier: number;
  competitionType?: string | null;
  isFeatured: boolean;
  isInternational: boolean;
  isActive: boolean;
  currentSeasonId?: string | null;
  currentSeasonLabel?: string | null;
  futureMatchCount: number;
  catalogRank?: number | null;
}

export interface Team {
  id: string;
  name: string;
  shortName: string;
  slug: string;
  country?: string | null;
  countryCode?: string | null;
  teamType: string;
  description?: string | null;
  leagueName?: string | null;
  region?: string | null;
  competitionIds: string[];
  aliases: string[];
  searchTerms: string[];
  logoUrl?: string | null;
  crestUrl?: string | null;
  coverImageUrl?: string | null;
  isActive: boolean;
  isFeatured: boolean;
  isPopularPick: boolean;
  popularPickRank?: number | null;
  fanCount: number;
}

export interface StandingRow {
  id: string;
  competitionId: string;
  seasonId: string;
  season: string;
  snapshotType: string;
  snapshotDate: string;
  teamId: string;
  teamName: string;
  position: number;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDifference: number;
  points: number;
}

export interface TeamFormFeature {
  matchId: string;
  teamId: string;
  last5Points: number;
  last5Wins: number;
  last5Draws: number;
  last5Losses: number;
  last5GoalsFor: number;
  last5GoalsAgainst: number;
  last5CleanSheets: number;
  last5FailedToScore: number;
  homeFormLast5: number;
  awayFormLast5: number;
  over25Last5: number;
  bttsLast5: number;
}

export interface ViewerProfile {
  userId: string;
  fanId: string;
  displayName: string;
  favoriteTeamId?: string | null;
  favoriteTeamName?: string | null;
  onboardingCompleted: boolean;
  isAnonymous: boolean;
  authMethod: string;
}

export interface ViewerWallet {
  availableBalanceFet: number;
  lockedBalanceFet: number;
  fanId?: string | null;
  displayName?: string | null;
}

export interface ViewerNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  sentAt: string;
  readAt?: string | null;
}

export type OrderStatus = 'placed' | 'received' | 'served' | 'cancelled';
export type PaymentMethod = 'momo' | 'revolut' | 'cash';
export type PaymentStatus = 'unpaid' | 'paid' | 'partially_paid' | 'refunded' | 'disputed' | 'pending' | 'failed' | 'cancelled';
export type VenueUserRole = 'owner' | 'manager' | 'staff';
export type MatchPoolScope = 'global' | 'country' | 'venue';
export type MatchPoolStatus = 'draft' | 'open' | 'locked' | 'live' | 'settling' | 'settled' | 'cancelled';
export type MatchPoolEntryStatus = 'active' | 'cancelled' | 'won' | 'lost' | 'refunded';
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Venue {
  id: string;
  name: string;
  slug: string;
  description?: string | null;
  address?: string | null;
  country: string;
  logoUrl?: string | null;
  coverUrl?: string | null;
  isOpen: boolean;
  hoursJson?: Record<string, Json>;
  revolutLink?: string | null;
  momoCode?: string | null;
  whatsapp?: string | null;
  primaryCategory?: string | null;
  rating?: number | null;
  priceLevel?: number | null;
}

export interface MenuCategory {
  id: string;
  venueId: string;
  name: string;
  displayOrder: number;
}

export interface MenuItem {
  id: string;
  venueId: string;
  categoryId: string;
  name: string;
  description?: string | null;
  price: number;
  currencyCode: string;
  imageUrl?: string | null;
  isAvailable: boolean;
  isFeatured: boolean;
  displayOrder: number;
  addOns?: Json[];
  dietaryFlags?: Record<string, boolean>;
  fetEarnPercentOverride?: number | null;
}

export interface Order {
  id: string;
  venueId: string;
  tableId: string;
  tableNumber?: string | null;
  orderCode: string;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  currencyCode: string;
  subtotalAmount: number;
  taxAmount?: number;
  tipAmount?: number;
  totalAmount: number;
  paymentFetAmount: number;
  paymentFetConvertedAmount: number;
  fetEarned: number;
  fetSpent: number;
  specialInstructions?: string | null;
  acceptedAt?: string | null;
  servedAt?: string | null;
  statusChangedAt?: string | null;
  createdAt: string;
  updatedAt?: string;
  items?: OrderItem[];
}

export interface OrderItem {
  id: string;
  orderId: string;
  itemNameSnapshot: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
}

export interface MatchPoolCamp {
  id: string;
  poolId: string;
  code: string;
  label: string;
  resultCode?: string | null;
  memberCount: number;
  totalStakedFet: number;
  displayOrder: number;
  isWinningCamp?: boolean;
}

export interface MatchPool {
  id: string;
  matchId: string;
  scope: MatchPoolScope;
  countryCode?: string | null;
  venueId?: string | null;
  creatorUserId?: string | null;
  title: string;
  status: MatchPoolStatus;
  isOfficial: boolean;
  entryFeeFet: number;
  stakeMinFet: number;
  stakeMaxFet: number;
  totalMembers: number;
  totalStakedFet: number;
  creatorRewardFet?: number;
  rulesJson?: Json;
  shareUrl?: string | null;
  socialCardUrl?: string | null;
  camps: MatchPoolCamp[];
  lockedAt?: string | null;
  settledAt?: string | null;
  metadata?: Json;
  createdAt: string;
}

export interface HospitalityAuditStats {
  totalOrders: number;
  totalRevenueEur: number;
  totalFetRedeemed: number;
  totalStakesCreated: number;
  totalStakedFet: number;
  activeVenuesCount: number;
}

export interface VenuePerformance {
  venueId: string;
  venueName: string;
  orderCount: number;
  revenueEur: number;
  fetRedeemed: number;
  stakeCount: number;
  participantCount: number;
}

export interface VenueMember {
  id: string;
  venueId: string;
  userId: string;
  role: VenueUserRole;
  isActive: boolean;
}

export interface VenueRow {
  [key: string]: unknown;
  id: string;
  name: string;
  slug: string;
  description: string | null;
  address_line1: string | null;
  country_code: string;
  logo_url: string | null;
  cover_url: string | null;
  is_open: boolean;
  hours_json: Json | null;
  revolut_link: string | null;
  momo_code: string | null;
  whatsapp: string | null;
  primary_category: string | null;
  rating: number | null;
  price_level: number | null;
}

export interface VenueUserRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  user_id: string;
  role: VenueUserRole;
  is_active: boolean;
}

export interface OrderItemRow {
  [key: string]: unknown;
  id: string;
  order_id: string;
  item_name_snapshot: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  currency_code: string;
}

export interface MenuCategoryRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  name: string;
  display_order: number;
  is_visible: boolean;
}

export interface MenuItemRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  category_id: string;
  name: string;
  description: string | null;
  price: number;
  currency_code: string;
  image_url: string | null;
  is_available: boolean;
  is_featured: boolean;
  display_order: number;
  add_ons: Json[] | null;
  dietary_flags: Record<string, boolean> | null;
  metadata?: Json;
  fet_earn_percent_override?: number | null;
}

export interface OrderRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  table_id: string;
  order_code: string;
  status: OrderStatus;
  payment_method: PaymentMethod;
  payment_status: PaymentStatus;
  currency_code: string;
  subtotal_amount: number;
  tax_amount?: number;
  tip_amount?: number;
  total_amount: number;
  special_instructions?: string | null;
  estimated_ready_at?: string | null;
  accepted_at?: string | null;
  served_at?: string | null;
  status_changed_at?: string;
  payment_fet_amount: number;
  payment_fet_converted_amount: number;
  fet_earned?: number;
  fet_spent?: number;
  created_at: string;
  updated_at?: string;
}

export interface VenueTableRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  table_number: string;
  qr_token?: string | null;
  qr_url?: string | null;
  qr_code_url?: string | null;
  deep_link_uri?: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface MatchPoolRow {
  [key: string]: unknown;
  id: string;
  match_id: string;
  scope: MatchPoolScope;
  country_code: string | null;
  venue_id: string | null;
  creator_user_id: string | null;
  title: string;
  status: MatchPoolStatus;
  is_official: boolean;
  entry_fee_fet: number;
  stake_min_fet: number;
  stake_max_fet: number;
  min_participants: number;
  total_members: number;
  total_staked_fet: number;
  creator_reward_fet: number;
  creator_reward_rules: Json;
  rules_json: Json;
  platform_fee_bps: number;
  venue_fee_bps: number;
  share_slug: string;
  share_url: string | null;
  social_card_url: string | null;
  result_camp_id: string | null;
  locked_at: string | null;
  settled_at: string | null;
  metadata: Json;
  created_at: string;
  updated_at: string;
}

export interface MatchPoolCampRow {
  [key: string]: unknown;
  id: string;
  pool_id: string;
  code: string;
  label: string;
  result_code: string | null;
  display_order: number;
  member_count: number;
  total_staked_fet: number;
  is_winning_camp?: boolean;
  created_at: string;
}

export interface MatchPoolEntryRow {
  [key: string]: unknown;
  id: string;
  pool_id: string;
  camp_id: string;
  user_id: string;
  amount_fet: number;
  status: MatchPoolEntryStatus;
  payout_fet: number;
  metadata: Json;
  created_at: string;
  updated_at: string;
}

export interface MatchPoolSettlementRow {
  [key: string]: unknown;
  id: string;
  pool_id: string;
  status: 'running' | 'completed' | 'failed';
  result_camp_id: string | null;
  winners_count: number;
  losing_stake_fet: number;
  total_paid_fet: number;
  payout_per_winner_fet: number;
  idempotency_key: string;
  started_at: string;
  completed_at: string | null;
  metadata: Json;
}

export interface MatchPoolStatsRow extends MatchPoolRow {
  camps: Json;
}

export interface PoolOperationAuditLogRow {
  [key: string]: unknown;
  id: string;
  actor_user_id: string | null;
  action: string;
  pool_id: string | null;
  venue_id: string | null;
  match_id: string | null;
  before_state: Json | null;
  after_state: Json | null;
  metadata: Json;
  created_at: string;
}

export interface CuratedMatchRow {
  [key: string]: unknown;
  id: string;
  match_id: string;
  country_code: string | null;
  venue_id: string | null;
  priority_score: number;
  is_active: boolean;
  reason: string;
  curated_by: string | null;
  starts_at: string | null;
  expires_at: string | null;
  metadata: Json;
  created_at: string;
  updated_at: string;
}

export interface VenuePoolMatchOptionRow {
  [key: string]: unknown;
  match_id: string;
  match_label: string;
  competition_name: string | null;
  kickoff_at: string | null;
  match_status: string | null;
  country_code: string | null;
  venue_id: string | null;
  curation_reason: string | null;
  priority_score: number;
  official_pool_id: string | null;
}

export interface PoolOperationsQueueRow {
  [key: string]: unknown;
  pool_id: string;
  title: string;
  scope: string;
  venue_id: string | null;
  venue_name: string | null;
  match_id: string;
  match_label: string;
  competition_name: string | null;
  kickoff_at: string | null;
  match_status: string | null;
  result_code: string | null;
  pool_status: string;
  total_members: number;
  total_staked_fet: number;
  settlement_status: string | null;
  settlement_started_at: string | null;
  settlement_completed_at: string | null;
  settlement_error: string | null;
  share_url: string | null;
  social_card_url: string | null;
  needs_settlement: boolean;
  needs_social_card: boolean;
  age_minutes: number;
}

export interface MatchRow {
  [key: string]: unknown;
  id: string;
  competition_id?: string;
  home_team_id?: string | null;
  away_team_id?: string | null;
  match_date?: string;
  match_status?: string;
  result_code?: string | null;
}

export interface AppMatchRow {
  [key: string]: unknown;
  id: string;
  competition_id: string;
  competition_name: string | null;
  match_date: string;
  home_team: string | null;
  away_team: string | null;
  home_logo_url?: string | null;
  away_logo_url?: string | null;
  result_code?: string | null;
  status: string;
  match_status: string;
}

export interface VenueOperationalInsights {
  today_orders: number;
  fet_issued: number;
  fet_redeemed: number;
  active_pools: number;
  most_active_match: {
    pool_id: string;
    match_id: string;
    title: string;
    competition_name: string | null;
    match_label: string;
    status: MatchPoolStatus;
    total_members: number;
    total_staked_fet: number;
  } | null;
  top_menu_items: Array<{
    name: string;
    quantity: number;
    revenue: number;
  }>;
  pending_payment_count: number;
}

type TableDefinition<Row extends Record<string, unknown>> = {
  Row: Row;
  Insert: Record<string, unknown>;
  Update: Record<string, unknown>;
  Relationships: [];
};

export interface Database {
  public: {
    Tables: {
      venues: TableDefinition<VenueRow>;
      venue_users: TableDefinition<VenueUserRow>;
      menu_categories: TableDefinition<MenuCategoryRow>;
      menu_items: TableDefinition<MenuItemRow>;
      orders: TableDefinition<OrderRow>;
      order_items: TableDefinition<OrderItemRow>;
      tables: TableDefinition<VenueTableRow>;
      match_pools: TableDefinition<MatchPoolRow>;
      match_pool_camps: TableDefinition<MatchPoolCampRow>;
      match_pool_entries: TableDefinition<MatchPoolEntryRow>;
      match_pool_settlements: TableDefinition<MatchPoolSettlementRow>;
      pool_operation_audit_logs: TableDefinition<PoolOperationAuditLogRow>;
      curated_matches: TableDefinition<CuratedMatchRow>;
      matches: TableDefinition<MatchRow>;
    };
    Views: {
      app_matches: TableDefinition<AppMatchRow>;
      match_pool_stats: TableDefinition<MatchPoolStatsRow>;
      venue_tables: TableDefinition<VenueTableRow>;
    };
    Functions: {
      create_match_pool: {
        Args: {
          p_match_id: string;
          p_scope?: MatchPoolScope;
          p_country_code?: string | null;
          p_venue_id?: string | null;
          p_title?: string | null;
          p_entry_fee_fet?: number;
          p_stake_min_fet?: number;
          p_stake_max_fet?: number;
          p_is_official?: boolean;
        };
        Returns: Json;
      };
      join_match_pool: {
        Args: {
          p_pool_id: string;
          p_camp_id: string;
          p_amount_fet?: number | null;
          p_invite_code?: string | null;
        };
        Returns: Json;
      };
      create_venue_official_match_pool: {
        Args: {
          p_venue_id: string;
          p_match_id: string;
          p_title?: string | null;
          p_entry_fee_fet?: number;
          p_stake_min_fet?: number;
          p_stake_max_fet?: number;
          p_creator_reward_fet?: number;
        };
        Returns: Json;
      };
      venue_pool_match_options: {
        Args: { p_venue_id: string; p_limit?: number };
        Returns: VenuePoolMatchOptionRow[];
      };
      venue_endorse_pool: {
        Args: { p_pool_id: string; p_venue_id: string };
        Returns: Json;
      };
      venue_reject_pool: {
        Args: { p_pool_id: string; p_venue_id: string; p_reason?: string | null };
        Returns: Json;
      };
      admin_pool_operations_kpis: {
        Args: Record<string, never>;
        Returns: Json;
      };
      admin_pool_operations_queue: {
        Args: { p_limit?: number };
        Returns: PoolOperationsQueueRow[];
      };
      admin_run_pool_settlement: {
        Args: { p_limit?: number };
        Returns: Json;
      };
      order_update_status: {
        Args: { p_order_id: string; p_status: OrderStatus };
        Returns: boolean;
      };
      venue_update_order_payment_status: {
        Args: {
          p_order_id: string;
          p_payment_status: PaymentStatus;
          p_payment_method?: PaymentMethod | null;
          p_actor_note?: string | null;
        };
        Returns: Json;
      };
      manual_mark_order_paid: {
        Args: {
          p_order_id: string;
          p_payment_method?: PaymentMethod | null;
          p_actor_note?: string | null;
        };
        Returns: Json;
      };
      get_venue_fet_reward_config: {
        Args: { p_venue_id: string };
        Returns: Json;
      };
      update_venue_fet_reward_config: {
        Args: {
          p_venue_id: string;
          p_reward_percent?: number | null;
          p_reward_trigger?: 'paid' | 'served' | null;
          p_accepts_fet_spend?: boolean | null;
          p_redemption_fet_per_currency?: number | null;
          p_max_fet_spend_per_order?: number | null;
          p_reward_campaign_active?: boolean | null;
        };
        Returns: Json;
      };
      get_venue_fet_reward_summary: {
        Args: { p_venue_id: string };
        Returns: Json;
      };
      get_venue_operational_insights: {
        Args: { p_venue_id: string };
        Returns: Json;
      };
      generate_table_qr: {
        Args: {
          p_venue_id: string;
          p_table_number: string;
          p_base_url?: string;
        };
        Returns: Json;
      };
    };
    Enums: {
      order_status: OrderStatus;
      payment_method: PaymentMethod;
      payment_status: PaymentStatus;
      venue_user_role: VenueUserRole;
      match_pool_scope: MatchPoolScope;
      match_pool_status: MatchPoolStatus;
      match_pool_entry_status: MatchPoolEntryStatus;
    };
    CompositeTypes: { [_ in never]: never };
  };
}
