export const FUNCTION_NAME = "screenshot-odds-extract";
export const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
export const DEFAULT_GEMINI_FALLBACK_MODEL = "gemini-2.5-pro";

export const ALLOWED_HEADERS = [
  "authorization",
  "x-client-info",
  "content-type",
  "x-match-sync-secret",
].join(", ");

/**
 * Primary odds source: bwin.com (official bookmaker).
 * Confirmed working with headless Chrome — renders full 1X2 odds.
 *
 * Capture is done locally via scripts/capture-odds.mjs (Puppeteer),
 * then images are sent to this Edge Function via imageBase64.
 *
 * These URLs are kept as a reference / fallback for cloud capture mode.
 */
export const DEFAULT_CAPTURE_URLS = [
  // bwin Featured Football — all live + upcoming 1X2 odds
  "https://sports.bwin.com/en/sports/football-4",
];

/** Capture providers — used only for cloud capture fallback (not primary flow) */
export const CAPTURE_PROVIDERS = ["browserless", "screenshotone"] as const;
export type CaptureProvider = (typeof CAPTURE_PROVIDERS)[number];
