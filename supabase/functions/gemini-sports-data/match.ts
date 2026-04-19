import type {
  MatchEvent,
  MatchEventsPayload,
  MatchPatch,
  MatchSnapshot,
  MatchState,
} from "./types.ts";

export function getEventSignature(
  event: Pick<
    MatchEvent,
    "minute" | "event_type" | "team" | "player" | "details"
  >,
): string {
  return [
    event.minute,
    event.event_type,
    event.team.toLowerCase(),
    event.player.toLowerCase(),
    event.details.toLowerCase(),
  ].join("|");
}

export function dedupeEvents(events: MatchEvent[]): MatchEvent[] {
  const seen = new Set<string>();

  return events.filter((event) => {
    const key = getEventSignature(event);
    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

function normalizeTeamName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function toDatabaseMatchStatus(matchStatus: MatchState): string | null {
  switch (matchStatus) {
    case "LIVE":
      return "live";
    case "FINISHED":
      return "finished";
    case "UPCOMING":
      return "upcoming";
    case "POSTPONED":
      return "postponed";
    case "CANCELLED":
      return "cancelled";
    case "UNKNOWN":
      return null;
  }
}

export function buildMatchPatch(
  match: MatchSnapshot,
  payload: MatchEventsPayload,
): MatchPatch | null {
  const patch: MatchPatch = {
    updated_at: new Date().toISOString(),
  };

  const nextStatus = toDatabaseMatchStatus(payload.match_status);
  if (
    nextStatus && match.status !== "cancelled" &&
    (match.status !== "finished" || nextStatus === "finished")
  ) {
    patch.status = nextStatus;
  }

  if (payload.match_status === "UNKNOWN") {
    const homeKey = normalizeTeamName(match.home_team);
    const awayKey = normalizeTeamName(match.away_team);

    let homeGoals = 0;
    let awayGoals = 0;

    for (const event of payload.events) {
      if (event.event_type !== "GOAL") {
        continue;
      }

      const eventTeam = normalizeTeamName(event.team);
      if (eventTeam === homeKey) {
        homeGoals += 1;
      } else if (eventTeam === awayKey) {
        awayGoals += 1;
      }
    }

    if (homeGoals > 0 || awayGoals > 0) {
      patch.ft_home = homeGoals;
      patch.ft_away = awayGoals;
    }
  } else if (
    payload.match_status === "LIVE" || payload.match_status === "FINISHED"
  ) {
    patch.ft_home = payload.home_score;
    patch.ft_away = payload.away_score;
  }

  if (
    patch["status"] == null &&
    patch["ft_home"] == null &&
    patch["ft_away"] == null
  ) {
    return null;
  }

  return patch;
}
