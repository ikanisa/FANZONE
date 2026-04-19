import {
  DEFAULT_GEMINI_FALLBACK_MODEL,
  DEFAULT_GEMINI_MODEL,
} from "./constants.ts";
import { HttpError, requireEnv } from "./http.ts";
import { crestLookupResponseSchema } from "./schemas.ts";
import type {
  GeminiAlternativeCandidate,
  GeminiCrestCandidate,
  GeminiCrestResponse,
  GeminiLookupResult,
  GroundingSummary,
  TeamCrestInput,
} from "./types.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeUrl(value: unknown): string | null {
  const candidate = asTrimmedString(value);
  if (!candidate) return null;

  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

function normalizeSourceType(
  value: unknown,
): GeminiCrestCandidate["source_type"] {
  switch (value) {
    case "official_club":
    case "official_federation":
    case "official_competition":
    case "trusted_reference":
      return value;
    default:
      return "unknown";
  }
}

function stripCodeFences(text: string): string {
  return text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function extractBalancedJson(text: string): string | null {
  const source = stripCodeFences(text);

  for (let start = 0; start < source.length; start++) {
    const opener = source[start];
    if (opener !== "{" && opener !== "[") continue;

    const stack: string[] = [opener === "{" ? "}" : "]"];
    let inString = false;
    let escaped = false;

    for (let index = start + 1; index < source.length; index++) {
      const char = source[index];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char === "\\") {
        escaped = true;
        continue;
      }

      if (char === '"') {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (char === "{") {
        stack.push("}");
      } else if (char === "[") {
        stack.push("]");
      } else if (char === "}" || char === "]") {
        if (stack[stack.length - 1] !== char) break;
        stack.pop();
        if (stack.length === 0) {
          return source.slice(start, index + 1);
        }
      }
    }
  }

  return null;
}

function parseGeminiJson(text: string): unknown {
  const direct = stripCodeFences(text);

  try {
    return JSON.parse(direct);
  } catch {
    const extracted = extractBalancedJson(text);
    if (!extracted) {
      throw new HttpError(502, "Gemini returned malformed JSON.");
    }
    return JSON.parse(extracted);
  }
}

function buildPrompt(input: TeamCrestInput): string {
  const today = new Date().toISOString().slice(0, 10);
  const aliases = input.aliases.length > 0 ? input.aliases.join(", ") : "none";

  return [
    "You are a football data verification worker for a production sports backend.",
    `Today's UTC date is ${today}.`,
    "Find the most likely official team crest or logo for the exact football team below.",
    "",
    `team_id: ${input.team_id}`,
    `team_name: ${input.team_name}`,
    `competition: ${input.competition ?? "unknown"}`,
    `country: ${input.country ?? "unknown"}`,
    `aliases: ${aliases}`,
    "",
    "Search and validate in this order:",
    "1. Official club website or official club media/CDN.",
    "2. Official federation or official competition page for the exact club.",
    "3. Trusted football reference sources only if no official source exposes a usable crest.",
    "",
    "Hard rules:",
    "- The source_url must be a public page where the crest can be verified.",
    "- The image_url must be a direct public URL to the crest image itself.",
    "- Prefer the exact club badge or crest, not sponsor marks, app icons, hero banners, kit photos, player photos, or fan pages.",
    "- Reject reserve teams, youth teams, women's teams, national teams, academies, or historical clubs unless the provided competition and country clearly indicate that entity.",
    "- Use aliases only for disambiguation.",
    "- Prefer official sources even if a trusted reference source has an easier image URL.",
    "- If you must fall back to a trusted reference source, say so in validation_notes.",
    "- Return only JSON matching the schema.",
  ].join("\n");
}

function extractResponseText(raw: Record<string, unknown>): string {
  const candidates = Array.isArray(raw.candidates) ? raw.candidates : [];
  const firstCandidate = candidates[0];
  if (!isRecord(firstCandidate) || !isRecord(firstCandidate.content)) {
    throw new HttpError(502, "Gemini returned no candidate content.");
  }

  const parts = Array.isArray(firstCandidate.content.parts)
    ? firstCandidate.content.parts
    : [];
  const text = parts
    .map((part) => (isRecord(part) ? asTrimmedString(part.text) : null))
    .filter((value): value is string => value != null)
    .join("\n")
    .trim();

  if (!text) {
    throw new HttpError(502, "Gemini returned an empty response body.");
  }

  return text;
}

function collectUrls(
  value: unknown,
  urls = new Set<string>(),
  depth = 0,
): Set<string> {
  if (depth > 8 || value == null) return urls;

  if (typeof value === "string") {
    const normalized = normalizeUrl(value);
    if (normalized) urls.add(normalized);
    return urls;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      collectUrls(item, urls, depth + 1);
    }
    return urls;
  }

  if (!isRecord(value)) return urls;

  for (const [key, nested] of Object.entries(value)) {
    if (["uri", "url", "sourceUrl", "imageUrl"].includes(key)) {
      const normalized = normalizeUrl(nested);
      if (normalized) {
        urls.add(normalized);
      }
    }
    collectUrls(nested, urls, depth + 1);
  }

  return urls;
}

