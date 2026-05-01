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

export interface MatchPoolCamp {
  id: string;
  poolId: string;
  code: string;
  campKey?: 'home' | 'draw' | 'away' | 'custom' | string;
  label: string;
  resultCode?: string | null;
  teamId?: string | null;
  memberCount: number;
  totalStakedFet: number;
  displayOrder: number;
  isWinningCamp?: boolean;
}

export interface MatchPoolSummary {
  id: string;
  matchId: string;
  scope: 'global' | 'country' | 'venue' | string;
  countryCode?: string | null;
  venueId?: string | null;
  title: string;
  status: string;
  isOfficial: boolean;
  entryFeeFet: number;
  stakeMinFet: number;
  stakeMaxFet: number;
  totalMembers: number;
  totalStakedFet: number;
  creatorRewardFet?: number;
  shareSlug: string;
  shareUrl?: string | null;
  deepLinkUrl?: string | null;
  socialCardUrl?: string | null;
  resultCampId?: string | null;
  lockedAt?: string | null;
  settledAt?: string | null;
  metadata?: Record<string, unknown>;
  camps: MatchPoolCamp[];
  createdAt: string;
  updatedAt: string;
}

export interface MatchPoolEntrySummary {
  entryId: string;
  poolId: string;
  campId: string;
  matchId: string;
  matchLabel: string;
  competitionName?: string | null;
  kickoffAt?: string | null;
  poolTitle: string;
  poolScope: string;
  poolStatus: string;
  campLabel: string;
  stakeAmount: number;
  entryStatus: string;
  payoutFet: number;
  totalMembers: number;
  totalStakedFet: number;
  resultCampId?: string | null;
  shareUrl?: string | null;
  deepLinkUrl?: string | null;
  socialCardUrl?: string | null;
  createdAt: string;
}

export interface ViewerProfile {
  userId: string;
  fanId: string;
  displayName: string;
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
  hoursJson?: Record<string, any>;
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
  addOns?: any[];
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
