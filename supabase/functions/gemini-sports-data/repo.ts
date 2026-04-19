import { createClient } from "jsr:@supabase/supabase-js@2";

import { HttpError, requireEnv } from "./http.ts";
import type {
  MatchEvent,
  MatchOdds,
  MatchPatch,
  MatchSnapshot,
  PendingLiveMatchEventRow,
} from "./types.ts";

// This repo does not ship generated database types for Edge Functions yet,
// so keep the client boundary explicit instead of leaking `never` through the
// query chain.
type SupabaseAdminClient = any;

export function getSupabaseAdminClient() {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export async function getMatchSnapshot(
  supabase: SupabaseAdminClient,
  matchId: string,
): Promise<MatchSnapshot> {
  const { data, error } = await supabase
    .from("matches")
    .select("id, home_team, away_team, status, ft_home, ft_away")
    .eq("id", matchId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load match metadata.", error);
  }

  if (!data) {
    throw new HttpError(404, `Match ${matchId} was not found.`);
  }

  return data as MatchSnapshot;
}

export async function loadExistingLiveEvents(
  supabase: SupabaseAdminClient,
  matchId: string,
): Promise<MatchEvent[]> {
  const { data, error } = await supabase
    .from("live_match_events")
    .select("minute, event_type, team, player, details")
    .eq("match_id", matchId);

  if (error) {
    throw new HttpError(
      500,
      "Failed to load existing live match events.",
      error,
    );
  }

  return (data ?? []).map((row: Record<string, unknown>) => ({
    minute: Number(row.minute ?? 0),
    event_type: String(row.event_type ?? "") as MatchEvent["event_type"],
    team: String(row.team ?? ""),
    player: String(row.player ?? ""),
    details: String(row.details ?? ""),
  }));
}

export async function updateMatchSnapshot(
  supabase: SupabaseAdminClient,
  matchId: string,
  matchPatch: MatchPatch,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await supabase
    .from("matches")
    .update(matchPatch)
    .eq("id", matchId)
    .select("id, status, ft_home, ft_away, updated_at")
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to update live match snapshot.", {
      error,
      matchPatch,
    });
  }

  return data as Record<string, unknown> | null;
}

export async function upsertLiveEvents(
  supabase: SupabaseAdminClient,
  rows: PendingLiveMatchEventRow[],
): Promise<PendingLiveMatchEventRow[] | null> {
  const { data, error } = await supabase
    .from("live_match_events")
    .upsert(rows, {
      onConflict: "match_id,event_signature",
      ignoreDuplicates: true,
    })
    .select();

  if (error) {
    throw new HttpError(500, "Failed to insert live match events.", error);
  }

  return data as PendingLiveMatchEventRow[] | null;
}

export async function upsertMatchOddsCache(
  supabase: SupabaseAdminClient,
  matchId: string,
  odds: MatchOdds,
  sourcePayload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("match_odds_cache")
    .upsert({
      match_id: matchId,
      ...odds,
      provider: "google_gemini_search",
      source_payload: sourcePayload,
      refreshed_at: now,
      updated_at: now,
    }, {
      onConflict: "match_id",
    })
    .select()
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to upsert match odds cache.", error);
  }

  if (!data) {
    throw new HttpError(
      404,
      `Match ${matchId} was not found for odds update.`,
    );
  }

  return data as Record<string, unknown>;
}
