/**
 * Gemini Vision — extracts structured betting odds from screenshot images.
 * Uses multimodal input: image (base64) + text prompt → structured JSON output.
 */

import { DEFAULT_GEMINI_FALLBACK_MODEL, DEFAULT_GEMINI_MODEL } from "./constants.ts";
import { screenshotOddsSchema } from "./schemas.ts";
import type { ExtractedFixtureOdds, ScreenshotExtractionResult } from "./types.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function stripCodeFences(text: string): string {
  return text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

/**
 * Build the vision prompt that instructs Gemini to read odds from the image.
 */
function buildVisionPrompt(): string {
  return [
    "You are a precision data extraction worker for a production sports backend.",
    "The image is a screenshot of a sports betting website showing football (soccer) matches with 1X2 decimal odds.",
    "",
    "Your task:",
    "1. Identify the betting website from the UI (bet365, Betway, 1xBet, William Hill, etc.).",
    "2. Extract EVERY visible football fixture that has 1X2 (Home/Draw/Away) decimal odds displayed.",
    "3. For each fixture, read the exact team names and the exact decimal odds numbers.",
    "4. If a competition/league header is visible above a group of fixtures, include it.",
    "5. If a kickoff time/date is visible next to a fixture, include it as raw text.",
    "",
    "Critical rules:",
    "- Read the EXACT decimal numbers shown. Do not round, estimate, or invent.",
    "- If a number is partially obscured or blurry, set confidence below 0.7 and still try to read it.",
    "- Home team is typically listed first (top or left). Away team is second (bottom or right).",
    "- The three odds columns are in order: Home (1), Draw (X), Away (2).",
    "- Only extract football/soccer fixtures. Skip other sports entirely.",
    "- If the screenshot shows a login page, CAPTCHA, or error page, return 0 fixtures and explain in extraction_notes.",
    "- Return ONLY valid JSON matching the response schema.",
  ].join("\n");
}

/**
 * Parse the Gemini Vision response into a structured extraction result.
 */
function parseExtractionResult(text: string): ScreenshotExtractionResult {
  const cleaned = stripCodeFences(text);
  let parsed: unknown;

  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error(`Gemini Vision returned malformed JSON: ${cleaned.slice(0, 500)}`);
  }

  if (!isRecord(parsed)) {
    throw new Error("Gemini Vision response is not a JSON object.");
  }

  const fixtures: ExtractedFixtureOdds[] = [];
  const rawFixtures = Array.isArray(parsed.fixtures) ? parsed.fixtures : [];

  for (const raw of rawFixtures) {
    if (!isRecord(raw)) continue;

    const homeOdds = Number(raw.home_odds);
    const drawOdds = Number(raw.draw_odds);
    const awayOdds = Number(raw.away_odds);

    // Validate: odds must be > 1.0 (decimal format) and be finite
    if (
      !Number.isFinite(homeOdds) || homeOdds <= 1.0 ||
      !Number.isFinite(drawOdds) || drawOdds <= 1.0 ||
      !Number.isFinite(awayOdds) || awayOdds <= 1.0
    ) {
      continue; // Skip invalid odds
    }

    fixtures.push({
      home_team: String(raw.home_team ?? "").trim(),
      away_team: String(raw.away_team ?? "").trim(),
      competition: typeof raw.competition === "string" ? raw.competition.trim() || null : null,
      kickoff_text: typeof raw.kickoff_text === "string" ? raw.kickoff_text.trim() || null : null,
      home_odds: Number(homeOdds.toFixed(3)),
      draw_odds: Number(drawOdds.toFixed(3)),
      away_odds: Number(awayOdds.toFixed(3)),
      confidence: Math.max(0, Math.min(1, Number(raw.confidence ?? 0.5))),
    });
  }

  return {
    detected_site: String(parsed.detected_site ?? "unknown").trim(),
    total_fixtures_found: Number(parsed.total_fixtures_found ?? fixtures.length),
    fixtures,
    extraction_notes: Array.isArray(parsed.extraction_notes)
      ? parsed.extraction_notes.filter((n: unknown) => typeof n === "string")
      : [],
  };
}

/**
 * Send a screenshot to Gemini Vision and extract structured betting odds.
 *
 * @param imageBase64 - Base64-encoded PNG/JPG screenshot data
 * @returns Structured extraction result with all visible fixtures and odds
 */
