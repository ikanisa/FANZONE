import { DEFAULT_GEMINI_MODEL, PROVIDER_NAME } from "./constants.ts";
import { fetchStructuredMatchData } from "./gemini.ts";
import {
  assertAuthorized,
  corsHeaders,
  jsonResponse,
  logUnhandledError,
  mapError,
  readJsonBody,
} from "./http.ts";
import {
  buildCanonicalEventRows,
  buildLiveEventRows,
  buildMatchPatch,
  dedupeEvents,
  detectScoreRegression,
  getEventSignature,
  toDatabaseMatchStatus,
} from "./match.ts";
import { parseRequestPayload } from "./payload.ts";
import {
  attachCanonicalEventIdsToLiveEvents,
  createLiveUpdateRun,
  finalizeLiveUpdateRun,
  getMatchLiveStateSnapshot,
  getMatchSnapshot,
  getSupabaseAdminClient,
  loadCanonicalMatchEventsBySignatures,
  loadExistingLiveEvents,
  loadRuntimeSettings,
  loadTrustedMatchSources,
  updateMatchSnapshot,
  upsertCanonicalMatchEvents,
  upsertLiveEvents,
  upsertMatchLiveState,
  upsertMatchOddsCache,
} from "./repo.ts";
import {
  enrichGroundingSummary,
  evaluateMatchUpdateConfidence,
} from "./scoring.ts";
import type { MatchEventsPayload, MatchOdds } from "./types.ts";

function addSeconds(iso: string, seconds: number) {
  return new Date(Date.parse(iso) + seconds * 1000).toISOString();
}

function normalizeStoredStatus(value: string | null | undefined): string {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  return normalized || "unknown";
}

function computeNextCheckAt(
  nowIso: string,
  matchStatus: MatchEventsPayload["match_status"],
  validationStatus: "confirmed" | "low_confidence" | "manual_review",
  settings: {
    live_poll_interval_seconds: number;
    low_confidence_backoff_seconds: number;
    failed_backoff_seconds: number;
  },
) {
  if (
    matchStatus === "FINISHED" || matchStatus === "POSTPONED" ||
    matchStatus === "CANCELLED"
  ) {
    return null;
  }

  if (validationStatus === "confirmed") {
    return addSeconds(nowIso, settings.live_poll_interval_seconds);
  }

  if (validationStatus === "low_confidence") {
    return addSeconds(nowIso, settings.low_confidence_backoff_seconds);
  }

  return addSeconds(nowIso, settings.failed_backoff_seconds);
}

