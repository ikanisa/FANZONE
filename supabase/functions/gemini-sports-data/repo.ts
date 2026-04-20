import { createClient } from "jsr:@supabase/supabase-js@2";

import type {
  CanonicalMatchEventRow,
  LiveStatePatch,
  MatchEvent,
  MatchOdds,
  MatchPatch,
  MatchSnapshot,
  PendingLiveMatchEventRow,
  RuntimeSettings,
  TrustedMatchSource,
} from "./types.ts";
import { HttpError, requireEnv } from "./http.ts";
import { getEventSignature } from "./match.ts";

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
    .select(
      [
        "id",
        "home_team",
        "away_team",
        "home_team_id",
        "away_team_id",
        "status",
        "ft_home",
        "ft_away",
        "live_home_score",
        "live_away_score",
        "live_minute",
        "live_phase",
        "source_url",
      ].join(", "),
    )
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
    .select("minute, event_type, team, player, details, source_payload")
    .eq("match_id", matchId);

  if (error) {
    throw new HttpError(
      500,
      "Failed to load existing live match events.",
      error,
    );
  }

  return (data ?? []).map((row: Record<string, unknown>) => {
    const sourcePayload =
      (row.source_payload as Record<string, unknown> | null) ??
        {};
    return {
      minute: Number(row.minute ?? 0),
      event_type: String(row.event_type ?? "") as MatchEvent["event_type"],
      team: String(row.team ?? ""),
      player: String(row.player ?? ""),
      assist_player: typeof sourcePayload["assist_player"] === "string"
        ? String(sourcePayload["assist_player"])
        : null,
      details: String(row.details ?? ""),
    };
  });
}

export async function loadRuntimeSettings(
  supabase: SupabaseAdminClient,
): Promise<RuntimeSettings> {
  const { data, error } = await supabase
    .from("match_sync_runtime_settings")
    .select(
      "live_poll_interval_seconds, low_confidence_backoff_seconds, failed_backoff_seconds",
    )
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load runtime settings.", error);
  }

  return {
    live_poll_interval_seconds: Number(
      data?.live_poll_interval_seconds ?? 60,
    ),
    low_confidence_backoff_seconds: Number(
      data?.low_confidence_backoff_seconds ?? 180,
    ),
    failed_backoff_seconds: Number(data?.failed_backoff_seconds ?? 300),
  };
}

export async function loadTrustedMatchSources(
  supabase: SupabaseAdminClient,
): Promise<TrustedMatchSource[]> {
  const { data, error } = await supabase
    .from("trusted_match_sources")
    .select("domain_pattern, source_name, source_type, trust_score, active")
    .eq("active", true)
    .order("trust_score", { ascending: false });

  if (error) {
    throw new HttpError(500, "Failed to load trusted match sources.", error);
  }

  return (data ?? []) as TrustedMatchSource[];
}

export async function getMatchLiveStateSnapshot(
  supabase: SupabaseAdminClient,
  matchId: string,
): Promise<
  {
    status: string | null;
    minute: number | null;
    phase: string | null;
    home_score: number | null;
    away_score: number | null;
    consecutive_failures: number;
    last_success_at: string | null;
  } | null
> {
  const { data, error } = await supabase
    .from("match_live_state")
    .select(
      "status, minute, phase, home_score, away_score, consecutive_failures, last_success_at",
    )
    .eq("match_id", matchId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load match live state.", error);
  }

  if (!data) {
    return null;
  }

  return {
    status: typeof data.status === "string" ? data.status : null,
    minute: data.minute == null
      ? null
      : Number.isFinite(Number(data.minute))
      ? Number(data.minute)
      : null,
    phase: typeof data.phase === "string" ? data.phase : null,
    home_score: data.home_score == null
      ? null
      : Number.isFinite(Number(data.home_score))
      ? Number(data.home_score)
      : null,
    away_score: data.away_score == null
      ? null
      : Number.isFinite(Number(data.away_score))
      ? Number(data.away_score)
      : null,
    consecutive_failures: Number(data.consecutive_failures ?? 0),
    last_success_at: typeof data.last_success_at === "string"
      ? data.last_success_at
      : null,
  };
}

