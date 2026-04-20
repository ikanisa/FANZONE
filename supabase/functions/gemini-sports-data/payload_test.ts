import { HttpError } from "./http.ts";
import {
  parseMatchEventsJson,
  parseMatchEventsPayload,
  parseOddsOutput,
  parseRequestPayload,
} from "./payload.ts";

Deno.test("parseRequestPayload accepts valid requests with grounding context", () => {
  const payload = parseRequestPayload({
    teamA: "Arsenal",
    teamB: "Chelsea",
    matchId: "match-1",
    fetchType: "events",
    competitionName: "Premier League",
    sourceUrl: "https://www.premierleague.com/match/1",
    kickoffAt: "2026-04-20T17:00:00Z",
  });

  if (
    payload.teamA !== "Arsenal" ||
    payload.teamB !== "Chelsea" ||
    payload.matchId !== "match-1" ||
    payload.fetchType !== "events" ||
    payload.competitionName !== "Premier League" ||
    payload.sourceUrl !== "https://www.premierleague.com/match/1" ||
    payload.kickoffAt !== "2026-04-20T17:00:00Z"
  ) {
    throw new Error("Expected request payload to be preserved");
  }
});

Deno.test("parseRequestPayload rejects unsupported fetch types", () => {
  try {
    parseRequestPayload({
      teamA: "Arsenal",
      teamB: "Chelsea",
      matchId: "match-1",
      fetchType: "stats",
    });
    throw new Error("Expected invalid fetchType to throw");
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 400) {
      throw error;
    }
  }
});

Deno.test("parseMatchEventsPayload dedupes duplicate events", () => {
  const payload = parseMatchEventsPayload({
    match_status: "LIVE",
    phase: "FIRST_HALF",
    minute: 12,
    home_score: 1,
    away_score: 0,
    events: [
      {
        minute: 12,
        event_type: "GOAL",
        team: "Arsenal",
        player: "Saka",
        details: "1-0",
      },
      {
        minute: 12,
        event_type: "GOAL",
        team: "Arsenal",
        player: "Saka",
        details: "1-0",
      },
    ],
    summary: "Arsenal lead 1-0.",
    uncertainty_notes: [],
  });

  if (payload.events.length !== 1 || payload.phase !== "FIRST_HALF") {
    throw new Error("Expected duplicate events to be collapsed");
  }
});

Deno.test("parseMatchEventsJson recovers score snapshot from malformed JSON", () => {
  const parsed = parseMatchEventsJson(`{
    "match_status": "LIVE",
    "phase": "SECOND_HALF",
    "minute": 67,
    "home_score": 2,
    "away_score": 1,
    "events": [`);

  const payload = parseMatchEventsPayload(parsed);
  if (
    payload.match_status !== "LIVE" ||
    payload.phase !== "SECOND_HALF" ||
    payload.minute !== 67 ||
    payload.home_score !== 2 ||
    payload.away_score !== 1 ||
    payload.events.length !== 0
  ) {
    throw new Error("Expected fallback score snapshot to be recovered");
  }
});

Deno.test("parseOddsOutput rounds decimal multipliers", () => {
  const odds = parseOddsOutput({
    home_multiplier: 1.23456,
    draw_multiplier: "3.45678",
    away_multiplier: 5.67891,
  });

  if (
    odds.home_multiplier !== 1.235 ||
    odds.draw_multiplier !== 3.457 ||
    odds.away_multiplier !== 5.679
  ) {
    throw new Error("Expected odds to be normalized to 3 decimal places");
  }
});
