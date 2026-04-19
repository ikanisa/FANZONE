export const FUNCTION_NAME = "gemini-sports-data";
export const DEFAULT_GEMINI_MODEL = (() => {
  try {
    return Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-pro-preview";
  } catch {
    return "gemini-3.1-pro-preview";
  }
})();
export const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-match-sync-secret";

export const EVENT_TYPES = [
  "GOAL",
  "YELLOW_CARD",
  "RED_CARD",
  "SUBSTITUTION",
] as const;

export const MATCH_STATES = [
  "LIVE",
  "FINISHED",
  "UPCOMING",
  "POSTPONED",
  "CANCELLED",
  "UNKNOWN",
] as const;