export async function createLiveUpdateRun(
  supabase: SupabaseAdminClient,
  matchId: string,
  requestPayload: Record<string, unknown>,
  modelName: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("match_live_update_runs")
    .insert({
      match_id: matchId,
      request_payload: requestPayload,
      model_name: modelName,
      status: "running",
    })
    .select("id")
    .maybeSingle();

  if (error || !data?.id) {
    throw new HttpError(500, "Failed to create live update run.", error);
  }

  return String(data.id);
}

export async function finalizeLiveUpdateRun(
  supabase: SupabaseAdminClient,
  runId: string,
  patch: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("match_live_update_runs")
    .update({
      ...patch,
      finished_at: new Date().toISOString(),
    })
    .eq("id", runId);

  if (error) {
    throw new HttpError(500, "Failed to finalize live update run.", error);
  }
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
    .select(
      [
        "id",
        "status",
        "ft_home",
        "ft_away",
        "live_home_score",
        "live_away_score",
        "live_minute",
        "live_phase",
        "last_live_checked_at",
        "updated_at",
      ].join(", "),
    )
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to update live match snapshot.", {
      error,
      matchPatch,
    });
  }

  return data as Record<string, unknown> | null;
}

export async function upsertMatchLiveState(
  supabase: SupabaseAdminClient,
  patch: LiveStatePatch,
) {
  const { error } = await supabase
    .from("match_live_state")
    .upsert(
      {
        ...patch,
        created_at: patch.updated_at,
      },
      {
        onConflict: "match_id",
      },
    );

  if (error) {
    throw new HttpError(500, "Failed to upsert match live state.", error);
  }
}

export async function upsertLiveEvents(
  supabase: SupabaseAdminClient,
  rows: PendingLiveMatchEventRow[],
): Promise<PendingLiveMatchEventRow[] | null> {
  if (rows.length === 0) return [];

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

export async function upsertCanonicalMatchEvents(
  supabase: SupabaseAdminClient,
  rows: CanonicalMatchEventRow[],
): Promise<Array<{ id: string; event_signature: string }> | null> {
  if (rows.length === 0) return [];

  const { data, error } = await supabase
    .from("match_events")
    .upsert(rows, {
      onConflict: "match_id,event_signature",
      ignoreDuplicates: true,
    })
    .select("id, event_signature");

  if (error) {
    throw new HttpError(500, "Failed to upsert canonical match events.", error);
  }

  return data as Array<{ id: string; event_signature: string }> | null;
}

export async function loadCanonicalMatchEventsBySignatures(
  supabase: SupabaseAdminClient,
  matchId: string,
  eventSignatures: string[],
): Promise<Array<{ id: string; event_signature: string }>> {
  if (eventSignatures.length === 0) {
    return [];
  }

  const { data, error } = await supabase
    .from("match_events")
    .select("id, event_signature")
    .eq("match_id", matchId)
    .in("event_signature", eventSignatures);

  if (error) {
    throw new HttpError(500, "Failed to load canonical match events.", error);
  }

  return (data ?? []) as Array<{ id: string; event_signature: string }>;
}

export async function attachCanonicalEventIdsToLiveEvents(
  supabase: SupabaseAdminClient,
  matchId: string,
  events: MatchEvent[],
  canonicalEvents: Array<{ id: string; event_signature: string }>,
) {
  const bySignature = new Map(
    canonicalEvents.map((row) => [row.event_signature, row.id]),
  );

  for (const event of events) {
    const matchEventId = bySignature.get(getEventSignature(event));
    if (!matchEventId) {
      continue;
    }

    const { error } = await supabase
      .from("live_match_events")
      .update({
        match_event_id: matchEventId,
        updated_at: new Date().toISOString(),
      })
      .eq("match_id", matchId)
      .eq("event_signature", getEventSignature(event));

    if (error) {
      throw new HttpError(500, "Failed to attach canonical event ids.", error);
    }
  }
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
    .upsert(
      {
        match_id: matchId,
        ...odds,
        provider: "google_gemini_grounded",
        source_payload: sourcePayload,
        refreshed_at: now,
        updated_at: now,
      },
      {
        onConflict: "match_id",
      },
    )
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
