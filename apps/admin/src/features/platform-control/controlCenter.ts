export const ROLLOUT_REGIONS = [
  { value: "africa", label: "Africa" },
  { value: "europe", label: "Europe" },
  { value: "uk", label: "UK" },
  { value: "north_america", label: "North America" },
  { value: "world_cup_markets", label: "World Cup markets" },
] as const;

export const SPORTS_BAR_FEATURE_FLAGS = [
  {
    key: "fet_spending",
    label: "FET spending",
    description: "Allow guests to spend FET against venue orders.",
  },
  {
    key: "user_pool_creation",
    label: "User pool creation",
    description: "Allow guests to create shareable match pools.",
  },
  {
    key: "venue_endorsement",
    label: "Venue endorsement",
    description: "Require venues to approve user-created venue pools.",
  },
  {
    key: "country_rollout",
    label: "Country rollout",
    description: "Enable country-gated discovery and pool visibility.",
  },
  {
    key: "competition_rollout",
    label: "Competition rollout",
    description: "Use approved competition visibility controls.",
  },
  {
    key: "social_card_generation",
    label: "Social card generation",
    description: "Allow automatic pool share-card generation.",
  },
  {
    key: "welcome_fet",
    label: "Welcome FET",
    description: "Credit new eligible wallets from active reward rules.",
  },
] as const;

export type SportsBarFeatureFlagKey =
  (typeof SPORTS_BAR_FEATURE_FLAGS)[number]["key"];

export function requireAdminReason(reason: string, action = "admin action") {
  const trimmed = reason.trim();
  if (trimmed.length < 8) {
    throw new Error(`A reason of at least 8 characters is required for ${action}.`);
  }
  return trimmed;
}

export function normalizeCountryIso(value: string) {
  return value.trim().toUpperCase();
}

export function normalizeNullableId(value?: string | null) {
  const trimmed = value?.trim() ?? "";
  return trimmed.length > 0 ? trimmed : null;
}

export interface RewardRuleFormInput {
  id?: string | null;
  scope: "platform" | "country" | "venue";
  countryId?: string | null;
  venueId?: string | null;
  welcomeFetAmount: number;
  orderFetDefaultPercent: number;
  poolCreatorRewardPerMember: number;
  minQualifiedStake: number;
  minQualifiedMembers: number;
  isActive: boolean;
  startsAt?: string | null;
  endsAt?: string | null;
  reason: string;
}

export function buildRewardRuleRpcArgs(input: RewardRuleFormInput) {
  const countryId = normalizeNullableId(input.countryId);
  const venueId = normalizeNullableId(input.venueId);

  if (input.scope === "platform" && (countryId || venueId)) {
    throw new Error("Platform reward rules cannot target a country or venue.");
  }

  if (input.scope === "country" && !countryId) {
    throw new Error("Country reward rules require a country.");
  }

  if (input.scope === "venue" && !venueId) {
    throw new Error("Venue reward rules require a venue.");
  }

  return {
    p_id: normalizeNullableId(input.id),
    p_scope: input.scope,
    p_country_id: input.scope === "country" ? countryId : null,
    p_venue_id: input.scope === "venue" ? venueId : null,
    p_welcome_fet_amount: Math.max(0, Math.trunc(input.welcomeFetAmount || 0)),
    p_order_fet_default_percent: Math.max(0, input.orderFetDefaultPercent || 0),
    p_pool_creator_reward_per_member: Math.max(
      0,
      Math.trunc(input.poolCreatorRewardPerMember || 0),
    ),
    p_min_qualified_stake: Math.max(0, Math.trunc(input.minQualifiedStake || 0)),
    p_min_qualified_members: Math.max(
      0,
      Math.trunc(input.minQualifiedMembers || 0),
    ),
    p_is_active: input.isActive,
    p_starts_at: input.startsAt?.trim() ? new Date(input.startsAt).toISOString() : null,
    p_ends_at: input.endsAt?.trim() ? new Date(input.endsAt).toISOString() : null,
    p_reason: requireAdminReason(input.reason, "reward rule changes"),
  };
}

export interface WalletAdjustmentInput {
  userId: string;
  amount: number;
  direction: "credit" | "debit";
  reason: string;
  idempotencyKey?: string | null;
}

export function buildWalletAdjustmentRpcArgs(input: WalletAdjustmentInput) {
  return {
    p_target_user_id: input.userId,
    p_amount_fet: Math.trunc(input.amount),
    p_direction: input.direction,
    p_reason: requireAdminReason(input.reason, "wallet adjustments"),
    p_idempotency_key: normalizeNullableId(input.idempotencyKey),
  };
}

export function buildCuratedMatchMetadata(tags: {
  global: boolean;
  country: boolean;
  venueRelevant: boolean;
  featured: boolean;
  hidden: boolean;
}) {
  const visibilityTags = [
    tags.global ? "global" : null,
    tags.country ? "country" : null,
    tags.venueRelevant ? "venue_relevant" : null,
    tags.featured ? "featured" : null,
    tags.hidden ? "hidden" : null,
  ].filter(Boolean);

  return {
    tags: visibilityTags,
    visibility: tags.hidden ? "hidden" : tags.global ? "global" : "curated",
    featured: tags.featured,
    hidden: tags.hidden,
  };
}
