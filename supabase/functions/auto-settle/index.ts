// FANZONE — Auto-Settlement Edge Function
// Settles all eligible pools and prediction slips for finished matches.
//
// Triggered by:
//   - pg_cron every 15 minutes (via pg_net)
//   - GitHub Actions cron fallback
//   - Manual admin invocation
//
// Auth: x-cron-secret.
// Internal push dispatch uses x-push-notify-secret.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET") || "";
const PUSH_NOTIFY_SECRET = Deno.env.get("PUSH_NOTIFY_SECRET")?.trim() || "";
const PUSH_NOTIFY_URL = `${SUPABASE_URL}/functions/v1/push-notify`;

interface SettlementResult {
  match_id: string;
  match_name: string;
  pools_settled: number;
  slips_settled: number;
  notifications_sent: number;
}

interface MatchRow {
  id: string;
  status: string;
  ft_home: number | null;
  ft_away: number | null;
  home_team: string | null;
  away_team: string | null;
}

interface UnsettledPoolRow {
  id: string;
  match_id: string;
  match_name: string | null;
  status: string;
  matches: MatchRow | MatchRow[] | null;
}

interface RpcSettlementSummary {
  pools_settled?: number;
  selections_settled?: number;
  total_winners?: number;
}

interface WinnerRow {
  user_id: string;
}

interface DailyChallengeRow {
  id: string;
  match_id: string;
  date: string;
}

function buildInternalHeaders(secretHeaderName?: string, secretValue?: string) {
  const headers = new Headers({ "Content-Type": "application/json" });

  if (secretHeaderName && secretValue && secretValue.length > 0) {
    headers.set(secretHeaderName, secretValue);
  }

  return headers;
}

function getSingleMatch(value: UnsettledPoolRow["matches"]): MatchRow | null {
  if (Array.isArray(value)) {
    return value[0] ?? null;
  }

  return value ?? null;
}

