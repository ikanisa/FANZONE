import type {
  Match,
  MatchPoolEntrySummary,
  MatchPoolSummary,
  Order,
  OrderItem,
  PaymentMethod,
  ViewerProfile,
  ViewerWallet,
} from "../types";
import { assertClientFeatureAvailable } from "../platform/access";
import { normalizePlatformBootstrap } from "../platform/normalize";
import type { PlatformBootstrap } from "../platform/types";
import {
  ensureWebsiteSession,
  isSupabaseConfigured,
  supabase,
} from "../lib/supabase";

type JsonRecord = Record<string, unknown>;

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

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number") return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return fallback;
}

function asString(value: unknown, fallback = ""): string {
  if (typeof value === "string") return value;
  if (value == null) return fallback;
  return String(value);
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

function normalizeMatchRow(row: JsonRecord): Match {
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

function normalizeMatchPoolRow(row: JsonRecord): MatchPoolSummary {
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

function normalizePoolEntryRow(row: JsonRecord): MatchPoolEntrySummary {
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

function relativeDateLabel(timestamp: string): string {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return "Just now";
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return "Just now";
}

async function ensureClient() {
  if (!isSupabaseConfigured || !supabase) return null;
  await ensureWebsiteSession();
  return supabase;
}

async function maybeSingle<T>(
  promise: PromiseLike<{ data: T | null; error: { message: string } | null }>,
) {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data;
}

async function selectList<T>(
  promise: PromiseLike<{ data: T[] | null; error: { message: string } | null }>,
) {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data ?? [];
}

export interface ViewerState {
  profile: ViewerProfile | null;
  wallet: ViewerWallet | null;
  walletTransactions: {
    id: string;
    title: string;
    amount: number;
    type: "earn" | "spend" | "transfer_sent" | "transfer_received";
    timestamp: number;
    dateStr: string;
  }[];
  notifications: {
    id: string;
    type: string;
    title: string;
    message: string;
    timestamp: number;
    read: boolean;
    data: Record<string, unknown>;
  }[];
}

export interface WebsitePhonePreset {
  countryCode: string | null;
  dialCode: string;
  hint: string;
  minDigits: number;
}

export interface CurrencyDisplayPreference {
  code: string;
  symbol: string;
  decimals: number;
  spaceSeparated: boolean;
  rate: number;
  fetPerEur: number | null;
}

function resolveBrowserCountryCode(): string | null {
  if (typeof navigator === "undefined") return null;

  const locales = [
    navigator.language,
    ...(Array.isArray(navigator.languages) ? navigator.languages : []),
  ];

  for (const locale of locales) {
    const match = locale?.match(/[-_]([a-z]{2})$/i);
    if (match?.[1]) return match[1].toUpperCase();
  }

  return null;
}

function normalizePhonePresetRow(row: JsonRecord): WebsitePhonePreset {
  return {
    countryCode: asString(row.country_code) || null,
    dialCode: asString(row.dial_code, "+"),
    hint: asString(row.hint, "000 000 000"),
    minDigits: asNumber(row.min_digits, 7),
  };
}

export const api = {
  isConfigured: isSupabaseConfigured,

  async getPlatformBootstrap(): Promise<PlatformBootstrap> {
    const client = await ensureClient();
    if (!client) {
      throw new Error("Supabase is not configured for the website.");
    }

    const { data, error } = await client.rpc("get_app_bootstrap_config", {
      p_market: "global",
      p_platform: "web",
    });

    if (error) {
      throw new Error(error.message);
    }

    return normalizePlatformBootstrap(data);
  },

  async getLiveMatches(limit = 12): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("curated_active_matches")
          .select("*")
          .eq("status", "live")
          .order("date", { ascending: true })
          .limit(limit),
      );
      return rows.map(normalizeMatchRow);
    } catch (error) {
      console.warn("Failed to load live matches", error);
      return [];
    }
  },

  async getUpcomingMatches(limit = 12): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("curated_active_matches")
          .select("*")
          .in("status", ["scheduled", "upcoming"])
          .gte("date", new Date().toISOString())
          .order("date", { ascending: true })
          .limit(limit),
      );
      return rows.map(normalizeMatchRow);
    } catch (error) {
      console.warn("Failed to load upcoming matches", error);
      return [];
    }
  },

  async getMatchDetail(matchId: string): Promise<Match | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const row = await maybeSingle<JsonRecord>(
        client
          .from("curated_active_matches")
          .select("*")
          .eq("id", matchId)
          .maybeSingle(),
      );
      return row ? normalizeMatchRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load match ${matchId}`, error);
      return null;
    }
  },

  async getOpenMatchPools(limit = 20): Promise<MatchPoolSummary[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("match_pool_stats")
          .select("*")
          .in("status", ["open", "locked", "live", "settling"])
          .order("created_at", { ascending: false })
          .limit(limit),
      );
      return rows.map(normalizeMatchPoolRow);
    } catch (error) {
      console.warn("Failed to load match pools", error);
      return [];
    }
  },

  async getMatchPools(matchId: string): Promise<MatchPoolSummary[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("match_pool_stats")
          .select("*")
          .eq("match_id", matchId)
          .in("status", ["open", "locked", "live", "settling", "settled"])
          .order("scope", { ascending: true })
          .order("created_at", { ascending: false }),
      );
      return rows.map(normalizeMatchPoolRow);
    } catch (error) {
      console.warn(`Failed to load pools for ${matchId}`, error);
      return [];
    }
  },

  async getMatchPoolBySlug(
    slug: string,
    inviteCode?: string | null,
    source: "direct" | "venue_qr" | "social_share" | "invite_link" = "direct",
  ): Promise<MatchPoolSummary | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const { data: shareData, error: shareError } = await client.rpc(
        "get_public_pool_share",
        {
          p_slug_or_pool_id: slug,
          p_invite_code: inviteCode ?? null,
          p_source: inviteCode ? "invite_link" : source,
        },
      );
      if (shareError) throw new Error(shareError.message);
      const resolvedPoolId = asString(
        ((shareData ?? {}) as { pool?: { id?: unknown } }).pool?.id,
      );
      if (!resolvedPoolId) return null;

      const row = await maybeSingle<JsonRecord>(
        client
          .from("match_pool_stats")
          .select("*")
          .eq("id", resolvedPoolId)
          .maybeSingle(),
      );
      return row ? normalizeMatchPoolRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load pool ${slug}`, error);
      return null;
    }
  },

  async getPoolMatches(limit = 16): Promise<Match[]> {
    const [live, upcoming] = await Promise.all([
      api.getLiveMatches(Math.ceil(limit / 2)),
      api.getUpcomingMatches(limit),
    ]);
    const seen = new Set<string>();
    return [...live, ...upcoming]
      .filter((match) => {
        if (seen.has(match.id)) return false;
        seen.add(match.id);
        return true;
      })
      .slice(0, limit);
  },

  async getMyPools(limit = 50): Promise<MatchPoolEntrySummary[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const { data, error } = await client.rpc("get_my_pools", {
        p_limit: limit,
      });
      if (error) throw new Error(error.message);
      return ((data ?? []) as JsonRecord[]).map(normalizePoolEntryRow);
    } catch (error) {
      console.warn("Failed to load my pools", error);
      return [];
    }
  },

  async createPool(input: {
    matchId: string;
    scope: "global" | "country" | "venue";
    title: string;
    stakeMinFet: number;
    stakeMaxFet: number;
    venueId?: string | null;
    visibility?: "shareable" | "private" | "public";
  }): Promise<{
    success: boolean;
    poolId?: string;
    shareUrl?: string | null;
    status?: string;
    endorsementStatus?: string | null;
    socialCardUrl?: string | null;
    error?: string;
  }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      assertClientFeatureAvailable(
        "pools",
        "Match pools are currently unavailable.",
      );

      if (input.scope !== "venue" || !input.venueId) {
        return {
          success: false,
          error: "Choose the linked venue before creating a pool.",
        };
      }

      const { data, error } = await client.rpc("create_pool", {
        p_match_id: input.matchId,
        p_scope: "venue",
        p_country_id: null,
        p_venue_id: input.venueId,
        p_title: input.title.trim() || null,
        p_stake_min: input.stakeMinFet,
        p_stake_max: input.stakeMaxFet,
        p_creator_reward_per_qualified_member: 1,
        p_rules_json: {
          visibility: input.visibility ?? "shareable",
          is_official: false,
        },
        p_allow_multiple: false,
      });

      if (error) throw new Error(error.message);
      const row = (data ?? {}) as JsonRecord;
      const poolId = asString(row.pool_id);
      let socialCardUrl: string | null = null;

      if (poolId) {
        try {
          const generated = await api.generatePoolShareCard(poolId);
          socialCardUrl = generated.socialCardUrl ?? null;
        } catch (cardError) {
          console.warn(
            "Pool created but social card generation failed",
            cardError,
          );
        }
      }

      return {
        success: true,
        poolId,
        shareUrl: asString(row.share_url) || null,
        status: asString(row.status, "created"),
        endorsementStatus: asString(row.endorsement_status) || null,
        socialCardUrl,
      };
    } catch (error) {
      return {
        success: false,
        error:
          error instanceof Error ? error.message : "Could not create pool.",
      };
    }
  },

  async generatePoolShareCard(poolId: string): Promise<{
    success: boolean;
    socialCardUrl?: string | null;
    error?: string;
  }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      const { data, error } = await client.functions.invoke(
        "generate-pool-social-card",
        { body: { pool_id: poolId } },
      );
      if (error) throw new Error(error.message);
      const row = (data ?? {}) as JsonRecord;
      return {
        success: true,
        socialCardUrl:
          asString(row.social_card_url) || asString(row.socialCardUrl) || null,
      };
    } catch (error) {
      return {
        success: false,
        error:
          error instanceof Error
            ? error.message
            : "Could not generate social card.",
      };
    }
  },

  async createPoolInvite(poolId: string): Promise<{
    success: boolean;
    inviteCode?: string | null;
    shareUrl?: string | null;
    deepLinkUrl?: string | null;
    error?: string;
  }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      const { data, error } = await client.rpc("create_match_pool_invite", {
        p_pool_id: poolId,
      });
      if (error) throw new Error(error.message);
      const row = (data ?? {}) as JsonRecord;
      return {
        success: true,
        inviteCode: asString(row.invite_code) || null,
        shareUrl: asString(row.share_url) || null,
        deepLinkUrl: asString(row.deep_link_url) || null,
      };
    } catch (error) {
      return {
        success: false,
        error:
          error instanceof Error
            ? error.message
            : "Could not create pool invite.",
      };
    }
  },

  async getViewerState(): Promise<ViewerState | null> {
    const client = await ensureClient();
    if (!client) return null;

    const userId = await ensureWebsiteSession();
    if (!userId) return null;

    try {
      const [profileRow, walletRow, txRows, notificationRows] =
        await Promise.all([
          maybeSingle<JsonRecord>(
            client
              .from("profiles")
              .select(
                "user_id,fan_id,display_name,onboarding_completed,is_anonymous,auth_method",
              )
              .eq("user_id", userId)
              .maybeSingle(),
          ),
          maybeSingle<JsonRecord>(
            client
              .from("wallet_overview")
              .select("*")
              .eq("user_id", userId)
              .maybeSingle(),
          ),
          selectList<JsonRecord>(
            client
              .from("fet_wallet_transactions")
              .select("id,tx_type,direction,amount_fet,title,created_at")
              .order("created_at", { ascending: false })
              .limit(12),
          ),
          selectList<JsonRecord>(
            client
              .from("notification_log")
              .select("id,type,title,body,data,sent_at,read_at")
              .order("sent_at", { ascending: false })
              .limit(20),
          ),
        ]);

      const profile: ViewerProfile | null = profileRow
        ? {
            userId: asString(profileRow.user_id),
            fanId: asString(profileRow.fan_id, "------"),
            displayName:
              asString(profileRow.display_name) ||
              `Fan #${asString(profileRow.fan_id, "------")}`,
            onboardingCompleted: profileRow.onboarding_completed === true,
            isAnonymous: profileRow.is_anonymous === true,
            authMethod: asString(profileRow.auth_method, "anonymous"),
          }
        : null;

      const wallet: ViewerWallet | null = walletRow
        ? {
            availableBalanceFet: asNumber(walletRow.available_balance_fet),
            lockedBalanceFet: asNumber(walletRow.locked_balance_fet),
            fanId: asString(walletRow.fan_id) || null,
            displayName: asString(walletRow.display_name) || null,
          }
        : {
            availableBalanceFet: 0,
            lockedBalanceFet: 0,
            fanId: profile?.fanId ?? null,
            displayName: profile?.displayName ?? null,
          };

      return {
        profile,
        wallet,
        walletTransactions: txRows.map((row) => {
          const direction = asString(row.direction);
          const txType = asString(row.tx_type);
          const transferSent = txType === "transfer" && direction === "debit";
          const transferReceived =
            txType === "transfer" && direction === "credit";
          return {
            id: asString(row.id),
            title: asString(
              row.title,
              transferSent ? "Transfer sent" : "Wallet activity",
            ),
            amount: asNumber(row.amount_fet),
            type: transferSent
              ? "transfer_sent"
              : transferReceived
                ? "transfer_received"
                : direction === "credit"
                  ? "earn"
                  : "spend",
            timestamp: new Date(asString(row.created_at)).getTime(),
            dateStr: relativeDateLabel(asString(row.created_at)),
          };
        }),
        notifications: notificationRows.map((row) => ({
          id: asString(row.id),
          type: asString(row.type, "system"),
          title: asString(row.title),
          message: asString(row.body),
          timestamp: new Date(asString(row.sent_at)).getTime(),
          read: !!row.read_at,
          data: (row.data as Record<string, unknown> | null) ?? {},
        })),
      };
    } catch (error) {
      console.warn("Failed to load viewer state", error);
      return null;
    }
  },

  async getPreferredPhonePreset(): Promise<WebsitePhonePreset> {
    const client = await ensureClient();
    const browserCountryCode = resolveBrowserCountryCode();

    if (!client) {
      return {
        countryCode: browserCountryCode,
        dialCode: "+",
        hint: "000 000 000",
        minDigits: 7,
      };
    }

    try {
      if (browserCountryCode) {
        const directRow = await maybeSingle<JsonRecord>(
          client
            .from("phone_presets")
            .select("country_code,dial_code,hint,min_digits")
            .eq("country_code", browserCountryCode)
            .maybeSingle(),
        );
        if (directRow) return normalizePhonePresetRow(directRow);
      }

      const fallbackRows = await selectList<JsonRecord>(
        client
          .from("phone_presets")
          .select("country_code,dial_code,hint,min_digits")
          .order("country_code", { ascending: true })
          .limit(1),
      );

      if (fallbackRows[0]) return normalizePhonePresetRow(fallbackRows[0]);
    } catch (error) {
      console.warn("Failed to load phone presets", error);
    }

    return {
      countryCode: browserCountryCode,
      dialCode: "+",
      hint: "000 000 000",
      minDigits: 7,
    };
  },

  async getPreferredCurrencyDisplay(): Promise<CurrencyDisplayPreference> {
    const client = await ensureClient();
    const browserCountryCode = resolveBrowserCountryCode();

    if (!client) {
      return {
        code: "EUR",
        symbol: "€",
        decimals: 2,
        spaceSeparated: false,
        rate: 1,
        fetPerEur: null,
      };
    }

    try {
      let currencyCode = "EUR";

      if (browserCountryCode) {
        const countryCurrencyRow = await maybeSingle<JsonRecord>(
          client
            .from("country_currency_map")
            .select("currency_code")
            .eq("country_code", browserCountryCode)
            .maybeSingle(),
        );
        currencyCode = asString(countryCurrencyRow?.currency_code, "EUR");
      }

      const [pegRow, displayRow, rateRow] = await Promise.all([
        maybeSingle<JsonRecord>(
          client
            .from("app_config_remote")
            .select("value")
            .eq("key", "fet_per_eur")
            .maybeSingle(),
        ),
        maybeSingle<JsonRecord>(
          client
            .from("currency_display_metadata")
            .select("currency_code,symbol,decimals,space_separated")
            .eq("currency_code", currencyCode)
            .maybeSingle(),
        ),
        currencyCode === "EUR"
          ? Promise.resolve<JsonRecord | null>({ rate: 1 } as JsonRecord)
          : maybeSingle<JsonRecord>(
              client
                .from("currency_rates")
                .select("rate")
                .eq("base_currency", "EUR")
                .eq("target_currency", currencyCode)
                .maybeSingle(),
            ),
      ]);

      const fetPerEurCandidate = asNumber(pegRow?.value, 0);
      const fetPerEur = fetPerEurCandidate > 0 ? fetPerEurCandidate : null;

      if (displayRow) {
        return {
          code: asString(displayRow.currency_code, currencyCode),
          symbol: asString(displayRow.symbol, "€"),
          decimals: asNumber(displayRow.decimals, 2),
          spaceSeparated: displayRow.space_separated === true,
          rate: asNumber(rateRow?.rate, 1),
          fetPerEur,
        };
      }
    } catch (error) {
      console.warn("Failed to load currency display preference", error);
    }

    return {
      code: "EUR",
      symbol: "€",
      decimals: 2,
      spaceSeparated: false,
      rate: 1,
      fetPerEur: null,
    };
  },

  async joinMatchPool(
    poolId: string,
    campId: string,
    amountFet?: number | null,
    inviteCode?: string | null,
    source: "direct" | "venue_qr" | "social_share" = "direct",
  ): Promise<{ success: boolean; error?: string }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      assertClientFeatureAvailable(
        "pools",
        "Match pools are currently unavailable.",
      );

      const { error } = await client.rpc("stake_fet", {
        p_pool_id: poolId,
        p_camp_id: campId,
        p_stake_amount: amountFet ?? null,
        p_source: inviteCode ? "invite_link" : source,
        p_invite_code: inviteCode ?? null,
      });

      if (error) throw new Error(error.message);
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : "Could not join pool.",
      };
    }
  },

  async transferFetByFanId(
    recipientFanId: string,
    amountFet: number,
  ): Promise<{
    success: boolean;
    viewerState?: ViewerState | null;
    error?: string;
  }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      assertClientFeatureAvailable(
        "wallet",
        "Wallet transfers are currently unavailable.",
      );

      const { error } = await client.rpc("transfer_fet_by_fan_id", {
        p_recipient_fan_id: recipientFanId,
        p_amount_fet: amountFet,
      });
      if (error) {
        throw new Error(error.message);
      }

      return {
        success: true,
        viewerState: await api.getViewerState(),
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : "Transfer failed.",
      };
    }
  },

  async markNotificationRead(notificationId: string): Promise<void> {
    const client = await ensureClient();
    if (!client) return;

    try {
      assertClientFeatureAvailable(
        "notifications",
        "Notifications are currently unavailable.",
      );

      const { error } = await client.rpc("mark_notification_read", {
        p_notification_id: notificationId,
      });
      if (error) {
        throw error;
      }
    } catch (error) {
      console.warn(
        `Failed to mark notification ${notificationId} as read`,
        error,
      );
    }
  },

  async markAllNotificationsRead(): Promise<void> {
    const client = await ensureClient();
    if (!client) return;

    try {
      assertClientFeatureAvailable(
        "notifications",
        "Notifications are currently unavailable.",
      );

      const { error } = await client.rpc("mark_all_notifications_read");
      if (error) {
        throw error;
      }
    } catch (error) {
      console.warn("Failed to mark all notifications as read", error);
    }
  },

  async fetchVenues(countryCode?: string): Promise<Venue[]> {
    const client = await ensureClient();
    if (!client) return [];

    let query = client.from("venues").select("*").eq("is_active", true);

    if (countryCode) {
      query = query.eq("country_code", countryCode);
    }

    const { data, error } = await query.order("name");
    if (error) throw error;

    return (data || []).map((row) => ({
      id: row.id,
      name: row.name,
      slug: row.slug,
      description: row.description,
      address: row.address_line1,
      country: row.country_code,
      logoUrl: row.logo_url,
      coverUrl: row.cover_url,
      isOpen: row.is_open,
      hoursJson: row.hours_json,
      revolutLink: row.revolut_link,
      momoCode: row.momo_code,
      whatsapp: row.whatsapp,
      primaryCategory: row.primary_category,
      rating: asNumber(row.rating, null),
      priceLevel: row.price_level,
    }));
  },

  async fetchVenueBySlug(slug: string): Promise<Venue | null> {
    const client = await ensureClient();
    if (!client) return null;

    const { data, error } = await client
      .from("venues")
      .select("*")
      .eq("slug", slug)
      .maybeSingle();

    if (error) throw error;
    if (!data) return null;

    return {
      id: data.id,
      name: data.name,
      slug: data.slug,
      description: data.description,
      address: data.address_line1,
      country: data.country_code,
      logoUrl: data.logo_url,
      coverUrl: data.cover_url,
      isOpen: data.is_open,
      hoursJson: data.hours_json,
      revolutLink: data.revolut_link,
      momoCode: data.momo_code,
      whatsapp: data.whatsapp,
      primaryCategory: data.primary_category,
      rating: asNumber(data.rating, null),
      priceLevel: data.price_level,
    };
  },

  async fetchMenu(
    venueId: string,
  ): Promise<{ categories: MenuCategory[]; items: MenuItem[] }> {
    const client = await ensureClient();
    if (!client) return { categories: [], items: [] };

    const [catRes, itemRes] = await Promise.all([
      client
        .from("menu_categories")
        .select("*")
        .eq("venue_id", venueId)
        .eq("is_visible", true)
        .order("display_order"),
      client
        .from("menu_items")
        .select("*")
        .eq("venue_id", venueId)
        .eq("is_available", true)
        .order("display_order"),
    ]);

    if (catRes.error) throw catRes.error;
    if (itemRes.error) throw itemRes.error;

    const categories = (catRes.data || []).map((row) => ({
      id: row.id,
      venueId: row.venue_id,
      name: row.name,
      displayOrder: row.display_order,
    }));

    const items = (itemRes.data || []).map((row) => ({
      id: row.id,
      venueId: row.venue_id,
      categoryId: row.category_id,
      name: row.name,
      description: row.description,
      price: asNumber(row.price),
      currencyCode: row.currency_code,
      imageUrl: row.image_url,
      isAvailable: row.is_available,
      isFeatured: row.is_featured,
      displayOrder: row.display_order,
      addOns: row.add_ons,
      dietaryFlags: row.dietary_flags,
    }));

    return { categories, items };
  },

  async placeOrder(payload: {
    venueId: string;
    tableId?: string;
    tablePublicCode?: string;
    paymentMethod: PaymentMethod;
    items: Array<{ menuItemId: string; quantity: number }>;
  }): Promise<Order> {
    const client = await ensureClient();
    if (!client) throw new Error("Supabase client not available");

    const body: Record<string, unknown> = {
      venue_id: payload.venueId,
      payment_method: payload.paymentMethod,
      items: payload.items.map((item) => ({
        menu_item_id: item.menuItemId,
        quantity: item.quantity,
      })),
    };

    if (payload.tableId) {
      body.table_id = payload.tableId;
    } else if (payload.tablePublicCode) {
      body.table_public_code = payload.tablePublicCode;
    } else {
      throw new Error("Table context is required to place an order");
    }

    const { data, error } = await client.functions.invoke("order_create", {
      body,
    });

    if (error) throw error;
    if (!data?.success || !data.order) {
      throw new Error("Order creation failed");
    }

    const row = data.order as JsonRecord & { items?: JsonRecord[] };
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
        payload.paymentMethod,
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
  },
};
