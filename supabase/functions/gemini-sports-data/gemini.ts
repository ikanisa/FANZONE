import {
  type GenerateContentResponse,
  GoogleGenAI,
  type Tool,
} from "npm:@google/genai";

import { DEFAULT_GEMINI_MODEL } from "./constants.ts";
import { HttpError, requireEnv } from "./http.ts";
import {
  parseGeminiJson,
  parseMatchEventsJson,
  parseMatchEventsPayload,
  parseOddsOutput,
} from "./payload.ts";
import { eventsSchema, oddsSchema } from "./schemas.ts";
import type {
  GroundingSummary,
  MatchDataRequest,
  MatchEventsPayload,
  MatchOdds,
  StructuredMatchDataResult,
} from "./types.ts";

function buildEventPrompt(payload: MatchDataRequest): string {
  const kickoffLine = payload.kickoffAt
    ? `Scheduled kickoff (UTC): ${payload.kickoffAt}.`
    : "Scheduled kickoff (UTC) is not provided.";
  const competitionLine = payload.competitionName
    ? `Competition: ${payload.competitionName}.`
    : "Competition name is not provided.";
  const sourceUrlLine = payload.sourceUrl
    ? `Official or source URL to inspect with URL Context when helpful: ${payload.sourceUrl}`
    : "No direct source URL is available.";

  return [
    "You are a grounded live football match update extractor for a production backend.",
    "Use Google Search grounding and URL Context when it helps verify specific pages.",
    "Do not guess. If a fact is not grounded strongly enough, omit the event and explain it in uncertainty_notes.",
    `Fixture: ${payload.teamA} vs ${payload.teamB}.`,
    competitionLine,
    kickoffLine,
    sourceUrlLine,
    "Task:",
    "- Determine the current match_status.",
    "- Determine the most specific current phase of play.",
    "- Determine the latest confirmed minute if the match is live.",
    "- Determine the current confirmed score.",
    "- Extract only confirmed key events that have already happened.",
    "Allowed event types: GOAL, OWN_GOAL, PENALTY_SCORED, PENALTY_MISSED, YELLOW_CARD, RED_CARD, SUBSTITUTION, VAR_DECISION, KICK_OFF, HALF_TIME, FULL_TIME.",
    "Allowed match_status values: LIVE, FINISHED, UPCOMING, POSTPONED, CANCELLED, SUSPENDED, UNKNOWN.",
    "Allowed phase values: PRE_MATCH, FIRST_HALF, HALF_TIME, SECOND_HALF, EXTRA_TIME, PENALTIES, FULL_TIME, POSTPONED, CANCELLED, SUSPENDED, UNKNOWN.",
    "Rules:",
    "- Return ONLY valid JSON matching the response schema.",
    "- Do not include markdown, prose, or code fences.",
    "- Prefer official federation / competition / match-centre sources when available.",
    "- Use trusted public live-score sites only as fallback when official sources do not expose the needed detail.",
    "- Scores must be non-negative integers.",
    '- Convert stoppage time to a single integer minute, for example "45+2" becomes 47.',
    `- Use "${payload.teamA}" or "${payload.teamB}" in the team field when the source clearly maps to one side.`,
    "- For substitutions, keep the primary player in player and put the paired player in details or assist_player when clearly available.",
    "- Keep events in chronological order from earliest to latest.",
    "- If the match is live but there are no confirmed key events yet, return an empty events array and keep match_status LIVE.",
    "- If the scheduled kickoff has passed but no reliable live proof exists yet, return the best grounded status and explain the uncertainty.",
  ].join("\n");
}

function buildOddsPrompt(payload: MatchDataRequest): string {
  const kickoffLine = payload.kickoffAt
    ? `Scheduled kickoff (UTC): ${payload.kickoffAt}.`
    : "";
  return [
    "You are a grounded football odds extraction worker for a production backend.",
    `Fixture: ${payload.teamA} vs ${payload.teamB}.`,
    payload.competitionName ? `Competition: ${payload.competitionName}.` : "",
    kickoffLine,
    "Use Google Search grounding and inspect the provided source URL if it directly contains odds coverage.",
    "Return ONLY valid JSON matching the response schema.",
    "Use decimal 1X2 odds only.",
    "Do not invent values.",
  ].filter(Boolean).join("\n");
}

function buildPrompt(payload: MatchDataRequest): string {
  return payload.fetchType === "events"
    ? buildEventPrompt(payload)
    : buildOddsPrompt(payload);
}

function buildNormalizationPrompt(
  payload: MatchDataRequest,
  groundedText: string,
): string {
  if (payload.fetchType === "events") {
    return [
      "Convert the grounded football match notes below into strict JSON.",
      "Use only facts explicitly present in the grounded notes.",
      "Do not infer or embellish.",
      "Return only JSON that matches the provided schema.",
      "Allowed match_status values: LIVE, FINISHED, UPCOMING, POSTPONED, CANCELLED, SUSPENDED, UNKNOWN.",
      "Allowed phase values: PRE_MATCH, FIRST_HALF, HALF_TIME, SECOND_HALF, EXTRA_TIME, PENALTIES, FULL_TIME, POSTPONED, CANCELLED, SUSPENDED, UNKNOWN.",
      "If the notes say the match has not started yet, use match_status UPCOMING and phase PRE_MATCH.",
      "If no events are confirmed, return an empty events array.",
      "If no minute is confirmed, use null for minute.",
      `Fixture: ${payload.teamA} vs ${payload.teamB}.`,
      "Grounded notes:",
      groundedText,
    ].join("\n");
  }

  return [
    "Convert the grounded football odds notes below into strict JSON.",
    "Use only facts explicitly present in the grounded notes.",
    "Return only JSON that matches the provided schema.",
    `Fixture: ${payload.teamA} vs ${payload.teamB}.`,
    "Grounded notes:",
    groundedText,
  ].join("\n");
}

