import type {
  Match,
  MatchPoolEntrySummary,
  MatchPoolSummary,
  MenuCategory,
  MenuItem,
  Order,
  OrderItem,
  PaymentMethod,
  Venue,
} from "../types";
import { asNumber, asString, type JsonRecord } from "./apiClient";
import type { WebsitePhonePreset } from "./viewerApi";

function asNumberOrNull(value: unknown): number | null {
  if (value == null) return null;
  const parsed = asNumber(value, Number.NaN);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeStatus(status: unknown): string {
  const value = String(status ?? "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");

  switch (value) {
    case "scheduled":
    case "not_started":
    case "notstarted":
    case "pending":
    case "upcoming":
      return "upcoming";
    case "in_play":
    case "inprogress":
    case "in_progress":
    case "playing":
    case "live":
      return "live";
    case "complete":
    case "completed":
    case "full_time":
    case "ft":
    case "finished":
    case "final":
      return "finished";
    default:
      return value || "upcoming";
  }
}

function formatKickoffLabel(
  dateValue: string,
  kickoffTime?: string | null,
): {
  kickoffLabel: string;
  timeLabel: string;
  dateLabel: string;
} {
  const kickoff = new Date(dateValue);
  const localKickoff = Number.isNaN(kickoff.getTime()) ? null : kickoff;

  const dateLabel = localKickoff
    ? localKickoff.toLocaleDateString(undefined, {
        weekday: "short",
        day: "2-digit",
        month: "short",
      })
    : "TBD";

  const timeLabel =
    kickoffTime?.trim() ||
    (localKickoff
      ? localKickoff.toLocaleTimeString(undefined, {
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        })
      : "--:--");

  return {
    kickoffLabel: timeLabel,
    timeLabel,
    dateLabel,
  };
}

function matchScoreDisplay(
  home?: number | null,
  away?: number | null,
): string | null {
  if (home == null || away == null) return null;
  return `${home} - ${away}`;
}

export function normalizeMatchRow(row: JsonRecord): Match {
  const status = normalizeStatus(row.status ?? row.match_status);
  const ftHomeValue = row.live_home_score ?? row.ft_home ?? row.home_goals;
  const ftAwayValue = row.live_away_score ?? row.ft_away ?? row.away_goals;
  const ftHome = ftHomeValue == null ? null : asNumber(ftHomeValue);
  const ftAway = ftAwayValue == null ? null : asNumber(ftAwayValue);
  const date = asString(row.date ?? row.match_date);
  const liveMinute = row.live_minute == null ? null : asNumber(row.live_minute);
  const baseLabels = formatKickoffLabel(date, asString(row.kickoff_time, ""));

  let kickoffLabel = baseLabels.kickoffLabel;
  let timeLabel = baseLabels.timeLabel;
  if (status === "live") {
    const minuteLabel =
      liveMinute && liveMinute > 0 ? `${liveMinute}'` : "LIVE";
    kickoffLabel = `${minuteLabel} LIVE`;
    timeLabel = minuteLabel;
  } else if (status === "finished") {
    kickoffLabel = "FT";
    timeLabel = "FT";
  }

  const competitionName = asString(row.competition_name);

  return {
    id: asString(row.id),
    competitionId: asString(row.competition_id),
    competitionName,
    competitionLabel: asString(row.competition_name ?? row.competition_id),
    seasonId: asString(row.season_id) || null,
    seasonLabel: asString(row.season_label) || null,
    stage: asString(row.stage) || null,
    round: asString(row.round) || null,
    matchdayOrRound: asString(row.matchday_or_round ?? row.round) || null,
    date,
    startTime: date,
    kickoffTime: asString(row.kickoff_time) || null,
    kickoffLabel,
    dateLabel: baseLabels.dateLabel,
    timeLabel,
    homeTeamId: asString(row.home_team_id) || null,
    awayTeamId: asString(row.away_team_id) || null,
    homeTeam: asString(row.home_team),
    awayTeam: asString(row.away_team),
    homeLogoUrl: asString(row.home_logo_url) || null,
    awayLogoUrl: asString(row.away_logo_url) || null,
    ftHome,
    ftAway,
    score: matchScoreDisplay(ftHome, ftAway),
    liveMinute,
    status,
    resultCode: asString(row.result_code) || null,
    isNeutral: row.is_neutral === true,
    dataSource: asString(row.data_source ?? row.source_name, "manual"),
    notes: asString(row.notes) || null,
    isLive: status === "live",
    isFinished: status === "finished",
    isUpcoming: status === "upcoming",
  };
}

export function normalizeMatchPoolRow(row: JsonRecord): MatchPoolSummary {
  const camps = Array.isArray(row.camps) ? (row.camps as JsonRecord[]) : [];

  return {
    id: asString(row.id),
    matchId: asString(row.match_id),
    scope: asString(row.scope, "venue"),
    countryCode: asString(row.country_code) || null,
    venueId: asString(row.venue_id) || null,
    title: asString(row.title, "Match pool"),
    status: asString(row.status, "open"),
    isOfficial: row.is_official === true,
    entryFeeFet: asNumber(row.entry_fee_fet),
    stakeMinFet: asNumber(row.stake_min_fet),
    stakeMaxFet: asNumber(row.stake_max_fet),
    totalMembers: asNumber(row.total_members),
    totalStakedFet: asNumber(row.total_staked_fet),
    creatorRewardFet: asNumber(row.creator_reward_fet),
    shareSlug: asString(row.share_slug),
    shareUrl: asString(row.share_url) || null,
    deepLinkUrl: asString(row.deep_link_url) || null,
    socialCardUrl: asString(row.social_card_url) || null,
    resultCampId: asString(row.result_camp_id) || null,
    lockedAt: asString(row.locked_at) || null,
    settledAt: asString(row.settled_at) || null,
    metadata:
      row.metadata &&
      typeof row.metadata === "object" &&
      !Array.isArray(row.metadata)
        ? (row.metadata as Record<string, unknown>)
        : {},
    camps: camps.map((camp) => ({
      id: asString(camp.id),
      poolId: asString(row.id),
      code: asString(camp.code),
      campKey: asString(camp.camp_key ?? camp.code),
      label: asString(camp.label),
      resultCode: asString(camp.result_code) || null,
      teamId: asString(camp.team_id) || null,
      memberCount: asNumber(camp.member_count),
      totalStakedFet: asNumber(camp.total_staked_fet),
      isWinningCamp: camp.is_winning_camp === true,
      displayOrder: asNumber(camp.display_order),
    })),
    createdAt: asString(row.created_at),
    updatedAt: asString(row.updated_at),
  };
}

export function normalizePoolEntryRow(row: JsonRecord): MatchPoolEntrySummary {
  return {
    entryId: asString(row.entry_id),
    poolId: asString(row.pool_id),
    campId: asString(row.camp_id),
    matchId: asString(row.match_id),
    matchLabel: asString(row.match_label, "Match"),
    competitionName: asString(row.competition_name) || null,
    kickoffAt: asString(row.kickoff_at) || null,
    poolTitle: asString(row.pool_title, "Match pool"),
    poolScope: asString(row.pool_scope, "venue"),
    poolStatus: asString(row.pool_status, "open"),
    campLabel: asString(row.camp_label, "Camp"),
    stakeAmount: asNumber(row.stake_amount),
    entryStatus: asString(row.entry_status, "active"),
    payoutFet: asNumber(row.payout_fet),
    totalMembers: asNumber(row.total_members),
    totalStakedFet: asNumber(row.total_staked_fet),
    resultCampId: asString(row.result_camp_id) || null,
    shareUrl: asString(row.share_url) || null,
    deepLinkUrl: asString(row.deep_link_url) || null,
    socialCardUrl: asString(row.social_card_url) || null,
    createdAt: asString(row.created_at),
  };
}

export function normalizePhonePresetRow(row: JsonRecord): WebsitePhonePreset {
  return {
    countryCode: asString(row.country_code) || null,
    dialCode: asString(row.dial_code, "+"),
    hint: asString(row.hint, "000 000 000"),
    minDigits: asNumber(row.min_digits, 7),
  };
}

export function mapVenueRow(row: JsonRecord): Venue {
  return {
    id: asString(row.id),
    name: asString(row.name),
    slug: asString(row.slug),
    description: asString(row.description) || null,
    address: asString(row.address_line1) || null,
    country: asString(row.country_code),
    logoUrl: asString(row.logo_url) || null,
    coverUrl: asString(row.cover_url) || null,
    isOpen: row.is_open === true,
    hoursJson:
      row.hours_json &&
      typeof row.hours_json === "object" &&
      !Array.isArray(row.hours_json)
        ? (row.hours_json as Record<string, unknown>)
        : undefined,
    revolutLink: asString(row.revolut_link) || null,
    momoCode: asString(row.momo_code) || null,
    whatsapp: asString(row.whatsapp) || null,
    primaryCategory: asString(row.primary_category) || null,
    rating: asNumberOrNull(row.rating),
    priceLevel: asNumberOrNull(row.price_level),
  };
}

export function mapMenuCategoryRow(row: JsonRecord): MenuCategory {
  return {
    id: asString(row.id),
    venueId: asString(row.venue_id),
    name: asString(row.name),
    displayOrder: asNumber(row.display_order),
  };
}

export function mapMenuItemRow(row: JsonRecord): MenuItem {
  return {
    id: asString(row.id),
    venueId: asString(row.venue_id),
    categoryId: asString(row.category_id),
    name: asString(row.name),
    description: asString(row.description) || null,
    price: asNumber(row.price),
    currencyCode: asString(row.currency_code),
    imageUrl: asString(row.image_url) || null,
    isAvailable: row.is_available === true,
    isFeatured: row.is_featured === true,
    displayOrder: asNumber(row.display_order),
    addOns: Array.isArray(row.add_ons) ? row.add_ons : undefined,
    dietaryFlags:
      row.dietary_flags &&
      typeof row.dietary_flags === "object" &&
      !Array.isArray(row.dietary_flags)
        ? (row.dietary_flags as Record<string, boolean>)
        : undefined,
  };
}

export function mapOrderRow(
  row: JsonRecord & { items?: JsonRecord[] },
  fallbackPaymentMethod: PaymentMethod,
): Order {
  const items: OrderItem[] = (row.items || []).map((item) => ({
    id: asString(item.id),
    orderId: asString(item.order_id),
    itemNameSnapshot: asString(item.item_name_snapshot),
    quantity: asNumber(item.quantity),
    unitPrice: asNumber(item.unit_price),
    lineTotal: asNumber(item.line_total),
  }));

  return {
    id: asString(row.id),
    venueId: asString(row.venue_id),
    tableId: asString(row.table_id),
    orderCode: asString(row.order_code),
    status: asString(row.status, "placed") as Order["status"],
    paymentMethod: asString(
      row.payment_method,
      fallbackPaymentMethod,
    ) as PaymentMethod,
    paymentStatus: asString(
      row.payment_status,
      "pending",
    ) as Order["paymentStatus"],
    currencyCode: asString(row.currency_code),
    subtotalAmount: asNumber(row.subtotal_amount),
    totalAmount: asNumber(row.total_amount),
    paymentFetAmount: asNumber(row.payment_fet_amount),
    paymentFetConvertedAmount: asNumber(row.payment_fet_converted_amount),
    createdAt: asString(row.created_at),
    items,
  };
}