function extractGrounding(raw: Record<string, unknown>): GroundingSummary {
  const candidates = Array.isArray(raw.candidates) ? raw.candidates : [];
  const firstCandidate = candidates[0];
  if (!isRecord(firstCandidate)) {
    return { sources: [], grounded_urls: [] };
  }

  const sources = new Map<string, { uri: string; title: string | null }>();
  const groundingMetadata = isRecord(firstCandidate.groundingMetadata)
    ? firstCandidate.groundingMetadata
    : null;

  if (groundingMetadata && Array.isArray(groundingMetadata.groundingChunks)) {
    for (const chunk of groundingMetadata.groundingChunks) {
      if (!isRecord(chunk) || !isRecord(chunk.web)) continue;
      const uri = normalizeUrl(chunk.web.uri);
      if (!uri) continue;
      sources.set(uri, {
        uri,
        title: asTrimmedString(chunk.web.title),
      });
    }
  }

  const groundedUrls = Array.from(
    collectUrls({
      groundingMetadata: firstCandidate.groundingMetadata,
      urlContextMetadata: firstCandidate.urlContextMetadata,
    }),
  );

  return {
    sources: Array.from(sources.values()),
    grounded_urls: groundedUrls,
  };
}

function parseCandidate(raw: unknown): GeminiCrestCandidate | null {
  if (!isRecord(raw)) return null;

  const sourceUrl = normalizeUrl(raw.source_url);
  const imageUrl = normalizeUrl(raw.image_url);
  if (!sourceUrl || !imageUrl) return null;

  return {
    source_url: sourceUrl,
    image_url: imageUrl,
    source_name: asTrimmedString(raw.source_name),
    source_domain: asTrimmedString(raw.source_domain),
    source_type: normalizeSourceType(raw.source_type),
    matched_name: asTrimmedString(raw.matched_name),
    matched_alias: asTrimmedString(raw.matched_alias),
    official_signal: asTrimmedString(raw.official_signal),
    match_reason: asTrimmedString(raw.match_reason),
    competition_match: raw.competition_match === true,
    country_match: raw.country_match === true,
    validation_notes: asTrimmedString(raw.validation_notes),
  };
}

function parseAlternative(raw: unknown): GeminiAlternativeCandidate | null {
  if (!isRecord(raw)) return null;
  return {
    source_url: normalizeUrl(raw.source_url),
    image_url: normalizeUrl(raw.image_url),
    source_domain: asTrimmedString(raw.source_domain),
    source_type: normalizeSourceType(raw.source_type),
    reason: asTrimmedString(raw.reason),
  };
}

function parseStructuredResponse(text: string): GeminiCrestResponse {
  const parsed = parseGeminiJson(text);
  if (!isRecord(parsed)) {
    throw new HttpError(502, "Gemini returned a non-object crest payload.");
  }

  return {
    selected_candidate: parseCandidate(parsed.selected_candidate),
    alternative_candidates: Array.isArray(parsed.alternative_candidates)
      ? parsed.alternative_candidates
        .map(parseAlternative)
        .filter((value): value is GeminiAlternativeCandidate => value != null)
      : [],
    search_summary: asTrimmedString(parsed.search_summary),
  };
}

export async function fetchCrestCandidate(
  input: TeamCrestInput,
): Promise<GeminiLookupResult> {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const primaryModelName = Deno.env.get("GEMINI_MODEL")?.trim() ||
    DEFAULT_GEMINI_MODEL;
  const fallbackModelName = Deno.env.get("GEMINI_FALLBACK_MODEL")?.trim() ||
    DEFAULT_GEMINI_FALLBACK_MODEL;

  const tryModel = async (modelName: string) => {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${
        encodeURIComponent(apiKey)
      }`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: buildPrompt(input) }],
          }],
          tools: [
            { googleSearch: {} },
            { urlContext: {} },
          ],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: "application/json",
            responseJsonSchema: crestLookupResponseSchema,
          },
        }),
        signal: AbortSignal.timeout(45_000),
      },
    );

    const rawText = await response.text();
    let raw: Record<string, unknown>;

    try {
      raw = JSON.parse(rawText) as Record<string, unknown>;
    } catch {
      throw new HttpError(
        502,
        "Gemini returned a non-JSON HTTP response.",
        {
          model_name: modelName,
          rawText,
        },
      );
    }

    if (!response.ok) {
      throw new HttpError(
        response.status === 429 ? 429 : 502,
        response.status === 429
          ? "Gemini API rate limit or quota exceeded."
          : "Gemini API request failed.",
        {
          model_name: modelName,
          response: raw,
          status: response.status,
        },
      );
    }

    const text = extractResponseText(raw);

    return {
      raw_response: raw,
      parsed: parseStructuredResponse(text),
      grounding: extractGrounding(raw),
      model_name: modelName,
    } satisfies GeminiLookupResult;
  };

  try {
    return await tryModel(primaryModelName);
  } catch (error) {
    const shouldFallback = error instanceof HttpError &&
      (error.status === 429 || error.status >= 500) &&
      fallbackModelName &&
      fallbackModelName !== primaryModelName;

    if (!shouldFallback) {
      throw error;
    }

    console.warn("[gemini-team-crests] Primary Gemini model failed, retrying fallback model.", {
      primary_model: primaryModelName,
      fallback_model: fallbackModelName,
      error,
    });

    try {
      return await tryModel(fallbackModelName);
    } catch (fallbackError) {
      throw new HttpError(
        fallbackError instanceof HttpError ? fallbackError.status : 502,
        fallbackError instanceof HttpError
          ? fallbackError.message
          : "Gemini fallback model request failed.",
        {
          primary_model: primaryModelName,
          fallback_model: fallbackModelName,
          primary_error: error instanceof HttpError ? error.details ?? error.message : String(error),
          fallback_error: fallbackError instanceof HttpError
            ? fallbackError.details ?? fallbackError.message
            : String(fallbackError),
        },
      );
    }
  }
}
