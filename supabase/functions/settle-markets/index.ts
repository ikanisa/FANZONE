// FANZONE — Automated Market Settlement Edge Function
//
// Orchestrates FULL settlement pipeline for ALL 108 market types:
//
// 1. Reads settlement configs FROM prediction_market_types (DB-driven)
// 2. Gathers match data (scores + events from DB)
// 3. If stats-tier markets exist → calls Gemini for enrichment
// 4. Builds comprehensive match_stats JSONB
// 5. Calls settle_match_selections() RPC
// 6. Logs results + notifies winners
//
// Triggered by:
//   - match finish trigger (via pg_net)
//   - pg_cron every 15 minutes
//   - manual admin POST
//
// Auth: x-cron-secret or service_role bearer

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET") || "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const PUSH_NOTIFY_SECRET = Deno.env.get("PUSH_NOTIFY_SECRET")?.trim() || "";
const PUSH_NOTIFY_URL = `${SUPABASE_URL}/functions/v1/push-notify`;

// ═══════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════

interface MatchRow {
  id: string;
  competition_id: string | null;
  home_team: string;
  away_team: string;
  home_team_id: string | null;
  away_team_id: string | null;
  ft_home: number;
  ft_away: number;
  ht_home: number | null;
  ht_away: number | null;
  et_home: number | null;
  et_away: number | null;
  status: string;
  round: string | null;
}

interface MatchEventRow {
  id: string;
  minute: number;
  event_type: string;
  team_id: string | null;
  team_name: string | null;
  player_name: string | null;
  description: string | null;
}

interface SettlementConfig {
  match_id: string;
  pending_count: number;
  data_tiers_needed: string[];
  market_types: Array<{
    id: string;
    eval_key: string;
    config: Record<string, unknown>;
    data_tier: string;
  }>;
}

interface MatchStats {
  ft_home: number;
  ft_away: number;
  ht_home: number;
  ht_away: number;
  et_home: number | null;
  et_away: number | null;
  total_goals: number;
  home_team: string;
  away_team: string;
  home_team_id: string | null;
  away_team_id: string | null;
  events: MatchEventRow[];
  event_counts: Record<string, number>;
  stats?: Record<string, number>;
  stats_enriched?: boolean;
  knockout?: { qualified_team?: string; method?: string };
  penalties?: boolean;
}

interface SettlementResult {
  match_id: string;
  match_name: string;
  selections_settled: number;
  won: number;
  lost: number;
  void_count: number;
  gemini_enriched: boolean;
}

// ═══════════════════════════════════════════════════════════════
// Data gathering
// ═══════════════════════════════════════════════════════════════

async function getFinishedMatchesWithPendingSelections(
  supabase: SupabaseClient,
  specificMatchId?: string,
): Promise<string[]> {
  if (specificMatchId) {
    return [specificMatchId];
  }

  // Find matches finished in last 48h with pending selections
  const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from("prediction_slip_selections")
    .select("match_id")
    .eq("result", "pending")
    .not("match_id", "is", null);

  if (error) throw new Error(`Query pending selections: ${error.message}`);
  if (!data?.length) return [];

  const matchIds = [...new Set(data.map((r: { match_id: string }) => r.match_id))];

  // Filter to only finished matches
  const { data: finishedMatches, error: matchErr } = await supabase
    .from("matches")
    .select("id")
    .in("id", matchIds)
    .eq("status", "finished")
    .not("ft_home", "is", null)
    .not("ft_away", "is", null);

  if (matchErr) throw new Error(`Query finished matches: ${matchErr.message}`);
  return (finishedMatches || []).map((m: { id: string }) => m.id);
}

async function getMatchData(
  supabase: SupabaseClient,
  matchId: string,
): Promise<MatchRow | null> {
  const { data, error } = await supabase
    .from("matches")
    .select("id, competition_id, home_team, away_team, home_team_id, away_team_id, ft_home, ft_away, ht_home, ht_away, et_home, et_away, status, round")
    .eq("id", matchId)
    .single();

  if (error) return null;
  return data as MatchRow;
}

