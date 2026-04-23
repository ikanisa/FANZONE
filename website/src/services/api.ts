import type {
  Competition,
  LeaderboardEntry,
  Match,
  PredictionConsensus,
  PredictionEngineOutput,
  StandingRow,
  Team,
  TeamFormFeature,
  UserPrediction,
  ViewerProfile,
  ViewerWallet,
} from "../types";
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

function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asString(item).trim())
    .filter((item) => item.length > 0);
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

function normalizeCompetitionRow(row: JsonRecord): Competition {
  return {
    id: asString(row.id),
    name: asString(row.name),
    shortName: asString(row.short_name),
    country: asString(row.country),
    tier: asNumber(row.tier, 1),
    competitionType: asString(row.competition_type) || null,
    isFeatured: row.is_featured === true,
    isInternational: row.is_international === true,
    isActive: row.is_active !== false,
    currentSeasonId: asString(row.current_season_id) || null,
    currentSeasonLabel: asString(row.current_season_label) || null,
    futureMatchCount: asNumber(row.future_match_count),
    catalogRank: row.catalog_rank == null ? null : asNumber(row.catalog_rank),
  };
}

function normalizeTeamRow(row: JsonRecord): Team {
  return {
    id: asString(row.id),
    name: asString(row.name),
    shortName: asString(row.short_name) || asString(row.name),
    slug: asString(row.slug) || asString(row.id),
    country: asString(row.country) || null,
    countryCode: asString(row.country_code) || null,
    teamType: asString(row.team_type, "club"),
    description: asString(row.description) || null,
    leagueName: asString(row.league_name) || null,
    region: asString(row.region) || null,
    competitionIds: asStringList(row.competition_ids),
    aliases: asStringList(row.aliases),
    searchTerms: asStringList(row.search_terms),
    logoUrl: asString(row.logo_url) || null,
    crestUrl: asString(row.crest_url) || null,
    coverImageUrl: asString(row.cover_image_url) || null,
    isActive: row.is_active !== false,
    isFeatured: row.is_featured === true,
    isPopularPick: row.is_popular_pick === true,
    popularPickRank:
      row.popular_pick_rank == null ? null : asNumber(row.popular_pick_rank),
    fanCount: asNumber(row.fan_count),
  };
}

function normalizeStandingRow(row: JsonRecord): StandingRow {
  return {
    id: asString(row.id),
    competitionId: asString(row.competition_id),
    seasonId: asString(row.season_id),
    season: asString(row.season),
    snapshotType: asString(row.snapshot_type),
    snapshotDate: asString(row.snapshot_date),
    teamId: asString(row.team_id),
    teamName: asString(row.team_name),
    position: asNumber(row.position),
    played: asNumber(row.played),
    won: asNumber(row.won),
    drawn: asNumber(row.drawn),
    lost: asNumber(row.lost),
    goalsFor: asNumber(row.goals_for),
    goalsAgainst: asNumber(row.goals_against),
    goalDifference: asNumber(row.goal_difference),
    points: asNumber(row.points),
  };
}

function normalizeFormRow(row: JsonRecord): TeamFormFeature {
  return {
    matchId: asString(row.match_id),
    teamId: asString(row.team_id),
    last5Points: asNumber(row.last5_points),
    last5Wins: asNumber(row.last5_wins),
    last5Draws: asNumber(row.last5_draws),
    last5Losses: asNumber(row.last5_losses),
    last5GoalsFor: asNumber(row.last5_goals_for),
    last5GoalsAgainst: asNumber(row.last5_goals_against),
    last5CleanSheets: asNumber(row.last5_clean_sheets),
    last5FailedToScore: asNumber(row.last5_failed_to_score),
    homeFormLast5: asNumber(row.home_form_last5),
    awayFormLast5: asNumber(row.away_form_last5),
    over25Last5: asNumber(row.over25_last5),
    bttsLast5: asNumber(row.btts_last5),
  };
}

