import { DEFAULT_GEMINI_MODEL, FUNCTION_NAME } from "./constants.ts";
import { fetchStructuredMatchData } from "./gemini.ts";
import {
  assertAuthorized,
  corsHeaders,
  jsonResponse,
  logUnhandledError,
  mapError,
  readJsonBody,
} from "./http.ts";
import { buildMatchPatch, dedupeEvents, getEventSignature } from "./match.ts";
import { parseRequestPayload } from "./payload.ts";
import {
  getMatchSnapshot,
  getSupabaseAdminClient,
  loadExistingLiveEvents,
  updateMatchSnapshot,
  upsertLiveEvents,
  upsertMatchOddsCache,
} from "./repo.ts";
import type {
  MatchEventsPayload,
  MatchOdds,
  PendingLiveMatchEventRow,
} from "./types.ts";

async function handleEventsRequest(
  payload: ReturnType<typeof parseRequestPayload>,
  requestId: string,
) {
  const supabase = getSupabaseAdminClient();
  const geminiResult = await fetchStructuredMatchData(payload);
  const eventPayload = geminiResult.data as MatchEventsPayload;
  const match = await getMatchSnapshot(supabase, payload.matchId);
  const existingEvents = await loadExistingLiveEvents(
    supabase,
    payload.matchId,
  );
  const existingSignatures = new Set(existingEvents.map(getEventSignature));

  const rows: PendingLiveMatchEventRow[] = eventPayload.events.map((event) => ({
    ...event,
    match_id: payload.matchId,
  }));
  const newRows = rows.filter((row) =>
    !existingSignatures.has(
      getEventSignature({
        minute: row.minute,
        event_type: row.event_type,
        team: row.team,
        player: row.player,
        details: row.details,
      }),
    )
  );

  const mergedEvents = dedupeEvents([
    ...existingEvents,
    ...eventPayload.events,
  ]);
  const matchPatch = buildMatchPatch(match, {
    ...eventPayload,
    events: mergedEvents,
  });
  const updatedMatch = matchPatch
    ? await updateMatchSnapshot(supabase, payload.matchId, matchPatch)
    : null;

  if (newRows.length === 0) {
    return jsonResponse(200, {
      success: true,
      requestId,
      fetchType: payload.fetchType,
      matchId: payload.matchId,
      geminiModel: DEFAULT_GEMINI_MODEL,
      insertedCount: 0,
      currentState: {
        match_status: eventPayload.match_status,
        home_score: eventPayload.home_score,
        away_score: eventPayload.away_score,
      },
      match: updatedMatch,
      grounding: geminiResult.grounding,
    });
  }

  const insertedEvents = await upsertLiveEvents(supabase, newRows);

  return jsonResponse(200, {
    success: true,
    requestId,
    fetchType: payload.fetchType,
    matchId: payload.matchId,
    geminiModel: DEFAULT_GEMINI_MODEL,
    insertedCount: insertedEvents?.length ?? newRows.length,
    events: insertedEvents ?? newRows,
    currentState: {
      match_status: eventPayload.match_status,
      home_score: eventPayload.home_score,
      away_score: eventPayload.away_score,
    },
    match: updatedMatch,
    grounding: geminiResult.grounding,
  });
}

async function handleOddsRequest(
  payload: ReturnType<typeof parseRequestPayload>,
  requestId: string,
) {
  const supabase = getSupabaseAdminClient();
  await getMatchSnapshot(supabase, payload.matchId);

  const geminiResult = await fetchStructuredMatchData(payload);
  const odds = geminiResult.data as MatchOdds;
  const cacheRow = await upsertMatchOddsCache(supabase, payload.matchId, odds, {
    grounding: geminiResult.grounding,
    rawText: geminiResult.rawText,
  });

  return jsonResponse(200, {
    success: true,
    requestId,
    fetchType: payload.fetchType,
    matchId: payload.matchId,
    geminiModel: DEFAULT_GEMINI_MODEL,
    odds: cacheRow,
    grounding: geminiResult.grounding,
  });
}

export async function handleGeminiSportsDataRequest(req: Request) {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      success: false,
      requestId,
      error: "Method not allowed. Use POST.",
    });
  }

  try {
    assertAuthorized(req);
    const payload = parseRequestPayload(await readJsonBody(req));

    if (payload.fetchType === "events") {
      return await handleEventsRequest(payload, requestId);
    }

    return await handleOddsRequest(payload, requestId);
  } catch (error) {
    const mapped = mapError(error, requestId);
    logUnhandledError(requestId, error);
    return jsonResponse(mapped.status, mapped.body);
  }
}
