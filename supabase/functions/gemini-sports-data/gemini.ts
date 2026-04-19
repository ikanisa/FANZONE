import { GoogleGenerativeAI, type Tool } from "npm:@google/generative-ai";

import { DEFAULT_GEMINI_MODEL } from "./constants.ts";
import { requireEnv } from "./http.ts";
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

function buildPrompt(payload: MatchDataRequest): string {
  const today = new Date().toISOString().slice(0, 10);
  const matchLabel = `${payload.teamA} vs ${payload.teamB}`;

  if (payload.fetchType === "events") {
    return [
      "You are a data extraction worker for a fantasy football backend.",
      `Today's UTC date is ${today}.`,
      `Use Google Search to find the current match status, score, and live timeline for the football match "${matchLabel}" on ${today}.`,
      "Extract only events that have already happened, and also return the current match state.",
      "Allowed event types: GOAL, YELLOW_CARD, RED_CARD, SUBSTITUTION.",
      "Allowed match_status values: LIVE, FINISHED, UPCOMING, POSTPONED, CANCELLED, UNKNOWN.",
      "Rules:",
      "- Return ONLY valid JSON matching the response schema.",
      "- Do not include markdown, prose, or code fences.",
      "- Always return the current score as non-negative integers in home_score and away_score.",
      "- Always return the best supported match_status based on search results.",
      `- Use "${payload.teamA}" or "${payload.teamB}" in the team field whenever the source clearly maps to one of them.`,
      '- Convert stoppage time to a single integer minute, for example "45+2" becomes 47.',
      "- Put the primary player in the player field.",
      "- Put supporting context in details, such as scoreline, assist, or substitution in/out.",
      "- If the match is live but no qualifying events are confirmed yet, return an empty events array and keep match_status as LIVE.",
      "- If the match has not started, use match_status UPCOMING and return an empty events array with scores set to 0.",
    ].join("\n");
  }

  return [
    "You are a data extraction worker for a fantasy football backend.",
    `Today's UTC date is ${today}.`,
    `Use Google Search to find the current standard 1X2 betting odds for the football match "${matchLabel}" on ${today}.`,
    "Rules:",
    "- Return ONLY valid JSON matching the response schema.",
    "- Do not include markdown, prose, or code fences.",
    "- Use decimal odds only.",
    "- If the source shows fractional or American odds, convert them to decimal format.",
    "- Prefer mainstream sportsbook odds surfaced directly in Google Search results or cited reputable sources.",
    "- Do not invent values.",
  ].join("\n");
}

function getGeminiModel() {
  const gemini = new GoogleGenerativeAI(requireEnv("GEMINI_API_KEY"));

  // The legacy @google/generative-ai typings still expose googleSearchRetrieval,
  // but current Google Search grounding docs for Gemini 3 use googleSearch.
  const tools = [{ googleSearch: {} }] as unknown as Tool[];

  return gemini.getGenerativeModel({
    model: DEFAULT_GEMINI_MODEL,
    tools,
  });
}

function extractGroundingSummary(response: {
  candidates?: Array<{
    groundingMetadata?: {
      webSearchQueries?: string[];
      groundingChunks?: Array<{ web?: { uri?: string; title?: string } }>;
      retrievalMetadata?: { googleSearchDynamicRetrievalScore?: number };
    };
  }>;
}): GroundingSummary {
  const metadata = response.candidates?.[0]?.groundingMetadata;
  const sources = new Map<string, { uri: string; title: string | null }>();

  for (const chunk of metadata?.groundingChunks ?? []) {
    const uri = chunk.web?.uri?.trim();
    if (!uri) {
      continue;
    }

    sources.set(uri, {
      uri,
      title: chunk.web?.title?.trim() || null,
    });
  }

  return {
    webSearchQueries: metadata?.webSearchQueries ?? [],
    sources: Array.from(sources.values()),
    googleSearchDynamicRetrievalScore:
      metadata?.retrievalMetadata?.googleSearchDynamicRetrievalScore ?? null,
  };
}

export async function fetchStructuredMatchData(
  payload: MatchDataRequest,
): Promise<StructuredMatchDataResult<MatchEventsPayload | MatchOdds>> {
  const model = getGeminiModel();
  const schema = payload.fetchType === "events" ? eventsSchema : oddsSchema;

  const result = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: buildPrompt(payload) }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: schema,
      temperature: 0.1,
    },
  });

  const text = result.response.text();
  const grounding = extractGroundingSummary(result.response);

  if (payload.fetchType === "events") {
    return {
      data: parseMatchEventsPayload(parseMatchEventsJson(text)),
      grounding,
      rawText: text,
    };
  }

  return {
    data: parseOddsOutput(parseGeminiJson(text)),
    grounding,
    rawText: text,
  };
}