export async function extractOddsFromScreenshot(
  imageBase64: string,
): Promise<ScreenshotExtractionResult> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const primaryModel = Deno.env.get("GEMINI_MODEL")?.trim() || DEFAULT_GEMINI_MODEL;
  const fallbackModel =
    Deno.env.get("GEMINI_FALLBACK_MODEL")?.trim() || DEFAULT_GEMINI_FALLBACK_MODEL;

  const tryModel = async (modelName: string): Promise<ScreenshotExtractionResult> => {
    console.log(`[screenshot-odds-extract] Sending to Gemini Vision (${modelName})...`);

    // Step 1: Send image + prompt to Gemini (no schema enforcement with vision,
    // since multimodal + responseSchema can conflict)
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: buildVisionPrompt() },
                {
                  inlineData: {
                    mimeType: "image/png",
                    data: imageBase64,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 8192,
          },
        }),
        signal: AbortSignal.timeout(60_000),
      },
    );

    const rawText = await response.text();
    let raw: Record<string, unknown>;

    try {
      raw = JSON.parse(rawText) as Record<string, unknown>;
    } catch {
      throw new Error(`Gemini returned non-JSON: ${rawText.slice(0, 300)}`);
    }

    if (!response.ok) {
      throw new Error(
        `Gemini API error (${response.status}): ${JSON.stringify(raw).slice(0, 500)}`,
      );
    }

    // Extract text from the response
    const candidates = Array.isArray(raw.candidates) ? raw.candidates : [];
    const firstCandidate = candidates[0];
    if (!isRecord(firstCandidate) || !isRecord(firstCandidate.content)) {
      throw new Error("Gemini returned no candidate content.");
    }

    const parts = Array.isArray(firstCandidate.content.parts)
      ? firstCandidate.content.parts
      : [];
    const responseText = parts
      .map((p: unknown) => (isRecord(p) && typeof p.text === "string" ? p.text : ""))
      .join("\n")
      .trim();

    if (!responseText) {
      throw new Error("Gemini returned an empty response.");
    }

    // Try direct parse
    try {
      return parseExtractionResult(responseText);
    } catch {
      // Fall through to normalization
    }

    // Step 2: Normalize — send the raw text through a structured JSON pass
    console.log(`[screenshot-odds-extract] Running normalization pass...`);
    const normalizeResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: [
                    "Convert the following betting odds extraction data into strict JSON matching the response schema.",
                    "Preserve all team names exactly as provided. Preserve all odds exactly.",
                    "If any odds values are missing or invalid, exclude that fixture.",
                    "",
                    "--- RAW EXTRACTION ---",
                    responseText,
                  ].join("\n"),
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0,
            responseMimeType: "application/json",
            responseJsonSchema: screenshotOddsSchema,
          },
        }),
        signal: AbortSignal.timeout(30_000),
      },
    );

    const normRawText = await normalizeResponse.text();
    let normRaw: Record<string, unknown>;
    try {
      normRaw = JSON.parse(normRawText) as Record<string, unknown>;
    } catch {
      throw new Error(`Gemini normalization returned non-JSON: ${normRawText.slice(0, 300)}`);
    }

    if (!normalizeResponse.ok) {
      throw new Error(
        `Gemini normalization failed (${normalizeResponse.status}): ${JSON.stringify(normRaw).slice(0, 500)}`,
      );
    }

    const normCandidates = Array.isArray(normRaw.candidates) ? normRaw.candidates : [];
    const normFirst = normCandidates[0];
    if (!isRecord(normFirst) || !isRecord(normFirst.content)) {
      throw new Error("Gemini normalization returned no content.");
    }
    const normParts = Array.isArray(normFirst.content.parts) ? normFirst.content.parts : [];
    const normText = normParts
      .map((p: unknown) => (isRecord(p) && typeof p.text === "string" ? p.text : ""))
      .join("\n")
      .trim();

    return parseExtractionResult(normText);
  };

  // Try primary model, fallback if rate limited or server error
  try {
    return await tryModel(primaryModel);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    if (
      (msg.includes("429") || msg.includes("500") || msg.includes("503")) &&
      fallbackModel !== primaryModel
    ) {
      console.warn(
        `[screenshot-odds-extract] Primary model failed, trying fallback: ${fallbackModel}`,
      );
      return await tryModel(fallbackModel);
    }
    throw error;
  }
}
