import { buildMatchPatch, dedupeEvents } from "./match.ts";
import type { MatchEvent, MatchSnapshot } from "./types.ts";

const snapshot: MatchSnapshot = {
  id: "match-1",
  home_team: "Arsenal",
  away_team: "Chelsea",
  status: "upcoming",
  ft_home: null,
  ft_away: null,
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

Deno.test("buildMatchPatch uses explicit live score when match status is known", () => {
  const patch = buildMatchPatch(snapshot, {
    match_status: "LIVE",
    home_score: 2,
    away_score: 1,
    events: [],
  });

  if (
    patch == null || patch["status"] !== "live" || patch["ft_home"] !== 2 ||
    patch["ft_away"] !== 1
  ) {
    throw new Error("Expected live score snapshot to be mapped");
  }
});

Deno.test("buildMatchPatch infers score from goal events when status is unknown", () => {
  const patch = buildMatchPatch(snapshot, {
    match_status: "UNKNOWN",
    home_score: 0,
    away_score: 0,
    events: [
      {
        minute: 14,
        event_type: "GOAL",
        team: "Arsenal",
        player: "Saka",
        details: "1-0",
      },
      {
        minute: 33,
        event_type: "GOAL",
        team: "Chelsea",
        player: "Palmer",
        details: "1-1",
      },
    ],
  });

  if (
    patch == null || patch["ft_home"] !== 1 || patch["ft_away"] !== 1 ||
    patch["status"] != null
  ) {
    throw new Error("Expected goal events to produce a derived score snapshot");
  }
});

Deno.test("buildMatchPatch returns null when no usable state change exists", () => {
  const patch = buildMatchPatch(snapshot, {
    match_status: "UNKNOWN",
    home_score: 0,
    away_score: 0,
    events: [],
  });

  if (patch !== null) {
    throw new Error("Expected empty unknown snapshot to be ignored");
  }
});
