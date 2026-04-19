import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";
import {
  buildGoalAlertBody,
  buildGoalAlertTitle,
  buildResultDispatchKey,
  type GoalEventRow,
  type MatchRow,
  singleMatch,
  uniqueUserIds,
} from "./dispatch.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";
const PUSH_NOTIFY_SECRET = Deno.env.get("PUSH_NOTIFY_SECRET")?.trim() || "";
const PUSH_NOTIFY_URL = `${SUPABASE_URL}/functions/v1/push-notify`;

interface KickoffSubscriptionRow {
  user_id: string;
  match_id: string;
  matches: MatchRow | MatchRow[] | null;
}

interface ResultSubscriptionRow extends KickoffSubscriptionRow {
  matches:
    | (MatchRow & { ft_home: number | null; ft_away: number | null })
    | (MatchRow & { ft_home: number | null; ft_away: number | null })[]
    | null;
}

interface GoalSubscriptionRow {
  user_id: string;
  match_id: string;
}

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

Deno.serve(async (req: Request) => {
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

  const summary = {
    kickoff_sent: 0,
    goal_sent: 0,
    result_sent: 0,
    dispatch_rows_written: 0,
    errors: [] as string[],
  };

  try {
    const now = Date.now();
    const kickoffStart = new Date(now - 10 * 60 * 1000).toISOString();
    const kickoffEnd = new Date(now + 15 * 60 * 1000).toISOString();
    const recentEventStart = new Date(now - 20 * 60 * 1000).toISOString();

    // Kickoff alerts
    try {
      const { data } = await supabase
        .from("match_alert_subscriptions")
        .select(`
          user_id,
          match_id,
          matches!inner (
            id,
            date,
            status,
            home_team,
            away_team
          )
        `)
        .eq("alert_kickoff", true)
        .gte("matches.date", kickoffStart)
        .lte("matches.date", kickoffEnd);

      const rows = (data || []) as KickoffSubscriptionRow[];
      const grouped = new Map<string, { match: MatchRow; userIds: string[] }>();

      for (const row of rows) {
        const match = singleMatch(row.matches);
        if (!match || match.status === "finished") continue;
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

    // Goal alerts
    try {
      const { data: goalEvents } = await supabase
        .from("live_match_events")
        .select("id, match_id, minute, team, player, details, created_at")
        .eq("event_type", "GOAL")
        .gte("created_at", recentEventStart)
        .order("created_at", { ascending: true });

      const events = (goalEvents || []) as GoalEventRow[];
      const matchIds = [...new Set(events.map((event) => event.match_id))];

      if (matchIds.length) {
        const { data: subscriptions } = await supabase
          .from("match_alert_subscriptions")
          .select("user_id, match_id")
          .eq("alert_goals", true)
          .in("match_id", matchIds);

        const subscriptionsByMatch = new Map<string, string[]>();
        for (const row of (subscriptions || []) as GoalSubscriptionRow[]) {
          const users = subscriptionsByMatch.get(row.match_id) || [];
          users.push(row.user_id);
          subscriptionsByMatch.set(row.match_id, users);
        }

        for (const event of events) {
          const userIds = uniqueUserIds(
            subscriptionsByMatch.get(event.match_id) || [],
          );
          if (!userIds.length) continue;

          const { data: existing } = await supabase
            .from("match_alert_dispatch_log")
            .select("user_id")
            .eq("match_id", event.match_id)
            .eq("alert_type", "goal")
            .eq("dispatch_key", event.id);

          const sentUsers = new Set((existing || []).map((row) => row.user_id));
          const nextUsers = userIds.filter((userId) => !sentUsers.has(userId));
          if (!nextUsers.length) continue;

          summary.goal_sent += await pushToUsers(
            nextUsers,
            "match_goal",
            buildGoalAlertTitle(event),
            buildGoalAlertBody(event),
            {
              match_id: event.match_id,
              screen: `/match/${event.match_id}`,
            },
          );

          await supabase.from("match_alert_dispatch_log").upsert(
            nextUsers.map((userId) => ({
              user_id: userId,
              match_id: event.match_id,
              alert_type: "goal",
              dispatch_key: event.id,
              live_event_id: event.id,
              payload: {
                minute: event.minute,
                team: event.team,
                player: event.player,
                details: event.details,
              },
            })),
            {
              onConflict: "user_id,match_id,alert_type,dispatch_key",
              ignoreDuplicates: true,
            },
          );
          summary.dispatch_rows_written += nextUsers.length;
        }
      }
    } catch (error) {
      summary.errors.push(`goal: ${getErrorMessage(error)}`);
    }

    // Result alerts
    try {
      const { data } = await supabase
        .from("match_alert_subscriptions")
        .select(`
          user_id,
          match_id,
          matches!inner (
            id,
            date,
            status,
            home_team,
            away_team,
            ft_home,
            ft_away
          )
        `)
        .eq("alert_result", true)
        .eq("matches.status", "finished")
        .not("matches.ft_home", "is", null)
        .not("matches.ft_away", "is", null);

      const rows = (data || []) as ResultSubscriptionRow[];
      const grouped = new Map<string, { match: MatchRow; userIds: string[] }>();

      for (const row of rows) {
        const match = singleMatch(row.matches);
        if (!match || match.ft_home == null || match.ft_away == null) continue;
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
