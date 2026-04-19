import { FUNCTION_NAME } from "./constants.ts";
import { fetchCrestCandidate } from "./gemini.ts";
import {
  assertAuthorized,
  corsHeaders,
  jsonResponse,
  logUnhandledError,
  mapError,
  readJsonBody,
} from "./http.ts";
import { parseRequestPayload } from "./payload.ts";
import {
  createFetchRun,
  deleteStoredImage,
  downloadImage,
  finalizeFetchRun,
  getSupabaseAdminClient,
  loadExistingMetadata,
  loadTeamSnapshot,
  updateTeamCrestUrls,
  uploadImageToStorage,
  upsertCrestMetadata,
} from "./repo.ts";
import {
  evaluateCandidate,
  getNextRetryHours,
  getRefreshHours,
  shouldApplyToTeam,
} from "./scoring.ts";
import type {
  ExistingCrestMetadata,
  TeamCrestInput,
  TeamCrestOutput,
} from "./types.ts";

function addHours(iso: string, hours: number | null) {
  if (hours == null) return null;
  const date = new Date(iso);
  date.setHours(date.getHours() + hours);
  return date.toISOString();
}

function shouldSkipRefresh(
  existing: ExistingCrestMetadata | null,
  nowIso: string,
  refreshHours: number,
  force: boolean,
) {
  if (!existing || force) {
    return false;
  }

  if (
    existing.status === "failed" &&
    existing.next_retry_at &&
    existing.next_retry_at > nowIso
  ) {
    return true;
  }

  if (
    existing.status === "fetched" &&
    existing.stale_after &&
    existing.stale_after > nowIso
  ) {
    return true;
  }

  if (
    existing.status === "low_confidence" || existing.status === "manual_review"
  ) {
    const retryIso = addHours(existing.last_attempt_at ?? nowIso, refreshHours);
    if (retryIso && retryIso > nowIso) {
      return true;
    }
  }

  return false;
}

function buildTeamPatch(
  teamCrestUrl: string | null,
  teamLogoUrl: string | null,
  previousAutomatedImageUrl: string | null,
  nextImageUrl: string,
  forceApply: boolean,
) {
  const patch: Record<string, unknown> = {};

  if (
    shouldApplyToTeam(
      teamCrestUrl,
      previousAutomatedImageUrl,
      "fetched",
      forceApply,
    )
  ) {
    patch.crest_url = nextImageUrl;
  }

  if (
    shouldApplyToTeam(
      teamLogoUrl,
      previousAutomatedImageUrl,
      "fetched",
      forceApply,
    )
  ) {
    patch.logo_url = nextImageUrl;
  }

  return patch;
}

