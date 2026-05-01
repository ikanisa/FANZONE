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

export interface PredictionEngineOutput {
  id: string;
  matchId: string;
  modelVersion: string;
  homeWinScore: number;
  drawScore: number;
  awayWinScore: number;
  over25Score: number;
  bttsScore: number;
  predictedHomeGoals?: number | null;
  predictedAwayGoals?: number | null;
  confidenceLabel: string;
  generatedAt: string;
}

export interface PredictionConsensus {
  matchId: string;
  totalPredictions: number;
  homePickCount: number;
  drawPickCount: number;
  awayPickCount: number;
  homePct: number;
  drawPct: number;
  awayPct: number;
}

export interface UserPrediction {
  id: string;
  matchId: string;
  predictedResultCode?: string | null;
  predictedOver25?: boolean | null;
  predictedBtts?: boolean | null;
  predictedHomeGoals?: number | null;
  predictedAwayGoals?: number | null;
  pointsAwarded: number;
  rewardStatus: string;
  createdAt: string;
  updatedAt: string;
}

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  predictionCount: number;
  totalPoints: number;
  totalFet: number;
  correctResults: number;
  exactScores: number;
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
export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'cancelled' | 'refunded';
export type VenueUserRole = 'owner' | 'manager' | 'staff';
export type VenueStakeStatus = 'open' | 'settled' | 'cancelled';
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
}

export interface Order {
  id: string;
  venueId: string;
  tableId: string;
  orderCode: string;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  currencyCode: string;
  subtotalAmount: number;
  totalAmount: number;
  paymentFetAmount: number;
  paymentFetConvertedAmount: number;
  createdAt: string;
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

export interface VenueMatchStake {
  id: string;
  venueId: string;
  matchId: string;
  entryFeeFet: number;
  totalPoolFet: number;
  status: VenueStakeStatus;
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
  total_amount: number;
  payment_fet_amount: number;
  payment_fet_converted_amount: number;
  created_at: string;
}

export interface VenueMatchStakeRow {
  [key: string]: unknown;
  id: string;
  venue_id: string;
  match_id: string;
  entry_fee_fet: number;
  total_pool_fet: number;
  status: VenueStakeStatus;
  created_at: string;
}

export interface VenueMatchStakeEntryRow {
  [key: string]: unknown;
  id: string;
  stake_id: string;
  user_id: string;
  created_at: string;
}

export interface MatchRow {
  [key: string]: unknown;
  id: string;
  home_team: string | null;
  away_team: string | null;
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
      venue_match_stakes: TableDefinition<VenueMatchStakeRow>;
      venue_match_stake_entries: TableDefinition<VenueMatchStakeEntryRow>;
      matches: TableDefinition<MatchRow>;
    };
    Views: { [_ in never]: never };
    Functions: {
      join_venue_match_stake: {
        Args: { p_stake_id: string };
        Returns: { success: boolean; stake_id: string; entry_fee_fet: number }[];
      };
      order_update_status: {
        Args: { p_order_id: string; p_status: OrderStatus };
        Returns: boolean;
      };
    };
    Enums: {
      order_status: OrderStatus;
      payment_method: PaymentMethod;
      payment_status: PaymentStatus;
      venue_user_role: VenueUserRole;
      venue_stake_status: VenueStakeStatus;
    };
    CompositeTypes: { [_ in never]: never };
  };
}
