import { buildMatchPatch, dedupeEvents } from "./match.ts";
import type { MatchEvent, MatchSnapshot } from "./types.ts";

const nowIso = "2026-04-20T12:00:00.000Z";

const snapshot: MatchSnapshot = {
  id: "match-1",
  home_team: "Arsenal",
  away_team: "Chelsea",
  home_team_id: "team-1",
  away_team_id: "team-2",
  status: "upcoming",
  ft_home: null,
  ft_away: null,
  live_home_score: null,
  live_away_score: null,
  live_minute: null,
  live_phase: null,
  source_url: null,
};

Deno.test("dedupeEvents removes duplicate signatures", () => {
  const duplicated: MatchEvent[] = [
    {
      minute: 10,
      event_type: "GOAL",
      team: "Arsenal",
      player: "Saka",
      details: "1-0",
    },
    {
      minute: 10,
      event_type: "GOAL",
      team: "Arsenal",
      player: "Saka",
      details: "1-0",
    },
  ];

  if (dedupeEvents(duplicated).length !== 1) {
    throw new Error("Expected duplicate events to be removed");
  }
});

Deno.test("buildMatchPatch stores live scores in live projection fields only", () => {
  const patch = buildMatchPatch(
    snapshot,
    {
      match_status: "LIVE",
      phase: "FIRST_HALF",
      minute: 27,
      home_score: 2,
      away_score: 1,
      events: [],
      summary: "Arsenal lead 2-1 in the first half.",
      uncertainty_notes: [],
    },
    nowIso,
    0.91,
    false,
  );

  if (
    patch == null ||
    patch["status"] !== "live" ||
    patch["live_home_score"] !== 2 ||
    patch["live_away_score"] !== 1 ||
    patch["live_minute"] !== 27 ||
    patch["live_phase"] !== "first_half" ||
    patch["ft_home"] != null ||
    patch["ft_away"] != null
  ) {
    throw new Error(
      "Expected live score snapshot to update only live projection fields",
    );
  }
});

Deno.test("buildMatchPatch finalizes scores only when match is finished", () => {
  const patch = buildMatchPatch(
    snapshot,
    {
      match_status: "FINISHED",
      phase: "FULL_TIME",
      minute: 90,
      home_score: 3,
      away_score: 1,
      events: [],
      summary: "Full time.",
      uncertainty_notes: [],
    },
    nowIso,
    0.95,
    false,
  );

  if (
    patch == null ||
    patch["status"] !== "finished" ||
    patch["ft_home"] !== 3 ||
    patch["ft_away"] !== 1 ||
    patch["live_home_score"] !== 3 ||
    patch["live_away_score"] !== 1 ||
    patch["live_phase"] !== "finished"
  ) {
    throw new Error("Expected finished match snapshot to persist final score");
  }
});

Deno.test("buildMatchPatch does not downgrade a finished match back to live", () => {
  const patch = buildMatchPatch(
    {
      ...snapshot,
      status: "finished",
      ft_home: 2,
      ft_away: 0,
      live_home_score: 2,
      live_away_score: 0,
      live_phase: "finished",
    },
    {
      match_status: "LIVE",
      phase: "SECOND_HALF",
      minute: 60,
      home_score: 1,
      away_score: 0,
      events: [],
      summary: null,
      uncertainty_notes: ["Conflicting live source."],
    },
    nowIso,
    0.41,
    true,
  );

  if (
    patch == null ||
    patch["status"] != null ||
    patch["ft_home"] != null ||
    patch["ft_away"] != null ||
    patch["last_live_review_required"] !== true
  ) {
    throw new Error("Expected finished match state to remain unchanged");
  }
});