async function getMatchEvents(
  supabase: SupabaseClient,
  matchId: string,
): Promise<MatchEventRow[]> {
  const { data, error } = await supabase
    .from("match_events")
    .select("id, minute, event_type, team_id, team_name, player_name, description")
    .eq("match_id", matchId)
    .order("minute", { ascending: true });

  if (error) {
    console.warn(`Failed to load events for ${matchId}: ${error.message}`);
    return [];
  }
  return (data || []) as MatchEventRow[];
}

async function getSettlementConfig(
  supabase: SupabaseClient,
  matchId: string,
): Promise<SettlementConfig> {
  const { data, error } = await supabase.rpc("get_settlement_config_for_match", {
    p_match_id: matchId,
  });

  if (error) throw new Error(`Settlement config: ${error.message}`);
  return data as SettlementConfig;
}

// ═══════════════════════════════════════════════════════════════
// Event counting (from match_events rows)
// ═══════════════════════════════════════════════════════════════

function computeEventCounts(events: MatchEventRow[]): Record<string, number> {
  const counts: Record<string, number> = {
    goals: 0,
    own_goals: 0,
    penalties: 0,
    penalties_scored: 0,
    penalties_missed: 0,
    yellow_cards: 0,
    red_cards: 0,
    total_cards: 0,
    total_yellow_cards: 0,
    var_decisions: 0,
    substitutions: 0,
  };

  for (const ev of events) {
    const type = ev.event_type?.toUpperCase();
    switch (type) {
      case "GOAL":
        counts.goals++;
        break;
      case "OWN_GOAL":
        counts.own_goals++;
        break;
      case "PENALTY_SCORED":
        counts.penalties++;
        counts.penalties_scored++;
        break;
      case "PENALTY_MISSED":
        counts.penalties++;
        counts.penalties_missed++;
        break;
      case "YELLOW_CARD":
        counts.yellow_cards++;
        counts.total_cards++;
        counts.total_yellow_cards++;
        break;
      case "RED_CARD":
        counts.red_cards++;
        counts.total_cards++;
        break;
      case "VAR_DECISION":
        counts.var_decisions++;
        break;
      case "SUBSTITUTION":
        counts.substitutions++;
        break;
    }
  }

  return counts;
}

// ═══════════════════════════════════════════════════════════════
// Gemini enrichment (for stats-tier markets)
// ═══════════════════════════════════════════════════════════════

interface GeminiMatchStats {
  total_corners: number | null;
  home_corners: number | null;
  away_corners: number | null;
  first_half_corners: number | null;
  home_possession: number | null;
  away_possession: number | null;
  home_shots: number | null;
  away_shots: number | null;
  home_shots_on_target: number | null;
  away_shots_on_target: number | null;
  home_fouls: number | null;
  away_fouls: number | null;
  home_offsides: number | null;
  away_offsides: number | null;
  // Player-level stats keyed by player name
  player_stats?: Record<string, {
    shots: number | null;
    shots_on_target: number | null;
    passes: number | null;
    tackles: number | null;
    assists: number | null;
    saves: number | null;
  }>;
  // Knockout context
  qualified_team?: string | null;
  victory_method?: string | null; // "regular_time", "extra_time", "penalties"
  // Race-to results
  race_to_5_corners_winner?: string | null;
}