function getGeminiClient() {
  return new GoogleGenAI({
    apiKey: requireEnv("GEMINI_API_KEY"),
  });
}

function shouldUseUrlContext(url: string | null | undefined): boolean {
  if (!url) return false;

  try {
    const parsed = new URL(url);
    const host = parsed.host.toLowerCase();
    const path = parsed.pathname.toLowerCase();

    if (
      host === "raw.githubusercontent.com" ||
      host.endsWith(".githubusercontent.com")
    ) {
      return false;
    }

    if (
      path.endsWith(".json") ||
      path.endsWith(".csv") ||
      path.endsWith(".xml")
    ) {
      return false;
    }

    return true;
  } catch {
    return false;
  }
}

function buildTools(payload: MatchDataRequest): Tool[] {
  if (payload.fetchType === "events" && shouldUseUrlContext(payload.sourceUrl)) {
    return [{ googleSearch: {} }, { urlContext: {} }];
  }

  return [{ googleSearch: {} }];
}

function hostFromUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    return new URL(value).host.toLowerCase();
  } catch {
    return null;
  }
}

function extractGroundingSummary(
  response: GenerateContentResponse,
): GroundingSummary {
  const candidate = response.candidates?.[0];
  const metadata = candidate?.groundingMetadata;
  const urlContextMetadata = candidate?.urlContextMetadata;
  const sources = new Map<
    string,
    {
      uri: string;
      title: string | null;
      domain: string | null;
      source_type: string;
      trust_score: number;
      trusted: boolean;
    }
  >();

  for (const chunk of metadata?.groundingChunks ?? []) {
    const uri = chunk.web?.uri?.trim();
    if (!uri) {
      continue;
    }

    sources.set(uri, {
      uri,
      title: chunk.web?.title?.trim() || null,
      domain: hostFromUrl(uri),
      source_type: "unknown",
      trust_score: 0,
      trusted: false,
    });
  }

  return {
    webSearchQueries: metadata?.webSearchQueries ?? [],
    sources: Array.from(sources.values()),
    urlContextResults: (urlContextMetadata?.urlMetadata ?? [])
      .map((item) => ({
        retrievedUrl: item.retrievedUrl ?? "",
        status: item.urlRetrievalStatus ?? "URL_RETRIEVAL_STATUS_UNSPECIFIED",
      }))
      .filter((item) => item.retrievedUrl.length > 0),
    googleSearchDynamicRetrievalScore:
      metadata?.retrievalMetadata?.googleSearchDynamicRetrievalScore ?? null,
  };
}

function extractResponseText(response: GenerateContentResponse): string {
  const directText = typeof response.text === "string" ? response.text.trim() : "";
  if (directText) {
    return directText;
  }

  const partsText = (response.candidates ?? [])
    .flatMap((candidate) => candidate.content?.parts ?? [])
    .map((part) => typeof part.text === "string" ? part.text.trim() : "")
    .filter(Boolean)
    .join("\n")
    .trim();

  return partsText;
}

function parseStructuredOutput(
  payload: MatchDataRequest,
  text: string,
): MatchEventsPayload | MatchOdds {
  if (payload.fetchType === "events") {
    return parseMatchEventsPayload(parseMatchEventsJson(text));
  }

  return parseOddsOutput(parseGeminiJson(text));
}

async function normalizeGroundedTextToJson(
  ai: GoogleGenAI,
  payload: MatchDataRequest,
  groundedText: string,
) {
  const schema = payload.fetchType === "events" ? eventsSchema : oddsSchema;
  const response = await ai.models.generateContent({
    model: DEFAULT_GEMINI_MODEL,
    contents: buildNormalizationPrompt(payload, groundedText),
    config: {
      temperature: 0,
      responseMimeType: "application/json",
      responseSchema: schema,
    },
  });

  const text = extractResponseText(response);
  if (!text) {
    throw new HttpError(
      502,
      "Gemini returned an empty normalization response body.",
    );
  }

  return text;
}

export async function fetchStructuredMatchData(
  payload: MatchDataRequest,
): Promise<StructuredMatchDataResult<MatchEventsPayload | MatchOdds>> {
  const ai = getGeminiClient();
  const schema = payload.fetchType === "events" ? eventsSchema : oddsSchema;
  const tools = buildTools(payload);
  const config: Record<string, unknown> = {
    tools,
    temperature: 0.1,
  };

  // Gemini grounding tools currently do not support JSON mime/schema output
  // in the same request, so keep the response as plain text and parse the JSON
  // ourselves from the model output.
  if (tools.length === 0) {
    config.responseMimeType = "application/json";
    config.responseSchema = schema;
  }

  const response = await ai.models.generateContent({
    model: DEFAULT_GEMINI_MODEL,
    contents: buildPrompt(payload),
    config,
  });

  const text = extractResponseText(response);
  const grounding = extractGroundingSummary(response);
  try {
    return {
      data: parseStructuredOutput(payload, text),
      grounding,
      rawText: text,
    };
  } catch (error) {
    if (
      !(error instanceof HttpError) ||
      error.status !== 502 ||
      !text ||
      tools.length === 0
    ) {
      throw error;
    }

    const normalizedText = await normalizeGroundedTextToJson(ai, payload, text);
    return {
      data: parseStructuredOutput(payload, normalizedText),
      grounding,
      rawText: JSON.stringify({
        groundedText: text,
        normalizedJson: normalizedText,
      }),
    };
  }
}