async function handleEventsRequest(
  payload: ReturnType<typeof parseRequestPayload>,
  requestId: string,
) {
  const supabase = getSupabaseAdminClient();
  const match = await getMatchSnapshot(supabase, payload.matchId);
  const existingLiveState = await getMatchLiveStateSnapshot(
    supabase,
    payload.matchId,
  );
  const settings = await loadRuntimeSettings(supabase);
  const trustedSources = await loadTrustedMatchSources(supabase);
  const nowIso = new Date().toISOString();
  const runId = await createLiveUpdateRun(
    supabase,
    payload.matchId,
    payload as unknown as Record<string, unknown>,
    DEFAULT_GEMINI_MODEL,
  );

  try {
    const geminiResult = await fetchStructuredMatchData(payload);
    const grounded = enrichGroundingSummary(
      geminiResult.grounding,
      trustedSources,
    );
    const eventPayload = geminiResult.data as MatchEventsPayload;
    const validation = evaluateMatchUpdateConfidence(eventPayload, grounded);
    const nextCheckAt = computeNextCheckAt(
      nowIso,
      eventPayload.match_status,
      validation.status,
      settings,
    );
    const dedupedEvents = dedupeEvents(eventPayload.events);
    const sourcePayload = {
      rawText: geminiResult.rawText,
      summary: eventPayload.summary,
      uncertainty_notes: eventPayload.uncertainty_notes,
      grounding: grounded,
    };
    const nextStatus = toDatabaseMatchStatus(eventPayload.match_status) ??
      normalizeStoredStatus(existingLiveState?.status ?? match.status);

    // Detect score regression before publishing
    const scoreRegression = detectScoreRegression(match, eventPayload);
    const effectiveReviewRequired = validation.status !== "confirmed" ||
      scoreRegression.regressed;
    const effectiveReviewReason = scoreRegression.regressed
      ? scoreRegression.reason
      : validation.review_reason;
    const effectiveConfidenceStatus = scoreRegression.regressed
      ? "manual_review" as const
      : validation.status;

    await upsertMatchLiveState(supabase, {
      match_id: payload.matchId,
      status: nextStatus,
      minute: eventPayload.minute,
      phase: eventPayload.phase.toLowerCase(),
      home_score: scoreRegression.regressed
        ? (existingLiveState?.home_score ?? match.live_home_score ??
          eventPayload.home_score)
        : eventPayload.home_score,
      away_score: scoreRegression.regressed
        ? (existingLiveState?.away_score ?? match.live_away_score ??
          eventPayload.away_score)
        : eventPayload.away_score,
      confidence_score: validation.confidence_score,
      confidence_status: effectiveConfidenceStatus,
      review_required: effectiveReviewRequired,
      review_reason: effectiveReviewReason,
      provider: PROVIDER_NAME,
      last_checked_at: nowIso,
      last_success_at: validation.status === "confirmed" &&
          !scoreRegression.regressed
        ? nowIso
        : existingLiveState?.last_success_at ?? null,
      next_check_at: nextCheckAt,
      last_event_count: dedupedEvents.length,
      last_error: effectiveReviewRequired ? effectiveReviewReason : null,
      consecutive_failures: 0,
      grounding_sources: grounded.sources as unknown as Array<
        Record<string, unknown>
      >,
      source_payload: sourcePayload,
      updated_at: nowIso,
    });

    let updatedMatch: Record<string, unknown> | null = null;
    let insertedLiveEventCount = 0;
    let insertedMatchEventCount = 0;

    if (validation.status === "confirmed" && !scoreRegression.regressed) {
      const existingEvents = await loadExistingLiveEvents(
        supabase,
        payload.matchId,
      );
      const existingSignatures = new Set(existingEvents.map(getEventSignature));
      const newEvents = dedupedEvents.filter((event) =>
        !existingSignatures.has(getEventSignature(event))
      );

      const canonicalRows = buildCanonicalEventRows(
        match,
        dedupedEvents,
        validation.confidence_score,
        sourcePayload,
      );
      const liveRows = buildLiveEventRows(
        payload.matchId,
        newEvents,
        validation.confidence_score,
        sourcePayload,
      );

      const canonicalEvents = await upsertCanonicalMatchEvents(
        supabase,
        canonicalRows,
      );
      await upsertLiveEvents(supabase, liveRows);

      insertedLiveEventCount = newEvents.length;
      const canonicalEventsBySignature =
        await loadCanonicalMatchEventsBySignatures(
          supabase,
          payload.matchId,
          dedupedEvents.map(getEventSignature),
        );
      insertedMatchEventCount = canonicalEvents?.length ?? 0;

      if (canonicalEventsBySignature.length > 0) {
        await attachCanonicalEventIdsToLiveEvents(
          supabase,
          payload.matchId,
          dedupedEvents,
          canonicalEventsBySignature,
        );
      }

      const matchPatch = buildMatchPatch(
        match,
        {
          ...eventPayload,
          events: dedupedEvents,
        },
        nowIso,
        validation.confidence_score,
        false,
      );

      if (matchPatch) {
        updatedMatch = await updateMatchSnapshot(
          supabase,
          payload.matchId,
          matchPatch,
        );
      }
    }

    await finalizeLiveUpdateRun(supabase, runId, {
      status: scoreRegression.regressed
        ? "manual_review"
        : validation.status === "confirmed"
        ? "completed"
        : validation.status,
      confidence_score: validation.confidence_score,
      detected_status: eventPayload.match_status.toLowerCase(),
      detected_phase: eventPayload.phase.toLowerCase(),
      detected_minute: eventPayload.minute,
      inserted_live_event_count: insertedLiveEventCount,
      inserted_match_event_count: insertedMatchEventCount,
      updated_match: updatedMatch != null,
      review_reason: effectiveReviewReason,
      response_payload: {
        payload: eventPayload,
        validation,
        grounding: grounded,
      },
      grounding_sources: grounded.sources,
      search_queries: grounded.webSearchQueries,
    });

    return jsonResponse(200, {
      success: true,
      requestId,
      fetchType: payload.fetchType,
      matchId: payload.matchId,
      geminiModel: DEFAULT_GEMINI_MODEL,
      insertedCount: insertedLiveEventCount,
      canonicalInsertedCount: insertedMatchEventCount,
      reviewRequired: effectiveReviewRequired,
      confidence: validation,
      currentState: {
        match_status: eventPayload.match_status,
        phase: eventPayload.phase,
        minute: eventPayload.minute,
        home_score: eventPayload.home_score,
        away_score: eventPayload.away_score,
        checked_at: nowIso,
      },
      match: updatedMatch,
      grounding: grounded,
      runId,
    });
  } catch (error) {
    const failureCount = (existingLiveState?.consecutive_failures ?? 0) + 1;
    await upsertMatchLiveState(supabase, {
      match_id: payload.matchId,
      status: normalizeStoredStatus(existingLiveState?.status ?? match.status),
      minute: existingLiveState?.minute ?? match.live_minute,
      phase: normalizeStoredStatus(
        existingLiveState?.phase ?? match.live_phase,
      ),
      home_score: existingLiveState?.home_score ?? match.live_home_score ??
        match.ft_home ?? 0,
      away_score: existingLiveState?.away_score ?? match.live_away_score ??
        match.ft_away ?? 0,
      confidence_score: 0,
      confidence_status: "manual_review",
      review_required: true,
      review_reason: error instanceof Error ? error.message : String(error),
      provider: PROVIDER_NAME,
      last_checked_at: nowIso,
      last_success_at: existingLiveState?.last_success_at ?? null,
      next_check_at: addSeconds(nowIso, settings.failed_backoff_seconds),
      last_event_count: 0,
      last_error: error instanceof Error ? error.message : String(error),
      consecutive_failures: failureCount,
      grounding_sources: [],
      source_payload: {
        request: payload,
        requestId,
        error: error instanceof Error ? error.message : String(error),
      },
      updated_at: nowIso,
    });
    await finalizeLiveUpdateRun(supabase, runId, {
      status: "failed",
      review_reason: error instanceof Error ? error.message : String(error),
      error_message: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
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