Deno.serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders("authorization, content-type, x-cron-secret"),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
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
    // ── 1) Find finished matches with unsettled pools ──
    // Matches finished in the last 48h that still have open/locked pools
    const { data: unsettledPools, error: poolQueryError } = await supabase
      .from("prediction_challenges")
      .select(`
        id,
        match_id,
        match_name,
        status,
        matches!inner (
          id,
          status,
          ft_home,
          ft_away,
          home_team,
          away_team
        )
      `)
      .in("status", ["open", "locked"])
      .not("matches.ft_home", "is", null)
      .not("matches.ft_away", "is", null);

    if (poolQueryError) {
      console.error("Pool query error:", poolQueryError);
      errors.push(`Pool query: ${poolQueryError.message}`);
    }

    // Group by match
    const matchPools = new Map<string, {
      match_id: string;
      match_name: string;
      ft_home: number;
      ft_away: number;
      pool_ids: string[];
    }>();

    for (const pool of (unsettledPools || []) as UnsettledPoolRow[]) {
      const match = getSingleMatch(pool.matches);
      if (match?.ft_home == null || match?.ft_away == null) continue;

      const key = pool.match_id;
      if (!matchPools.has(key)) {
        matchPools.set(key, {
          match_id: pool.match_id,
          match_name: pool.match_name ||
            `${match.home_team} vs ${match.away_team}`,
          ft_home: match.ft_home,
          ft_away: match.ft_away,
          pool_ids: [],
        });
      }
      matchPools.get(key)!.pool_ids.push(pool.id);
    }

    // ── 2) Settle each match's pools ──
    for (const [matchId, info] of matchPools) {
      try {
        const { data: settleResult, error: settleError } = await supabase.rpc(
          "auto_settle_pools",
          {
            p_match_id: matchId,
            p_home_score: info.ft_home,
            p_away_score: info.ft_away,
          },
        );

        if (settleError) {
          errors.push(`Settle pools for ${matchId}: ${settleError.message}`);
          continue;
        }

        const poolsSettled = (settleResult as RpcSettlementSummary | null)
          ?.pools_settled || 0;

        // ── 3) Settle prediction slips for the same match ──
        let slipsSettled = 0;
        try {
          const { data: slipResult } = await supabase.rpc(
            "settle_prediction_slips_for_match",
            {
              p_match_id: matchId,
              p_official_home_score: info.ft_home,
              p_official_away_score: info.ft_away,
            },
          );
          slipsSettled = (slipResult as RpcSettlementSummary | null)
            ?.selections_settled || 0;
        } catch (slipError: unknown) {
          errors.push(
            `Settle slips for ${matchId}: ${getErrorMessage(slipError)}`,
          );
        }

        // ── 4) Notify winners ──
        let notifsSent = 0;
        if (poolsSettled > 0) {
          try {
            // Get winner user IDs from recently settled entries
            const { data: winners } = await supabase
              .from("prediction_challenge_entries")
              .select("user_id")
              .in(
                "challenge_id",
                info.pool_ids,
              )
              .eq("status", "won");

            if (winners?.length) {
              const winnerIds = [
                ...new Set(
                  (winners as WinnerRow[]).map((winner) => winner.user_id),
                ),
              ];

              const pushResponse = await fetch(PUSH_NOTIFY_URL, {
                method: "POST",
                headers: buildInternalHeaders(
                  "x-push-notify-secret",
                  PUSH_NOTIFY_SECRET,
                ),
                body: JSON.stringify({
                  user_ids: winnerIds,
                  type: "pool_settled",
                  title: "🎉 You won!",
                  body:
                    `Your prediction for ${info.match_name} (${info.ft_home}-${info.ft_away}) was correct!`,
                  data: { match_id: matchId, screen: "/predict" },
                }),
              });

              if (!pushResponse.ok) {
                errors.push(
                  `Notify for ${matchId}: push-notify returned ${pushResponse.status} ${await pushResponse
                    .text()}`,
                );
              } else {
                const pushSummary = await pushResponse.json().catch(() =>
                  null
                ) as
                  | { sent?: number }
                  | null;
                notifsSent = pushSummary?.sent ?? winnerIds.length;
              }
            }
          } catch (notificationError: unknown) {
            errors.push(
              `Notify for ${matchId}: ${getErrorMessage(notificationError)}`,
            );
          }
        }

        results.push({
          match_id: matchId,
          match_name: info.match_name,
          pools_settled: poolsSettled,
          slips_settled: slipsSettled,
          notifications_sent: notifsSent,
        });
      } catch (matchError: unknown) {
        errors.push(`Match ${matchId}: ${getErrorMessage(matchError)}`);
      }
    }

    // ── 5) Settle daily challenges (if match finished) ──
    try {
      const today = new Date().toISOString().substring(0, 10);
      const yesterday = new Date(Date.now() - 86400000)
        .toISOString()
        .substring(0, 10);

      const { data: activeChallenges } = await supabase
        .from("daily_challenges")
        .select("id, match_id, date")
        .eq("status", "active")
        .gte("date", yesterday)
        .lte("date", today);

      for (const challenge of (activeChallenges || []) as DailyChallengeRow[]) {
        // Check if the match is finished
        const { data: match } = await supabase
          .from("matches")
          .select("ft_home, ft_away, status")
          .eq("id", challenge.match_id)
          .single();

        if (match?.ft_home != null && match?.ft_away != null) {
          const { data: settleResult, error: settleErr } = await supabase.rpc(
            "settle_daily_challenge",
            {
              p_challenge_id: challenge.id,
              p_home_score: match.ft_home,
              p_away_score: match.ft_away,
            },
          );

          if (settleErr) {
            errors.push(
              `Daily challenge ${challenge.id}: ${settleErr.message}`,
            );
          } else {
            results.push({
              match_id: challenge.match_id,
              match_name: `Daily Challenge ${challenge.date}`,
              pools_settled: 0,
              slips_settled: 0,
              notifications_sent:
                (settleResult as RpcSettlementSummary | null)?.total_winners ||
                0,
            });
          }
        }
      }
    } catch (dailyChallengeError: unknown) {
      errors.push(
        `Daily challenges: ${getErrorMessage(dailyChallengeError)}`,
      );
    }

    const summary = {
      timestamp: new Date().toISOString(),
      matches_processed: results.length,
      total_pools_settled: results.reduce((s, r) => s + r.pools_settled, 0),
      total_slips_settled: results.reduce((s, r) => s + r.slips_settled, 0),
      total_notifications: results.reduce(
        (s, r) => s + r.notifications_sent,
        0,
      ),
      results,
      errors: errors.length > 0 ? errors : undefined,
    };

    console.log("Auto-settle summary:", JSON.stringify(summary));

    return Response.json(summary, {
      status: errors.length > 0 ? 207 : 200,
    });
  } catch (error: unknown) {
    console.error("Auto-settle fatal error:", error);
    return Response.json(
      { error: getErrorMessage(error), errors, partial_results: results },
      { status: 500 },
    );
  }
});
