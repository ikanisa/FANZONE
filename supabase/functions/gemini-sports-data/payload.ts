import { EVENT_TYPES, MATCH_STATES } from "./constants.ts";
import { HttpError } from "./http.ts";
import { dedupeEvents } from "./match.ts";
import type {
  EventType,
  MatchDataRequest,
  MatchEvent,
  MatchEventsPayload,
  MatchOdds,
  MatchState,
} from "./types.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readRequiredString(
  value: unknown,
  fieldName: string,
  options: { allowEmpty?: boolean } = {},
): string {
  if (typeof value !== "string") {
    throw new HttpError(400, `${fieldName} must be a string.`);
  }

  const trimmed = value.trim();
  if (!options.allowEmpty && !trimmed) {
    throw new HttpError(400, `${fieldName} cannot be empty.`);
  }

  return trimmed;
}

function toFiniteNumber(value: unknown, fieldName: string): number {
  const numeric = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;

  if (!Number.isFinite(numeric)) {
    throw new HttpError(502, `Gemini returned a non-numeric ${fieldName}.`);
  }

  return numeric;
}

function parseEvent(output: unknown): MatchEvent {
  if (!isRecord(output)) {
    throw new HttpError(502, "Each event must be a JSON object.");
  }

  const minute = toFiniteNumber(output.minute, "minute");
  if (!Number.isInteger(minute) || minute < 0) {
    throw new HttpError(502, "Gemini returned an invalid event minute.");
  }

  const eventType = readRequiredString(output.event_type, "event_type");
  if (!EVENT_TYPES.includes(eventType as EventType)) {
    throw new HttpError(502, `Unsupported event_type received: ${eventType}`);
  }

  return {
    minute,
    event_type: eventType as EventType,
    team: readRequiredString(output.team, "team"),
    player: readRequiredString(output.player, "player"),
    details: readRequiredString(output.details, "details", {
      allowEmpty: true,
    }),
  };
}

function parseEventsOutput(output: unknown): MatchEvent[] {
  if (!Array.isArray(output)) {
    throw new HttpError(502, "Gemini events response must be a JSON array.");
  }

  return dedupeEvents(output.map(parseEvent));
}

export function parseRequestPayload(input: unknown): MatchDataRequest {
  if (!isRecord(input)) {
    throw new HttpError(400, "Request body must be a JSON object.");
  }

  const teamA = readRequiredString(input.teamA, "teamA");
  const teamB = readRequiredString(input.teamB, "teamB");
  const matchId = readRequiredString(input.matchId, "matchId");
  const fetchType = readRequiredString(input.fetchType, "fetchType");

  if (fetchType !== "events" && fetchType !== "odds") {
    throw new HttpError(
      400,
      "fetchType must be either 'events' or 'odds'.",
    );
  }

  return { teamA, teamB, matchId, fetchType };
}

export function parseMatchEventsPayload(output: unknown): MatchEventsPayload {
  if (!isRecord(output)) {
    throw new HttpError(
      502,
      "Gemini events response must be a JSON object.",
    );
  }

  const matchStatus = readRequiredString(output.match_status, "match_status");
  if (!MATCH_STATES.includes(matchStatus as MatchState)) {
    throw new HttpError(
      502,
      `Unsupported match_status received: ${matchStatus}`,
    );
  }

  const homeScore = toFiniteNumber(output.home_score, "home_score");
  const awayScore = toFiniteNumber(output.away_score, "away_score");

  if (
    !Number.isInteger(homeScore) || !Number.isInteger(awayScore) ||
    homeScore < 0 || awayScore < 0
  ) {
    throw new HttpError(502, "Gemini returned an invalid score snapshot.");
  }

  return {
    match_status: matchStatus as MatchState,
    home_score: homeScore,
    away_score: awayScore,
    events: parseEventsOutput(output.events),
  };
}

export function parseOddsOutput(output: unknown): MatchOdds {
  if (!isRecord(output)) {
    throw new HttpError(502, "Gemini odds response must be a JSON object.");
  }

  const home_multiplier = toFiniteNumber(
    output.home_multiplier,
    "home_multiplier",
  );
  const draw_multiplier = toFiniteNumber(
    output.draw_multiplier,
    "draw_multiplier",
  );
  const away_multiplier = toFiniteNumber(
    output.away_multiplier,
    "away_multiplier",
  );

  if (
    home_multiplier <= 0 || draw_multiplier <= 0 || away_multiplier <= 0
  ) {
    throw new HttpError(
      502,
      "Gemini returned an invalid odds payload with non-positive multipliers.",
    );
  }

  return {
    home_multiplier: Number(home_multiplier.toFixed(3)),
    draw_multiplier: Number(draw_multiplier.toFixed(3)),
    away_multiplier: Number(away_multiplier.toFixed(3)),
  };
}

function stripJsonFences(text: string): string {
  const trimmed = text.trim();

  if (!trimmed.startsWith("```")) {
    return trimmed;
  }

  return trimmed
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
}

export function parseGeminiJson(text: string): unknown {
  const normalized = stripJsonFences(text);

  if (!normalized) {
    throw new HttpError(502, "Gemini returned an empty response body.");
  }

  try {
    return JSON.parse(normalized);
  } catch {
    throw new HttpError(502, "Gemini returned malformed JSON.", {
      responsePreview: normalized.slice(0, 500),
    });
  }
}

export function parseMatchEventsJson(text: string): unknown {
  try {
    return parseGeminiJson(text);
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 502) {
      throw error;
    }

    const normalized = stripJsonFences(text);
    const matchStatus = normalized.match(
      /"match_status"\s*:\s*"([^"]+)"/,
    )?.[1];
    const homeScore = normalized.match(/"home_score"\s*:\s*(\d+)/)?.[1];
    const awayScore = normalized.match(/"away_score"\s*:\s*(\d+)/)?.[1];

    if (matchStatus && homeScore && awayScore) {
      return {
        match_status: matchStatus,
        home_score: Number(homeScore),
        away_score: Number(awayScore),
        events: [],
      };
    }

    throw error;
  }
}
