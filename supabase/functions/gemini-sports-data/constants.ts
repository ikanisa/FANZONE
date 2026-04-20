export const FUNCTION_NAME = "gemini-sports-data";

export const DEFAULT_GEMINI_MODEL = (() => {
  try {
    return Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-2.5-flash";
  } catch {
    return "gemini-2.5-flash";
  }
})();

export const PROVIDER_NAME = "google_gemini_grounded";

export const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-match-sync-secret";

export const EVENT_TYPES = [
  "GOAL",
  "OWN_GOAL",
  "PENALTY_SCORED",
  "PENALTY_MISSED",
  "YELLOW_CARD",
  "RED_CARD",
  "SUBSTITUTION",
  "VAR_DECISION",
  "KICK_OFF",
  "HALF_TIME",
  "FULL_TIME",
] as const;

export const MATCH_STATES = [
  "LIVE",
  "FINISHED",
  "UPCOMING",
  "POSTPONED",
  "CANCELLED",
  "SUSPENDED",
  "UNKNOWN",
] as const;

export const MATCH_PHASES = [
  "PRE_MATCH",
  "FIRST_HALF",
  "HALF_TIME",
  "SECOND_HALF",
  "EXTRA_TIME",
  "PENALTIES",
  "FULL_TIME",
  "POSTPONED",
  "CANCELLED",
  "SUSPENDED",
  "UNKNOWN",
] as const;

export const CONFIRMED_CONFIDENCE_THRESHOLD = 0.82;
export const LOW_CONFIDENCE_THRESHOLD = 0.65;