function normalizeEngineRow(row: JsonRecord): PredictionEngineOutput {
  return {
    id: asString(row.id),
    matchId: asString(row.match_id),
    modelVersion: asString(row.model_version),
    homeWinScore: asNumber(row.home_win_score),
    drawScore: asNumber(row.draw_score),
    awayWinScore: asNumber(row.away_win_score),
    over25Score: asNumber(row.over25_score),
    bttsScore: asNumber(row.btts_score),
    predictedHomeGoals:
      row.predicted_home_goals == null
        ? null
        : asNumber(row.predicted_home_goals),
    predictedAwayGoals:
      row.predicted_away_goals == null
        ? null
        : asNumber(row.predicted_away_goals),
    confidenceLabel: asString(row.confidence_label, "low"),
    generatedAt: asString(row.generated_at),
  };
}

function normalizeConsensusRow(row: JsonRecord): PredictionConsensus {
  return {
    matchId: asString(row.match_id),
    totalPredictions: asNumber(row.total_predictions),
    homePickCount: asNumber(row.home_pick_count),
    drawPickCount: asNumber(row.draw_pick_count),
    awayPickCount: asNumber(row.away_pick_count),
    homePct: asNumber(row.home_pct),
    drawPct: asNumber(row.draw_pct),
    awayPct: asNumber(row.away_pct),
  };
}

function normalizeUserPredictionRow(row: JsonRecord): UserPrediction {
  return {
    id: asString(row.id),
    matchId: asString(row.match_id),
    predictedResultCode: asString(row.predicted_result_code) || null,
    predictedOver25:
      row.predicted_over25 == null ? null : row.predicted_over25 === true,
    predictedBtts:
      row.predicted_btts == null ? null : row.predicted_btts === true,
    predictedHomeGoals:
      row.predicted_home_goals == null
        ? null
        : asNumber(row.predicted_home_goals),
    predictedAwayGoals:
      row.predicted_away_goals == null
        ? null
        : asNumber(row.predicted_away_goals),
    pointsAwarded: asNumber(row.points_awarded),
    rewardStatus: asString(row.reward_status),
    createdAt: asString(row.created_at),
    updatedAt: asString(row.updated_at),
  };
}

