/** Represents a single fixture's odds extracted from a screenshot. */
export interface ExtractedFixtureOdds {
  /** Home team name as shown on the screenshot */
  home_team: string;
  /** Away team name as shown on the screenshot */
  away_team: string;
  /** Competition / league name if visible */
  competition: string | null;
  /** Kickoff time as shown, raw text */
  kickoff_text: string | null;
  /** Decimal odds for home win */
  home_odds: number;
  /** Decimal odds for draw */
  draw_odds: number;
  /** Decimal odds for away win */
  away_odds: number;
  /** Confidence that the extraction is correct (0-1) */
  confidence: number;
}

/** Full Gemini Vision extraction result from a single screenshot. */
export interface ScreenshotExtractionResult {
  /** Site detected (bet365, betway, etc.) */
  detected_site: string;
  /** Total fixtures visible on the screenshot */
  total_fixtures_found: number;
  /** Extracted odds for each fixture */
  fixtures: ExtractedFixtureOdds[];
  /** Notes about quality issues or partial visibility */
  extraction_notes: string[];
}

/** Result of capturing a screenshot. */
export interface CaptureResult {
  /** Base64-encoded PNG image data */
  imageBase64: string;
  /** Which provider was used */
  provider: string;
  /** Viewport dimensions */
  width: number;
  height: number;
}

/** A match from the database for fuzzy matching. */
export interface DbMatch {
  id: string;
  home_team: string;
  away_team: string;
  home_team_id: string | null;
  away_team_id: string | null;
  competition_id: string | null;
  date: string | null;
  kickoff_time: string | null;
  status: string | null;
}

/** Result of matching an extracted fixture to a DB match. */
export interface MatchResult {
  fixture: ExtractedFixtureOdds;
  dbMatch: DbMatch;
  matchScore: number;
}

/** Full pipeline run result. */
export interface PipelineRunResult {
  screenshotId: string;
  captureProvider: string;
  sourceUrl: string;
  fixturesFound: number;
  matchesLinked: number;
  oddsUpdated: number;
  errors: string[];
}