async function processSingleTeam(
  input: TeamCrestInput,
  options: ReturnType<typeof parseRequestPayload>["options"],
): Promise<TeamCrestOutput> {
  const supabase = getSupabaseAdminClient();
  const nowIso = new Date().toISOString();
  const team = await loadTeamSnapshot(supabase, input.team_id);
  const existing = await loadExistingMetadata(supabase, input.team_id);

  const mergedInput: TeamCrestInput = {
    team_id: input.team_id,
    team_name: input.team_name || team.name,
    competition: input.competition || team.league_name,
    country: input.country || team.country,
    aliases: Array.from(
      new Set([
        ...input.aliases,
        ...(team.short_name ? [team.short_name] : []),
      ]),
    ),
  };

  if (
    shouldSkipRefresh(
      existing,
      nowIso,
      options.refresh_if_older_than_hours,
      options.force,
    )
  ) {
    return {
      team_id: mergedInput.team_id,
      team_name: mergedInput.team_name,
      source_url: existing?.source_url ?? null,
      image_url: existing?.image_url ?? null,
      source_domain: existing?.source_domain ?? null,
      confidence_score: existing?.confidence_score ?? 0,
      fetched_at: nowIso,
      status: "skipped",
    };
  }

  const runId = await createFetchRun(supabase, mergedInput.team_id, {
    team: mergedInput,
    options,
  });

  try {
    const gemini = await fetchCrestCandidate(mergedInput);
    if (!gemini.parsed.selected_candidate) {
      throw new Error("Gemini did not return a crest candidate.");
    }

    const candidate = gemini.parsed.selected_candidate;
    const downloadedImage = await downloadImage(candidate.image_url);
    const validation = evaluateCandidate(
      mergedInput,
      candidate,
      gemini.grounding,
      downloadedImage,
    );

    let finalImageUrl = existing?.image_url ?? null;
    let storagePath = existing?.storage_path ?? null;
    let storageBucket = "team-crests";

    if (
      existing?.image_sha256 === downloadedImage.sha256 && existing.image_url
    ) {
      finalImageUrl = existing.image_url;
      storagePath = existing.storage_path;
    } else if (!options.dry_run) {
      const uploaded = await uploadImageToStorage(
        supabase,
        mergedInput.team_id,
        downloadedImage,
      );
      finalImageUrl = uploaded.publicUrl;
      storagePath = uploaded.path;
      storageBucket = uploaded.bucket;

      if (
        existing?.storage_path &&
        existing.storage_path !== uploaded.path
      ) {
        await deleteStoredImage(supabase, existing.storage_path);
      }
    } else {
      finalImageUrl = downloadedImage.final_url;
      storagePath = null;
    }

    const nextRetryAt = addHours(
      nowIso,
      getNextRetryHours(validation.status, existing?.retry_count ?? 0),
    );
    const staleAfter = validation.status === "fetched"
      ? addHours(nowIso, getRefreshHours(candidate.source_type))
      : null;

    const teamPatch = validation.status === "fetched" && options.apply_to_team
      ? buildTeamPatch(
        team.crest_url,
        team.logo_url,
        existing?.image_url ?? null,
        finalImageUrl!,
        options.force,
      )
      : {};

    if (!options.dry_run && Object.keys(teamPatch).length > 0) {
      await updateTeamCrestUrls(supabase, mergedInput.team_id, teamPatch);
    }

    await upsertCrestMetadata(supabase, {
      team_id: mergedInput.team_id,
      team_name: mergedInput.team_name,
      competition: mergedInput.competition,
      country: mergedInput.country,
      aliases: mergedInput.aliases,
      source_url: candidate.source_url,
      source_domain: candidate.source_domain ||
        new URL(candidate.source_url).host,
      remote_image_url: downloadedImage.final_url,
      image_url: finalImageUrl,
      storage_bucket: storageBucket,
      storage_path: storagePath,
      image_sha256: downloadedImage.sha256,
      source_type: candidate.source_type,
      confidence_score: validation.confidence_score,
      status: validation.status,
      validation_flags: validation.flags,
      validation_notes: validation.notes,
      matched_name: candidate.matched_name,
      matched_alias: candidate.matched_alias,
      match_reason: candidate.match_reason,
      model_name: gemini.model_name,
      fetch_count: (existing?.fetch_count ?? 0) + 1,
      retry_count: validation.status === "failed"
        ? (existing?.retry_count ?? 0) + 1
        : existing?.retry_count ?? 0,
      last_attempt_at: nowIso,
      next_retry_at: nextRetryAt,
      fetched_at: nowIso,
      stale_after: staleAfter,
      applied_to_team: Object.keys(teamPatch).length > 0,
      applied_at: Object.keys(teamPatch).length > 0 ? nowIso : null,
      last_error: null,
      source_payload: {
        candidate,
        alternatives: gemini.parsed.alternative_candidates,
        search_summary: gemini.parsed.search_summary,
        grounding: gemini.grounding,
      },
      updated_at: nowIso,
    });

    await finalizeFetchRun(supabase, runId, {
      status: validation.status === "fetched" ? "completed" : validation.status,
      confidence_score: validation.confidence_score,
      source_url: candidate.source_url,
      source_domain: candidate.source_domain ||
        new URL(candidate.source_url).host,
      image_url: finalImageUrl,
      model_name: gemini.model_name,
      validation_flags: validation.flags,
      response_payload: {
        candidate,
        alternatives: gemini.parsed.alternative_candidates,
        grounding: gemini.grounding,
      },
    });

    return {
      team_id: mergedInput.team_id,
      team_name: mergedInput.team_name,
      source_url: candidate.source_url,
      image_url: finalImageUrl,
      source_domain: candidate.source_domain ||
        new URL(candidate.source_url).host,
      confidence_score: validation.confidence_score,
      fetched_at: nowIso,
      status: validation.status,
    };
  } catch (error) {
    const failureMessage = error instanceof Error
      ? error.message
      : String(error);
    const nextRetryAt = addHours(
      nowIso,
      getNextRetryHours("failed", existing?.retry_count ?? 0),
    );

    await upsertCrestMetadata(supabase, {
      team_id: mergedInput.team_id,
      team_name: mergedInput.team_name,
      competition: mergedInput.competition,
      country: mergedInput.country,
      aliases: mergedInput.aliases,
      status: "failed",
      fetch_count: (existing?.fetch_count ?? 0) + 1,
      retry_count: (existing?.retry_count ?? 0) + 1,
      last_attempt_at: nowIso,
      next_retry_at: nextRetryAt,
      last_error: failureMessage,
      updated_at: nowIso,
    });

    await finalizeFetchRun(supabase, runId, {
      status: "failed",
      error_message: failureMessage,
      validation_flags: ["lookup_failed"],
    });

    return {
      team_id: mergedInput.team_id,
      team_name: mergedInput.team_name,
      source_url: null,
      image_url: null,
      source_domain: null,
      confidence_score: 0,
      fetched_at: nowIso,
      status: "failed",
    };
  }
}

function summarizeResults(results: TeamCrestOutput[]) {
  return results.reduce<Record<string, number>>((accumulator, result) => {
    accumulator[result.status] = (accumulator[result.status] ?? 0) + 1;
    return accumulator;
  }, {});
}

export async function handleGeminiTeamCrestsRequest(req: Request) {
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

    const results: TeamCrestOutput[] = [];
    for (let index = 0; index < payload.teams.length; index += 1) {
      results.push(
        await processSingleTeam(payload.teams[index], payload.options),
      );

      if (index < payload.teams.length - 1 && payload.options.delay_ms > 0) {
        await new Promise((resolve) =>
          setTimeout(resolve, payload.options.delay_ms)
        );
      }
    }

    return jsonResponse(200, {
      success: true,
      requestId,
      function: FUNCTION_NAME,
      count: results.length,
      summary: summarizeResults(results),
      results,
    });
  } catch (error) {
    const mapped = mapError(error, requestId);
    logUnhandledError(requestId, error);
    return jsonResponse(mapped.status, mapped.body);
  }
}