function normalizeLeaderboardRow(row: JsonRecord): LeaderboardEntry {
  return {
    userId: asString(row.user_id),
    displayName: asString(row.display_name),
    predictionCount: asNumber(row.prediction_count),
    totalPoints: asNumber(row.total_points),
    totalFet: asNumber(row.total_fet),
    correctResults: asNumber(row.correct_results),
    exactScores: asNumber(row.exact_scores),
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
  favoriteTeams: string[];
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
}

export interface PredictionSubmission {
  matchId: string;
  predictedResultCode?: string | null;
  predictedOver25?: boolean | null;
  predictedBtts?: boolean | null;
  predictedHomeGoals?: number | null;
  predictedAwayGoals?: number | null;
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

  async getLiveMatches(limit = 12): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("app_matches")
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
          .from("app_matches")
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

  async getMatchesWindow(dateFrom: string, dateTo: string): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("app_matches")
          .select("*")
          .gte("date", dateFrom)
          .lte("date", dateTo)
          .order("date", { ascending: true })
          .order("kickoff_time", { ascending: true })
          .limit(300),
      );
      return rows.map(normalizeMatchRow);
    } catch (error) {
      console.warn("Failed to load match window", error);
      return [];
    }
  },

  async getCompetitions(): Promise<Competition[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("competitions")
          .select(
            "id,name,short_name,country,tier,competition_type,is_featured,is_international,is_active,current_season_id,current_season_label,future_match_count,catalog_rank",
          )
          .eq("is_active", true)
          .order("is_featured", { ascending: false })
          .order("catalog_rank", { ascending: true, nullsFirst: false })
          .order("name", { ascending: true }),
      );
      return rows.map(normalizeCompetitionRow);
    } catch (error) {
      console.warn("Failed to load competitions", error);
      return [];
    }
  },

  async getCompetitionById(competitionId: string): Promise<Competition | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const row = await maybeSingle<JsonRecord>(
        client
          .from("competitions")
          .select(
            "id,name,short_name,country,tier,competition_type,is_featured,is_international,is_active,current_season_id,current_season_label,future_match_count,catalog_rank",
          )
          .eq("id", competitionId)
          .maybeSingle(),
      );
      return row ? normalizeCompetitionRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load competition ${competitionId}`, error);
      return null;
    }
  },

  async getCompetitionMatches(
    competitionId: string,
    limit = 18,
  ): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("app_matches")
          .select("*")
          .eq("competition_id", competitionId)
          .order("date", { ascending: true })
          .limit(limit),
      );
      return rows.map(normalizeMatchRow);
    } catch (error) {
      console.warn(`Failed to load matches for ${competitionId}`, error);
      return [];
    }
  },

  async getCompetitionTeams(competitionId: string): Promise<Team[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("teams")
          .select("*")
          .eq("is_active", true)
          .contains("competition_ids", [competitionId])
          .order("is_popular_pick", { ascending: false })
          .order("fan_count", { ascending: false })
          .order("name", { ascending: true }),
      );
      return rows.map(normalizeTeamRow);
    } catch (error) {
      console.warn(
        `Failed to load competition teams for ${competitionId}`,
        error,
      );
      return [];
    }
  },

  async getPopularTeams(limit = 12): Promise<Team[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("teams")
          .select("*")
          .eq("is_active", true)
          .order("is_popular_pick", { ascending: false })
          .order("popular_pick_rank", { ascending: true, nullsFirst: false })
          .order("fan_count", { ascending: false })
          .order("name", { ascending: true })
          .limit(limit),
      );
      return rows.map(normalizeTeamRow);
    } catch (error) {
      console.warn("Failed to load popular teams", error);
      return [];
    }
  },

  async searchTeams(query: string, limit = 8): Promise<Team[]> {
    const client = await ensureClient();
    if (!client) return [];

    const trimmed = query.trim();
    if (!trimmed) return [];

    const sanitized = trimmed.replace(/[,%]/g, "").slice(0, 64);
    const pattern = `%${sanitized}%`;

    try {
      const [directRows, aliasRows] = await Promise.all([
        selectList<JsonRecord>(
          client
            .from("teams")
            .select("*")
            .eq("is_active", true)
            .or(`name.ilike.${pattern},short_name.ilike.${pattern}`)
            .limit(limit * 2),
        ),
        selectList<JsonRecord>(
          client
            .from("team_aliases")
            .select("team_id")
            .ilike("alias_name", pattern)
            .limit(limit * 2),
        ),
      ]);

      const merged = new Map<string, JsonRecord>();
      for (const row of directRows) {
        const id = asString(row.id);
        if (id) merged.set(id, row);
      }

      const aliasIds = [
        ...new Set(
          aliasRows.map((row) => asString(row.team_id)).filter(Boolean),
        ),
      ];
      if (aliasIds.length > 0) {
        const aliasTeams = await selectList<JsonRecord>(
          client
            .from("teams")
            .select("*")
            .in("id", aliasIds)
            .eq("is_active", true),
        );
        for (const row of aliasTeams) {
          const id = asString(row.id);
          if (id) merged.set(id, row);
        }
      }

      return [...merged.values()]
        .map(normalizeTeamRow)
        .sort((left, right) => {
          if (left.isPopularPick !== right.isPopularPick) {
            return left.isPopularPick ? -1 : 1;
          }
          const leftRank = left.popularPickRank ?? Number.MAX_SAFE_INTEGER;
          const rightRank = right.popularPickRank ?? Number.MAX_SAFE_INTEGER;
          if (leftRank !== rightRank) return leftRank - rightRank;
          if (left.fanCount !== right.fanCount)
            return right.fanCount - left.fanCount;
          return left.name.localeCompare(right.name);
        })
        .slice(0, limit);
    } catch (error) {
      console.warn(`Failed to search teams for "${trimmed}"`, error);
      return [];
    }
  },

  async getCompetitionStandings(
    competitionId: string,
    season?: string | null,
  ): Promise<StandingRow[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      let query = client
        .from("competition_standings")
        .select("*")
        .eq("competition_id", competitionId);

      if (season && season.trim()) {
        query = query.eq("season", season.trim());
      }

      const rows = await selectList<JsonRecord>(
        query.order("snapshot_date", { ascending: false }).order("position", {
          ascending: true,
        }),
      );
      return rows.map(normalizeStandingRow);
    } catch (error) {
      console.warn(`Failed to load standings for ${competitionId}`, error);
      return [];
    }
  },

  async getTeamByIdOrSlug(teamIdOrSlug: string): Promise<Team | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      let row = await maybeSingle<JsonRecord>(
        client.from("teams").select("*").eq("id", teamIdOrSlug).maybeSingle(),
      );

      if (!row) {
        const aliasRow = await maybeSingle<JsonRecord>(
          client
            .from("team_aliases")
            .select("team_id")
            .eq("alias_name", teamIdOrSlug)
            .maybeSingle(),
        );
        if (aliasRow && typeof aliasRow.team_id === "string") {
          row = await maybeSingle<JsonRecord>(
            client
              .from("teams")
              .select("*")
              .eq("id", aliasRow.team_id)
              .maybeSingle(),
          );
        }
      }

      return row ? normalizeTeamRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load team ${teamIdOrSlug}`, error);
      return null;
    }
  },

  async getTeamMatches(teamId: string, limit = 10): Promise<Match[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("app_matches")
          .select("*")
          .or(`home_team_id.eq.${teamId},away_team_id.eq.${teamId}`)
          .order("date", { ascending: false })
          .limit(limit),
      );
      return rows.map(normalizeMatchRow);
    } catch (error) {
      console.warn(`Failed to load team matches for ${teamId}`, error);
      return [];
    }
  },

  async getMatchDetail(matchId: string): Promise<Match | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const row = await maybeSingle<JsonRecord>(
        client.from("app_matches").select("*").eq("id", matchId).maybeSingle(),
      );
      return row ? normalizeMatchRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load match ${matchId}`, error);
      return null;
    }
  },

  async getPredictionEngineOutput(
    matchId: string,
  ): Promise<PredictionEngineOutput | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const row = await maybeSingle<JsonRecord>(
        client
          .from("predictions_engine_outputs")
          .select("*")
          .eq("match_id", matchId)
          .maybeSingle(),
      );
      return row ? normalizeEngineRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load engine output for ${matchId}`, error);
      return null;
    }
  },

  async getMatchFormFeatures(matchId: string): Promise<TeamFormFeature[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client.from("team_form_features").select("*").eq("match_id", matchId),
      );
      return rows.map(normalizeFormRow);
    } catch (error) {
      console.warn(`Failed to load form features for ${matchId}`, error);
      return [];
    }
  },

  async getMatchPredictionConsensus(
    matchId: string,
  ): Promise<PredictionConsensus | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const row = await maybeSingle<JsonRecord>(
        client
          .from("match_prediction_consensus")
          .select("*")
          .eq("match_id", matchId)
          .maybeSingle(),
      );
      return row ? normalizeConsensusRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load consensus for ${matchId}`, error);
      return null;
    }
  },

  async getMyPredictionForMatch(
    matchId: string,
  ): Promise<UserPrediction | null> {
    const client = await ensureClient();
    if (!client) return null;

    try {
      const userId = await ensureWebsiteSession();
      if (!userId) return null;

      const row = await maybeSingle<JsonRecord>(
        client
          .from("user_predictions")
          .select("*")
          .eq("user_id", userId)
          .eq("match_id", matchId)
          .maybeSingle(),
      );
      return row ? normalizeUserPredictionRow(row) : null;
    } catch (error) {
      console.warn(`Failed to load viewer prediction for ${matchId}`, error);
      return null;
    }
  },

  async getLeaderboard(limit = 20): Promise<LeaderboardEntry[]> {
    const client = await ensureClient();
    if (!client) return [];

    try {
      const rows = await selectList<JsonRecord>(
        client
          .from("public_leaderboard")
          .select("*")
          .order("total_points", { ascending: false })
          .order("total_fet", { ascending: false })
          .limit(limit),
      );
      return rows.map(normalizeLeaderboardRow);
    } catch (error) {
      console.warn("Failed to load leaderboard", error);
      return [];
    }
  },

  async getViewerState(): Promise<ViewerState | null> {
    const client = await ensureClient();
    if (!client) return null;

    const userId = await ensureWebsiteSession();
    if (!userId) return null;

    try {
      const [profileRow, walletRow, txRows, notificationRows, favoriteRows] =
        await Promise.all([
          maybeSingle<JsonRecord>(
            client
              .from("profiles")
              .select(
                "user_id,fan_id,display_name,favorite_team_id,favorite_team_name,onboarding_completed,is_anonymous,auth_method",
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
          selectList<JsonRecord>(
            client
              .from("user_favorite_teams")
              .select("team_name")
              .order("sort_order", { ascending: true })
              .order("created_at", { ascending: true })
              .limit(12),
          ),
        ]);

      const profile: ViewerProfile | null = profileRow
        ? {
            userId: asString(profileRow.user_id),
            fanId: asString(profileRow.fan_id, "------"),
            displayName:
              asString(profileRow.display_name) ||
              `Fan #${asString(profileRow.fan_id, "------")}`,
            favoriteTeamId: asString(profileRow.favorite_team_id) || null,
            favoriteTeamName: asString(profileRow.favorite_team_name) || null,
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
        favoriteTeams: favoriteRows
          .map((row) => asString(row.team_name))
          .filter((teamName) => teamName.length > 0),
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

      const [displayRow, rateRow] = await Promise.all([
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

      if (displayRow) {
        return {
          code: asString(displayRow.currency_code, currencyCode),
          symbol: asString(displayRow.symbol, "€"),
          decimals: asNumber(displayRow.decimals, 2),
          spaceSeparated: displayRow.space_separated === true,
          rate: asNumber(rateRow?.rate, 1),
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
    };
  },

  async submitPredictionEntry(
    input: PredictionSubmission,
  ): Promise<{ success: boolean; predictionId?: string; error?: string }> {
    const client = await ensureClient();
    if (!client) {
      return {
        success: false,
        error: "Supabase is not configured for the website.",
      };
    }

    try {
      const { data, error } = await client.rpc("submit_user_prediction", {
        p_match_id: input.matchId,
        p_predicted_result_code: input.predictedResultCode ?? null,
        p_predicted_over25: input.predictedOver25 ?? null,
        p_predicted_btts: input.predictedBtts ?? null,
        p_predicted_home_goals: input.predictedHomeGoals ?? null,
        p_predicted_away_goals: input.predictedAwayGoals ?? null,
      });

      if (error) {
        throw new Error(error.message);
      }

      return {
        success: true,
        predictionId: data ? String(data) : undefined,
      };
    } catch (error) {
      return {
        success: false,
        error:
          error instanceof Error ? error.message : "Could not save prediction.",
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
      await client
        .from("notification_log")
        .update({ read_at: new Date().toISOString() })
        .eq("id", notificationId)
        .is("read_at", null);
    } catch (error) {
      console.warn(
        `Failed to mark notification ${notificationId} as read`,
        error,
      );
    }
  },

  async markAllNotificationsRead(): Promise<void> {
    const client = await ensureClient();
    const userId = await ensureWebsiteSession();
    if (!client || !userId) return;

    try {
      await client
        .from("notification_log")
        .update({ read_at: new Date().toISOString() })
        .eq("user_id", userId)
        .is("read_at", null);
    } catch (error) {
      console.warn("Failed to mark all notifications as read", error);
    }
  },
};