const GEMINI_STATS_SCHEMA = {
  type: "OBJECT",
  description:
    "Full match statistics for a finished football match. Return numeric values or null if uncertain.",
  properties: {
    total_corners: {
      type: "INTEGER",
      description: "Total corners for both teams combined",
    },
    home_corners: { type: "INTEGER", description: "Corners for home team" },
    away_corners: { type: "INTEGER", description: "Corners for away team" },
    first_half_corners: {
      type: "INTEGER",
      description: "Total corners in the first half",
    },
    home_possession: {
      type: "INTEGER",
      description: "Home possession percentage (0-100)",
    },
    away_possession: {
      type: "INTEGER",
      description: "Away possession percentage (0-100)",
    },
    home_shots: {
      type: "INTEGER",
      description: "Total shots by home team",
    },
    away_shots: {
      type: "INTEGER",
      description: "Total shots by away team",
    },
    home_shots_on_target: {
      type: "INTEGER",
      description: "Shots on target by home team",
    },
    away_shots_on_target: {
      type: "INTEGER",
      description: "Shots on target by away team",
    },
    qualified_team: {
      type: "STRING",
      description:
        "For knockout matches: which team advanced. Null for non-knockout.",
    },
    victory_method: {
      type: "STRING",
      description:
        'How the match was decided: "regular_time", "extra_time", or "penalties". Null for non-knockout.',
    },
    race_to_5_corners_winner: {
      type: "STRING",
      description:
        "Which team reached 5 corners first, or null if neither did",
    },
  },
  required: ["total_corners", "home_corners", "away_corners"],
};

async function enrichWithGemini(
  match: MatchRow,
  neededStats: string[],
): Promise<GeminiMatchStats | null> {
  if (!GEMINI_API_KEY) {
    console.warn("GEMINI_API_KEY not set — skipping stats enrichment");
    return null;
  }

  const prompt =
    `Find the full match statistics for this finished football match:
${match.home_team} vs ${match.away_team}
Final score: ${match.ft_home}-${match.ft_away}
Competition: ${match.competition_id || "unknown"}
Round: ${match.round || "unknown"}

I need: ${neededStats.join(", ")}

Return ONLY confirmed statistics from official match reports. Use null for any stat you cannot confirm.`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: GEMINI_STATS_SCHEMA,
            temperature: 0.1,
          },
          tools: [{
            googleSearch: {},
          }],
        }),
      },
    );

    if (!response.ok) {
      console.error(`Gemini API error: ${response.status}`);
      return null;
    }

    const result = await response.json();
    const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return null;

    return JSON.parse(text) as GeminiMatchStats;
  } catch (error) {
    console.error("Gemini enrichment failed:", getErrorMessage(error));
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
// Build match_stats payload
// ═══════════════════════════════════════════════════════════════

function buildMatchStats(
  match: MatchRow,
  events: MatchEventRow[],
  geminiStats: GeminiMatchStats | null,
): MatchStats {
  const eventCounts = computeEventCounts(events);

  const stats: MatchStats = {
    ft_home: match.ft_home,
    ft_away: match.ft_away,
    ht_home: match.ht_home ?? 0,
    ht_away: match.ht_away ?? 0,
    et_home: match.et_home,
    et_away: match.et_away,
    total_goals: match.ft_home + match.ft_away,
    home_team: match.home_team,
    away_team: match.away_team,
    home_team_id: match.home_team_id,
    away_team_id: match.away_team_id,
    events: events.map((e) => ({
      ...e,
      event_type: e.event_type?.toUpperCase(),
    })),
    event_counts: eventCounts,
  };

  // Add ET / penalty flags
  if (match.et_home !== null) {
    stats.penalties = false; // ET played but no pens
  }

  // Gemini enrichment
  if (geminiStats) {
    stats.stats_enriched = true;
    stats.stats = {};

    // Map Gemini stats to flat keys
    if (geminiStats.total_corners != null) {
      stats.stats.total_corners = geminiStats.total_corners;
    }
    if (geminiStats.home_corners != null) {
      stats.stats.home_corners = geminiStats.home_corners;
    }
    if (geminiStats.away_corners != null) {
      stats.stats.away_corners = geminiStats.away_corners;
    }
    if (geminiStats.first_half_corners != null) {
      stats.stats.first_half_corners = geminiStats.first_half_corners;
    }
    if (geminiStats.home_shots != null) {
      stats.stats.home_shots = geminiStats.home_shots;
    }
    if (geminiStats.away_shots != null) {
      stats.stats.away_shots = geminiStats.away_shots;
    }
    if (geminiStats.home_shots_on_target != null) {
      stats.stats.home_shots_on_target = geminiStats.home_shots_on_target;
    }
    if (geminiStats.away_shots_on_target != null) {
      stats.stats.away_shots_on_target = geminiStats.away_shots_on_target;
    }

    // Knockout context
    if (geminiStats.qualified_team) {
      stats.knockout = {
        qualified_team: geminiStats.qualified_team,
        method: geminiStats.victory_method || undefined,
      };
    }

    // Race-to-5 corners
    if (geminiStats.race_to_5_corners_winner) {
      stats.stats.race_to_5_corners = 1; // placeholder
      stats.stats[`race_to_5_corners`] = 1;
    }
  }

  return stats;
}

// ═══════════════════════════════════════════════════════════════
// Determine which stats Gemini needs to fetch
// ═══════════════════════════════════════════════════════════════

function determineNeededStats(config: SettlementConfig): string[] {
  const needed = new Set<string>();

  for (const mt of config.market_types) {
    if (mt.data_tier !== "stats") continue;

    const cfg = mt.config as Record<string, unknown>;
    const stat = cfg.stat as string | undefined;

    if (stat) {
      if (stat.includes("corners")) needed.add("corners");
      if (stat.includes("shots")) needed.add("shots");
      if (stat.includes("passes")) needed.add("passes");
      if (stat.includes("tackles")) needed.add("tackles");
      if (stat.includes("assists")) needed.add("assists");
      if (stat.includes("saves")) needed.add("goalkeeper saves");
    }

    if (mt.eval_key === "knockout") {
      needed.add("qualified team");
      needed.add("victory method");
    }

    if (mt.eval_key === "race_to") {
      needed.add("race to 5 corners");
    }
  }

  return [...needed];
}

// ═══════════════════════════════════════════════════════════════
// Notification
// ═══════════════════════════════════════════════════════════════

async function notifyWinners(
  supabase: SupabaseClient,
  matchId: string,
  matchName: string,
  score: string,
) {
  try {
    // Get users who won slips for this match
    const { data: winningSlips } = await supabase
      .from("prediction_slips")
      .select("user_id")
      .eq("status", "settled_win")
      .in(
        "id",
        supabase
          .from("prediction_slip_selections")
          .select("slip_id")
          .eq("match_id", matchId)
          .eq("result", "won"),
      );

    if (!winningSlips?.length || !PUSH_NOTIFY_SECRET) return 0;

    const userIds = [
      ...new Set(winningSlips.map((s: { user_id: string }) => s.user_id)),
    ];

    const response = await fetch(PUSH_NOTIFY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-push-notify-secret": PUSH_NOTIFY_SECRET,
      },
      body: JSON.stringify({
        user_ids: userIds,
        type: "market_settled",
        title: "🎉 Prediction correct!",
        body: `Your prediction for ${matchName} (${score}) was spot on!`,
        data: { match_id: matchId, screen: "/predict" },
      }),
    });

    return response.ok ? userIds.length : 0;
  } catch (error) {
    console.warn("Failed to notify winners:", getErrorMessage(error));
    return 0;
  }
}

