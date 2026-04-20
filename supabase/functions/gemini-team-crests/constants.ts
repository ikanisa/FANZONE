export const FUNCTION_NAME = "gemini-team-crests";
export const DEFAULT_GEMINI_MODEL = Deno.env.get("GEMINI_MODEL")?.trim() ||
  "gemini-2.0-flash";
export const DEFAULT_GEMINI_FALLBACK_MODEL =
  Deno.env.get("GEMINI_FALLBACK_MODEL")?.trim() || "gemini-2.5-pro";
export const DEFAULT_GEMINI_SECOND_FALLBACK_MODEL =
  Deno.env.get("GEMINI_SECOND_FALLBACK_MODEL")?.trim() ||
  "gemini-2.5-flash";
export const DEFAULT_STORAGE_BUCKET =
  Deno.env.get("TEAM_CREST_BUCKET")?.trim() ||
  "team-crests";
export const MAX_BATCH_SIZE = 10;
export const DEFAULT_REFRESH_AFTER_HOURS = 24 * 30;
export const DEFAULT_DELAY_MS = 500;

export const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-team-crest-sync-secret";

export const OFFICIAL_REFRESH_HOURS = 24 * 90;
export const FEDERATION_REFRESH_HOURS = 24 * 60;
export const REFERENCE_REFRESH_HOURS = 24 * 30;
export const LOW_CONFIDENCE_RETRY_HOURS = 24 * 7;
export const INITIAL_FAILURE_RETRY_HOURS = 6;
export const MAX_FAILURE_RETRY_HOURS = 24 * 7;
