/**
 * Screenshot-to-Multipliers Pipeline Orchestrator.
 *
 * Primary flow (recommended):
 *   Local Puppeteer (scripts/capture-odds.mjs) → imageBase64 → this function
 *   Source: bwin.com (official bookmaker, confirmed working in headless Chrome)
 *
 * Steps:
 * 1. Receive pre-captured screenshot (imageBase64) from local script
 * 2. Send screenshot to Gemini Vision for structured odds extraction
 * 3. Fuzzy-match extracted teams to DB matches
 * 4. UPSERT multipliers into match_odds_cache
 * 5. Log everything to odds_screenshots for audit trail
 */

import { createClient } from "jsr:@supabase/supabase-js@2";

import { DEFAULT_CAPTURE_URLS, DEFAULT_GEMINI_MODEL } from "./constants.ts";
import { captureScreenshot } from "./capture.ts";
import { extractOddsFromScreenshot } from "./gemini.ts";
import { matchFixturesToDb } from "./matcher.ts";
import { assertAuthorized, corsHeaders, HttpError, jsonResponse, logError, requireEnv } from "./http.ts";
import type { DbMatch, PipelineRunResult } from "./types.ts";

type SupabaseClient = ReturnType<typeof createClient>;

function getSupabase(): SupabaseClient {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

// ─────────────────────────────────────────────────────────────
// Database helpers
// ─────────────────────────────────────────────────────────────

/**
 * Load upcoming/scheduled matches from the DB for fuzzy matching.
 * Includes today's and tomorrow's matches.
 */
async function loadUpcomingMatches(supabase: SupabaseClient): Promise<DbMatch[]> {
  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
  const dayAfterTomorrow = new Date(now.getTime() + 48 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from("matches")
    .select("id, home_team, away_team, home_team_id, away_team_id, competition_name, kickoff_at, status")
    .gte("kickoff_at", yesterday)
    .lte("kickoff_at", dayAfterTomorrow)
    .in("status", ["scheduled", "live", "in_play", "upcoming", "not_started"])
    .limit(200);

  if (error) {
    // Fallback: try without status filter if the column has different values
    const { data: fallbackData, error: fallbackError } = await supabase
      .from("matches")
      .select("id, home_team, away_team, home_team_id, away_team_id, competition_name, kickoff_at, status")
      .gte("kickoff_at", yesterday)
      .lte("kickoff_at", dayAfterTomorrow)
      .limit(200);

    if (fallbackError) {
      throw new HttpError(500, "Failed to load upcoming matches.", fallbackError);
    }

    return (fallbackData ?? []) as DbMatch[];
  }

  return (data ?? []) as DbMatch[];
}

/**
 * Create or update the odds_screenshots log entry.
 */
async function createScreenshotLog(
  supabase: SupabaseClient,
  sourceUrl: string,
  captureProvider: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("odds_screenshots")
    .insert({
      source_url: sourceUrl,
      source_site: detectSiteName(sourceUrl),
      capture_provider: captureProvider,
      status: "pending",
    })
    .select("id")
    .single();

  if (error || !data?.id) {
    throw new HttpError(500, "Failed to create screenshot log.", error);
  }

  return String(data.id);
}

async function updateScreenshotLog(
  supabase: SupabaseClient,
  id: string,
  patch: Record<string, unknown>,
) {
  await supabase
    .from("odds_screenshots")
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq("id", id);
}

/**
 * UPSERT extracted odds into match_odds_cache.
 */
async function upsertOddsCache(
  supabase: SupabaseClient,
  matchId: string,
  homeMultiplier: number,
  drawMultiplier: number,
  awayMultiplier: number,
  screenshotId: string,
  sourcePayload: Record<string, unknown>,
) {
  const now = new Date().toISOString();
  const { error } = await supabase
    .from("match_odds_cache")
    .upsert(
      {
        match_id: matchId,
        home_multiplier: homeMultiplier,
        draw_multiplier: drawMultiplier,
        away_multiplier: awayMultiplier,
        provider: "screenshot_vision",
        source_tier: "screenshot_vision",
        screenshot_id: screenshotId,
        source_payload: sourcePayload,
        refreshed_at: now,
        updated_at: now,
      },
      { onConflict: "match_id" },
    );

  if (error) {
    throw new HttpError(500, `Failed to upsert odds for match ${matchId}.`, error);
  }
}

function detectSiteName(url: string): string {
  try {
    const host = new URL(url).hostname.toLowerCase();
    if (host.includes("bwin")) return "bwin";
    if (host.includes("bet365")) return "bet365";
    if (host.includes("betway")) return "betway";
    if (host.includes("1xbet")) return "1xbet";
    if (host.includes("williamhill")) return "williamhill";
    if (host.includes("betfair")) return "betfair";
    if (host.includes("pinnacle")) return "pinnacle";
    return host;
  } catch {
    return "unknown";
  }
}

// ─────────────────────────────────────────────────────────────
// Pipeline: process a single URL
// ─────────────────────────────────────────────────────────────

async function processUrl(
  supabase: SupabaseClient,
  url: string,
  dbMatches: DbMatch[],
): Promise<PipelineRunResult> {
  const errors: string[] = [];
  let screenshotId = "";

  try {
    // Step 1: Create screenshot log entry
    screenshotId = await createScreenshotLog(supabase, url, "auto");

    // Step 2: Capture screenshot
    console.log(`[screenshot-odds-extract] ▶ Capturing: ${url}`);
    const capture = await captureScreenshot({ url });

    await updateScreenshotLog(supabase, screenshotId, {
      status: "captured",
      capture_provider: capture.provider,
      viewport_width: capture.width,
      viewport_height: capture.height,
      captured_at: new Date().toISOString(),
      // Don't store full base64 in DB — too large. Store a truncated hash instead.
      image_base64: null,
    });

    // Step 3: Extract odds via Gemini Vision
    console.log(`[screenshot-odds-extract] ▶ Extracting odds from screenshot...`);
    const extraction = await extractOddsFromScreenshot(capture.imageBase64);

    await updateScreenshotLog(supabase, screenshotId, {
      status: "extracted",
      extracted_odds: extraction,
      total_fixtures_found: extraction.total_fixtures_found,
      gemini_model: DEFAULT_GEMINI_MODEL,
      extracted_at: new Date().toISOString(),
    });

    console.log(
      `[screenshot-odds-extract] ✓ Extracted ${extraction.fixtures.length} fixtures from ${extraction.detected_site}`,
    );

    if (extraction.fixtures.length === 0) {
      await updateScreenshotLog(supabase, screenshotId, {
        status: "matched",
        matched_count: 0,
      });
      return {
        screenshotId,
        captureProvider: capture.provider,
        sourceUrl: url,
        fixturesFound: 0,
        matchesLinked: 0,
        oddsUpdated: 0,
        errors: extraction.extraction_notes,
      };
    }

    // Step 4: Fuzzy-match fixtures to DB matches
    console.log(`[screenshot-odds-extract] ▶ Matching ${extraction.fixtures.length} fixtures against ${dbMatches.length} DB matches...`);
    const matchResults = matchFixturesToDb(extraction.fixtures, dbMatches);

    console.log(`[screenshot-odds-extract] ✓ Matched ${matchResults.length} fixtures to DB`);

    // Step 5: UPSERT matched odds
    let oddsUpdated = 0;
    for (const match of matchResults) {
      try {
        await upsertOddsCache(
          supabase,
          match.dbMatch.id,
          match.fixture.home_odds,
          match.fixture.draw_odds,
          match.fixture.away_odds,
          screenshotId,
          {
            extracted_home_team: match.fixture.home_team,
            extracted_away_team: match.fixture.away_team,
            match_score: match.matchScore,
            extraction_confidence: match.fixture.confidence,
            detected_site: extraction.detected_site,
            source_url: url,
          },
        );
        oddsUpdated++;
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        errors.push(`Failed to upsert odds for ${match.dbMatch.id}: ${msg}`);
      }
    }

    await updateScreenshotLog(supabase, screenshotId, {
      status: "matched",
      matched_count: matchResults.length,
      extraction_confidence: matchResults.length > 0
        ? matchResults.reduce((sum, m) => sum + m.fixture.confidence, 0) / matchResults.length
        : 0,
    });

    return {
      screenshotId,
      captureProvider: capture.provider,
      sourceUrl: url,
      fixturesFound: extraction.fixtures.length,
      matchesLinked: matchResults.length,
      oddsUpdated,
      errors,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    errors.push(msg);

    if (screenshotId) {
      await updateScreenshotLog(supabase, screenshotId, {
        status: "failed",
        capture_error: msg,
      }).catch(() => {});
    }

    return {
      screenshotId,
      captureProvider: "none",
      sourceUrl: url,
      fixturesFound: 0,
      matchesLinked: 0,
      oddsUpdated: 0,
      errors,
    };
  }
}

// ─────────────────────────────────────────────────────────────
// Request parsing
// ─────────────────────────────────────────────────────────────

interface PipelineRequest {
  /** 'auto' = use default bet365 URLs. 'manual' = use provided URLs. */
  mode: "auto" | "manual";
  /** URLs to capture (only used in manual mode) */
  urls?: string[];
  /** Optional: provide a pre-captured base64 image directly (skip capture) */
  imageBase64?: string;
  /** Trigger source for logging */
  trigger?: string;
}

function parseRequest(body: unknown): PipelineRequest {
  if (typeof body !== "object" || body === null) {
    return { mode: "auto" };
  }

  const obj = body as Record<string, unknown>;
  const mode = obj.mode === "manual" ? "manual" : "auto";
  const urls = Array.isArray(obj.urls)
    ? obj.urls.filter((u): u is string => typeof u === "string" && u.startsWith("http"))
    : undefined;

  return {
    mode,
    urls,
    imageBase64: typeof obj.imageBase64 === "string" ? obj.imageBase64 : undefined,
    trigger: typeof obj.trigger === "string" ? obj.trigger : undefined,
  };
}

// ─────────────────────────────────────────────────────────────
// Main handler
// ─────────────────────────────────────────────────────────────

export async function handleScreenshotOddsRequest(req: Request) {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { success: false, requestId, error: "Use POST." });
  }

  try {
    assertAuthorized(req);

    let body: unknown = {};
    try {
      body = await req.json();
    } catch {
      // Empty body is fine — defaults to auto mode
    }

    const request = parseRequest(body);
    const supabase = getSupabase();

    console.log(`[screenshot-odds-extract] ▶ Pipeline started (mode=${request.mode}, trigger=${request.trigger ?? "manual"})`);

    // Load DB matches for fuzzy matching
    const dbMatches = await loadUpcomingMatches(supabase);
    console.log(`[screenshot-odds-extract] ▶ Loaded ${dbMatches.length} upcoming matches from DB`);

    // Handle direct image upload (skip capture step)
    if (request.imageBase64) {
      console.log(`[screenshot-odds-extract] ▶ Processing pre-captured image...`);
      const screenshotId = await createScreenshotLog(supabase, "direct_upload", "manual");

      await updateScreenshotLog(supabase, screenshotId, {
        status: "captured",
        capture_provider: "manual",
        captured_at: new Date().toISOString(),
      });

      const extraction = await extractOddsFromScreenshot(request.imageBase64);

      await updateScreenshotLog(supabase, screenshotId, {
        status: "extracted",
        extracted_odds: extraction,
        total_fixtures_found: extraction.total_fixtures_found,
        gemini_model: DEFAULT_GEMINI_MODEL,
        extracted_at: new Date().toISOString(),
      });

      const matchResults = matchFixturesToDb(extraction.fixtures, dbMatches);
      let oddsUpdated = 0;

      for (const match of matchResults) {
        try {
          await upsertOddsCache(
            supabase,
            match.dbMatch.id,
            match.fixture.home_odds,
            match.fixture.draw_odds,
            match.fixture.away_odds,
            screenshotId,
            {
              extracted_home_team: match.fixture.home_team,
              extracted_away_team: match.fixture.away_team,
              match_score: match.matchScore,
              extraction_confidence: match.fixture.confidence,
            },
          );
          oddsUpdated++;
        } catch { /* skip */ }
      }

      await updateScreenshotLog(supabase, screenshotId, {
        status: "matched",
        matched_count: matchResults.length,
      });

      return jsonResponse(200, {
        success: true,
        requestId,
        mode: "direct_image",
        results: [{
          screenshotId,
          fixturesFound: extraction.fixtures.length,
          matchesLinked: matchResults.length,
          oddsUpdated,
          detectedSite: extraction.detected_site,
          extractionNotes: extraction.extraction_notes,
        }],
      });
    }

    // Determine URLs to capture
    const urls = request.mode === "manual" && request.urls?.length
      ? request.urls
      : DEFAULT_CAPTURE_URLS;

    // Process each URL
    const results: PipelineRunResult[] = [];
    for (const url of urls) {
      const result = await processUrl(supabase, url, dbMatches);
      results.push(result);
    }

    const totalFixtures = results.reduce((s, r) => s + r.fixturesFound, 0);
    const totalMatched = results.reduce((s, r) => s + r.matchesLinked, 0);
    const totalUpdated = results.reduce((s, r) => s + r.oddsUpdated, 0);
    const allErrors = results.flatMap((r) => r.errors);

    console.log(
      `[screenshot-odds-extract] ✅ Pipeline complete: ${totalFixtures} fixtures found, ${totalMatched} matched, ${totalUpdated} odds updated`,
    );

    return jsonResponse(200, {
      success: true,
      requestId,
      mode: request.mode,
      trigger: request.trigger,
      summary: {
        urlsProcessed: urls.length,
        totalFixturesFound: totalFixtures,
        totalMatchesLinked: totalMatched,
        totalOddsUpdated: totalUpdated,
        errors: allErrors.length,
      },
      results,
    });
  } catch (err) {
    logError(requestId, err);
    const status = err instanceof HttpError ? err.status : 500;
    return jsonResponse(status, {
      success: false,
      requestId,
      error: err instanceof Error ? err.message : "Unhandled server error.",
    });
  }
}