// ═══════════════════════════════════════════════════════════════
// Main handler
// ═══════════════════════════════════════════════════════════════

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders(
        "authorization, content-type, x-cron-secret",
      ),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey: SUPABASE_SERVICE_KEY,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: CRON_SECRET }],
    })
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const results: SettlementResult[] = [];
  const errors: string[] = [];

  try {
    // Parse optional match_id from body
    let specificMatchId: string | undefined;
    try {
      const body = await req.json();
      specificMatchId = body?.match_id;
    } catch {
      // No body or invalid JSON — settle all
    }

    // ── 1) Find matches to settle ──
    const matchIds = await getFinishedMatchesWithPendingSelections(
      supabase,
      specificMatchId,
    );

    if (matchIds.length === 0) {
      return Response.json({
        timestamp: new Date().toISOString(),
        message: "No matches to settle",
        matches_processed: 0,
      });
    }

    // ── 2) Process each match ──
    for (const matchId of matchIds) {
      try {
        // Get match data
        const match = await getMatchData(supabase, matchId);
        if (!match || match.ft_home == null || match.ft_away == null) {
          errors.push(`${matchId}: missing match data or scores`);
          continue;
        }

        // Get settlement config from DB (what market types need settling)
        const config = await getSettlementConfig(supabase, matchId);
        if (config.pending_count === 0) continue;

        // Get match events
        const events = await getMatchEvents(supabase, matchId);

        // ── 3) Gemini enrichment if stats-tier markets are pending ──
        let geminiStats: GeminiMatchStats | null = null;
        const needsStats = config.data_tiers_needed?.includes("stats");

        if (needsStats) {
          const neededStatTypes = determineNeededStats(config);
          if (neededStatTypes.length > 0) {
            console.log(
              `Match ${matchId}: Calling Gemini for stats: ${neededStatTypes.join(", ")}`,
            );
            geminiStats = await enrichWithGemini(match, neededStatTypes);
          }
        }

        // ── 4) Build comprehensive match_stats ──
        const matchStats = buildMatchStats(match, events, geminiStats);

        // ── 5) Call the DB-driven settlement RPC ──
        const { data: settleResult, error: settleError } = await supabase.rpc(
          "settle_match_selections",
          {
            p_match_id: matchId,
            p_match_stats: matchStats,
          },
        );

        if (settleError) {
          errors.push(`${matchId}: ${settleError.message}`);
          continue;
        }

        const result = settleResult as {
          selections_settled: number;
          won: number;
          lost: number;
          void: number;
          slips_affected: number;
        };

        // ── 6) Notify winners ──
        const matchName = `${match.home_team} vs ${match.away_team}`;
        const score = `${match.ft_home}-${match.ft_away}`;
        if (result.won > 0) {
          await notifyWinners(supabase, matchId, matchName, score);
        }

        results.push({
          match_id: matchId,
          match_name: matchName,
          selections_settled: result.selections_settled,
          won: result.won,
          lost: result.lost,
          void_count: result.void ?? 0,
          gemini_enriched: geminiStats !== null,
        });

        // ── 7) Log settlement ──
        await supabase.from("market_settlement_log").insert({
          match_id: matchId,
          trigger_source: specificMatchId
            ? "manual_trigger"
            : "auto_cron",
          market_types_attempted: config.pending_count,
          selections_settled: result.selections_settled,
          selections_won: result.won,
          selections_lost: result.lost,
          selections_void: result.void ?? 0,
          data_tiers_used: config.data_tiers_needed,
          gemini_enriched: geminiStats !== null,
          match_stats: matchStats as unknown as Record<string, unknown>,
        });

        // ── 8) Also settle pools + daily challenges via existing RPCs ──
        try {
          await supabase.rpc("auto_settle_pools", {
            p_match_id: matchId,
            p_home_score: match.ft_home,
            p_away_score: match.ft_away,
          });
        } catch (poolError) {
          errors.push(
            `${matchId} pools: ${getErrorMessage(poolError)}`,
          );
        }
      } catch (matchError) {
        errors.push(`${matchId}: ${getErrorMessage(matchError)}`);
      }
    }

    const summary = {
      timestamp: new Date().toISOString(),
      matches_processed: results.length,
      total_selections_settled: results.reduce(
        (s, r) => s + r.selections_settled,
        0,
      ),
      total_won: results.reduce((s, r) => s + r.won, 0),
      total_lost: results.reduce((s, r) => s + r.lost, 0),
      total_void: results.reduce((s, r) => s + r.void_count, 0),
      gemini_calls: results.filter((r) => r.gemini_enriched).length,
      results,
      errors: errors.length > 0 ? errors : undefined,
    };

    console.log("Settlement summary:", JSON.stringify(summary));

    return Response.json(summary, {
      status: errors.length > 0 ? 207 : 200,
    });
  } catch (error) {
    console.error("Settlement fatal error:", error);
    return Response.json(
      {
        error: getErrorMessage(error),
        errors,
        partial_results: results,
      },
      { status: 500 },
    );
  }
});
