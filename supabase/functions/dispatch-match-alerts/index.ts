import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";
import {
  buildResultDispatchKey,
  type MatchRow,
  uniqueUserIds,
} from "./dispatch.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")?.trim() ||
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";
const PUSH_NOTIFY_SECRET = Deno.env.get("PUSH_NOTIFY_SECRET")?.trim() || "";
const PUSH_NOTIFY_URL = `${SUPABASE_URL}/functions/v1/push-notify`;

interface SubscriptionRow {
  user_id: string;
  match_id: string;
}

type AnySupabase = SupabaseClient<any, "public", any>;

function internalHeaders() {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (PUSH_NOTIFY_SECRET) {
    headers.set("x-push-notify-secret", PUSH_NOTIFY_SECRET);
  }
  return headers;
}

async function pushToUsers(
  userIds: string[],
  type: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  if (!userIds.length) return 0;

  const response = await fetch(PUSH_NOTIFY_URL, {
    method: "POST",
    headers: internalHeaders(),
    body: JSON.stringify({
      user_ids: userIds,
      type,
      title,
      body,
      data,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `push-notify returned ${response.status}: ${await response.text()}`,
    );
  }

  const summary = await response.json().catch(() => null) as
    | { sent?: number }
    | null;
  return summary?.sent ?? userIds.length;
}

async function loadMatchesByIds(
  supabase: AnySupabase,
  matchIds: string[],
) {
  if (!matchIds.length) return new Map<string, MatchRow>();

  const { data, error } = await supabase
    .from("app_matches")
    .select("id, date, status, home_team, away_team, ft_home, ft_away")
    .in("id", matchIds);

  if (error) {
    throw error;
  }

  return new Map(
    ((data || []) as MatchRow[]).map((match) => [match.id, match]),
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders("content-type, x-cron-secret"),
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

  const summary = {
    kickoff_sent: 0,
    goal_sent: 0,
    result_sent: 0,
    dispatch_rows_written: 0,
    errors: [] as string[],
  };

  try {
    const now = Date.now();
    const kickoffStart = new Date(now - 10 * 60 * 1000);
    const kickoffEnd = new Date(now + 15 * 60 * 1000);

    try {
      const { data } = await supabase
        .from("match_alert_subscriptions")
        .select("user_id, match_id")
        .eq("alert_kickoff", true);

      const rows = (data || []) as SubscriptionRow[];
      const matchMap = await loadMatchesByIds(
        supabase,
        [...new Set(rows.map((row) => row.match_id))],
      );

      const grouped = new Map<string, { match: MatchRow; userIds: string[] }>();
      for (const row of rows) {
        const match = matchMap.get(row.match_id);
        if (!match || !match.date) continue;

        const kickoffAt = new Date(match.date);
        if (
          Number.isNaN(kickoffAt.valueOf()) ||
          kickoffAt < kickoffStart ||
          kickoffAt > kickoffEnd ||
          match.status === "finished" ||
          match.status === "cancelled" ||
          match.status === "postponed"
        ) {
          continue;
        }

        const current = grouped.get(row.match_id);
        if (current) {
          current.userIds.push(row.user_id);
          continue;
        }
        grouped.set(row.match_id, { match, userIds: [row.user_id] });
      }

      for (const [matchId, value] of grouped.entries()) {
        const dispatchKey = `kickoff:${matchId}`;
        const userIds = uniqueUserIds(value.userIds);
        const { data: existing } = await supabase
          .from("match_alert_dispatch_log")
          .select("user_id")
          .eq("match_id", matchId)
          .eq("alert_type", "kickoff")
          .eq("dispatch_key", dispatchKey);

        const sentUsers = new Set((existing || []).map((row) => row.user_id));
        const nextUsers = userIds.filter((userId) => !sentUsers.has(userId));
        if (!nextUsers.length) continue;

        summary.kickoff_sent += await pushToUsers(
          nextUsers,
          "match_kickoff",
          "Kickoff soon",
          `${value.match.home_team} vs ${value.match.away_team} is about to start.`,
          { match_id: matchId, screen: `/match/${matchId}` },
        );

        await supabase.from("match_alert_dispatch_log").upsert(
          nextUsers.map((userId) => ({
            user_id: userId,
            match_id: matchId,
            alert_type: "kickoff",
            dispatch_key: dispatchKey,
            payload: { scheduled_for: value.match.date },
          })),
          {
            onConflict: "user_id,match_id,alert_type,dispatch_key",
            ignoreDuplicates: true,
          },
        );
        summary.dispatch_rows_written += nextUsers.length;
      }
    } catch (error) {
      summary.errors.push(`kickoff: ${getErrorMessage(error)}`);
    }

    try {
      const { data } = await supabase
        .from("match_alert_subscriptions")
        .select("user_id, match_id")
        .eq("alert_result", true);

      const rows = (data || []) as SubscriptionRow[];
      const matchMap = await loadMatchesByIds(
        supabase,
        [...new Set(rows.map((row) => row.match_id))],
      );

      const grouped = new Map<string, { match: MatchRow; userIds: string[] }>();
      for (const row of rows) {
        const match = matchMap.get(row.match_id);
        if (
          !match ||
          match.status !== "finished" ||
          match.ft_home == null ||
          match.ft_away == null
        ) {
          continue;
        }

        const current = grouped.get(row.match_id);
        if (current) {
          current.userIds.push(row.user_id);
          continue;
        }
        grouped.set(row.match_id, { match, userIds: [row.user_id] });
      }

      for (const [matchId, value] of grouped.entries()) {
        const dispatchKey = buildResultDispatchKey(value.match);
        const userIds = uniqueUserIds(value.userIds);
        const { data: existing } = await supabase
          .from("match_alert_dispatch_log")
          .select("user_id")
          .eq("match_id", matchId)
          .eq("alert_type", "result")
          .eq("dispatch_key", dispatchKey);

        const sentUsers = new Set((existing || []).map((row) => row.user_id));
        const nextUsers = userIds.filter((userId) => !sentUsers.has(userId));
        if (!nextUsers.length) continue;

        summary.result_sent += await pushToUsers(
          nextUsers,
          "match_result",
          "Final score",
          `${value.match.home_team} ${value.match.ft_home} - ${value.match.ft_away} ${value.match.away_team}`,
          { match_id: matchId, screen: `/match/${matchId}` },
        );

        await supabase.from("match_alert_dispatch_log").upsert(
          nextUsers.map((userId) => ({
            user_id: userId,
            match_id: matchId,
            alert_type: "result",
            dispatch_key: dispatchKey,
            payload: {
              home_score: value.match.ft_home,
              away_score: value.match.ft_away,
            },
          })),
          {
            onConflict: "user_id,match_id,alert_type,dispatch_key",
            ignoreDuplicates: true,
          },
        );
        summary.dispatch_rows_written += nextUsers.length;
      }
    } catch (error) {
      summary.errors.push(`result: ${getErrorMessage(error)}`);
    }

    return Response.json(summary, {
      headers: buildCorsHeaders("content-type"),
    });
  } catch (error) {
    return Response.json(
      { error: getErrorMessage(error), ...summary },
      { status: 500, headers: buildCorsHeaders("content-type") },
    );
  }
});
