import { PROVIDER_NAME } from "./constants.ts";
import type {
  CanonicalMatchEventRow,
  MatchEvent,
  MatchEventsPayload,
  MatchPatch,
  MatchSnapshot,
  MatchState,
  PendingLiveMatchEventRow,
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
    normalizeText(event.team),
    normalizeText(event.player),
    normalizeText(event.details),
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

export function normalizeText(value: string | null | undefined): string {
  return (value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeTeamName(value: string | null | undefined): string {
  return normalizeText(value)
    .replace(/\b(fc|cf|sc|afc|club|football)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function toDatabaseMatchStatus(matchStatus: MatchState): string | null {
  switch (matchStatus) {
    case "LIVE":
    case "SUSPENDED":
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

export function toDatabasePhase(phase: MatchEventsPayload["phase"]): string {
  switch (phase) {
    case "PRE_MATCH":
      return "pre_match";
    case "FIRST_HALF":
      return "first_half";
    case "HALF_TIME":
      return "half_time";
    case "SECOND_HALF":
      return "second_half";
    case "EXTRA_TIME":
      return "extra_time";
    case "PENALTIES":
      return "penalties";
    case "FULL_TIME":
      return "finished";
    case "POSTPONED":
      return "postponed";
    case "CANCELLED":
      return "cancelled";
    case "SUSPENDED":
      return "suspended";
    case "UNKNOWN":
      return "unknown";
  }
}

/**
 * Detects whether a score update would regress (go backwards) from what
 * is already stored.  This can happen when Gemini confuses two different
 * matches or when grounding latency makes an older result appear after a
 * newer one was already written.
 */
export function detectScoreRegression(
  match: MatchSnapshot,
  payload: MatchEventsPayload,
): { regressed: boolean; reason: string | null } {
  const existingHome = match.live_home_score ?? match.ft_home ?? 0;
  const existingAway = match.live_away_score ?? match.ft_away ?? 0;
  const existingTotal = existingHome + existingAway;
  const incomingTotal = payload.home_score + payload.away_score;

  // Only flag regression when flowing back to a *lower* total score
  // while the match is still considered live (goals don't un-happen).
  if (
    incomingTotal < existingTotal &&
    toDatabaseMatchStatus(payload.match_status) === "live"
  ) {
    return {
      regressed: true,
      reason:
        `Score regression detected: existing ${existingHome}-${existingAway} ` +
        `(total ${existingTotal}) → incoming ${payload.home_score}-${payload.away_score} ` +
        `(total ${incomingTotal}). Flagging for manual review.`,
    };
  }

  return { regressed: false, reason: null };
}

export function buildMatchPatch(
  match: MatchSnapshot,
  payload: MatchEventsPayload,
  nowIso: string,
  confidenceScore: number,
  reviewRequired: boolean,
): MatchPatch | null {
  const patch: MatchPatch = {
    updated_at: nowIso,
    last_live_checked_at: nowIso,
    last_live_sync_confidence: confidenceScore,
    last_live_review_required: reviewRequired,
  };

  const currentStatus = normalizeText(match.status);
  const nextStatus = toDatabaseMatchStatus(payload.match_status);
  const phase = toDatabasePhase(payload.phase);

  if (currentStatus === "finished" && nextStatus !== "finished") {
    return patch;
  }

  // Guard: detect score regression (goals can't un-happen in live play)
  const regression = detectScoreRegression(match, payload);
  if (regression.regressed) {
    patch.last_live_review_required = true;
    // Still update timestamp/confidence, but do NOT overwrite scores
    return patch;
  }

  if (nextStatus === "live") {
    patch.status = "live";
    patch.live_home_score = payload.home_score;
    patch.live_away_score = payload.away_score;
    patch.live_minute = payload.minute;
    patch.live_phase = phase;
  } else if (nextStatus === "finished") {
    patch.status = "finished";
    patch.ft_home = payload.home_score;
    patch.ft_away = payload.away_score;
    patch.live_home_score = payload.home_score;
    patch.live_away_score = payload.away_score;
    patch.live_minute = payload.minute;
    patch.live_phase = "finished";
  } else if (nextStatus === "postponed" || nextStatus === "cancelled") {
    patch.status = nextStatus;
    patch.live_phase = phase;
    patch.live_minute = payload.minute;
  } else if (nextStatus === "upcoming") {
    if (currentStatus !== "live") {
      patch.status = "upcoming";
    }
    patch.live_home_score = payload.home_score;
    patch.live_away_score = payload.away_score;
    patch.live_minute = payload.minute;
    patch.live_phase = phase;
  }

  return patch;
}

function mapEventTypeToCanonical(
  eventType: MatchEvent["event_type"],
): CanonicalMatchEventRow["event_type"] {
  switch (eventType) {
    case "GOAL":
      return "goal";
    case "OWN_GOAL":
      return "own_goal";
    case "PENALTY_SCORED":
      return "penalty_scored";
    case "PENALTY_MISSED":
      return "penalty_missed";
    case "YELLOW_CARD":
      return "yellow_card";
    case "RED_CARD":
      return "red_card";
    case "SUBSTITUTION":
      return "substitution";
    case "VAR_DECISION":
      return "var_decision";
    case "KICK_OFF":
      return "kick_off";
    case "HALF_TIME":
      return "half_time";
    case "FULL_TIME":
      return "full_time";
  }
}

function mapTeamId(match: MatchSnapshot, teamName: string): string | null {
  const normalized = normalizeTeamName(teamName);
  const home = normalizeTeamName(match.home_team);
  const away = normalizeTeamName(match.away_team);

  if (
    normalized === home || normalized.includes(home) ||
    home.includes(normalized)
  ) {
    return match.home_team_id;
  }

  if (
    normalized === away || normalized.includes(away) ||
    away.includes(normalized)
  ) {
    return match.away_team_id;
  }

  return null;
}

export function buildCanonicalEventRows(
  match: MatchSnapshot,
  events: MatchEvent[],
  confidenceScore: number,
  sourcePayload: Record<string, unknown>,
): CanonicalMatchEventRow[] {
  return events.map((event) => ({
    match_id: match.id,
    minute: event.minute,
    event_type: mapEventTypeToCanonical(event.event_type),
    team_id: mapTeamId(match, event.team),
    team_name: event.team,
    player_name: event.player || null,
    assist_player_name: event.assist_player || null,
    description: event.details || null,
    metadata: {
      raw_event_type: event.event_type,
      raw_team: event.team,
      raw_player: event.player,
      assist_player: event.assist_player,
    },
    source_provider: PROVIDER_NAME,
    source_confidence: confidenceScore,
    source_payload: sourcePayload,
  }));
}

export function buildLiveEventRows(
  matchId: string,
  events: MatchEvent[],
  confidenceScore: number,
  sourcePayload: Record<string, unknown>,
): PendingLiveMatchEventRow[] {
  return events.map((event) => ({
    ...event,
    match_id: matchId,
    provider: PROVIDER_NAME,
    confidence_score: confidenceScore,
    source_payload: sourcePayload,
  }));
}
