/** Types for gemini-team-discovery edge function. */

export interface DiscoveredTeam {
  id: string;
  name: string;
  short_name: string;
  country: string;
  country_code: string;
  league_name: string;
  search_terms: string[];
  crest_url: string | null;
}

export interface GroundingSummary {
  webSearchQueries: string[];
  sources: Array<{ uri: string; title: string | null }>;
}

export interface LeagueDiscoveryResult {
  league_name: string;
  total_count: number;
  teams: DiscoveredTeam[];
  grounding: GroundingSummary;
}

export interface DiscoveryRequest {
  /** Process a single region or "all". */
  region?: "europe" | "africa" | "americas" | "north_america" | "all";
  /** Or process specific countries by code. */
  countries?: string[];
  /** Backward-compatible single-country request. */
  country_code?: string;
  /** Backward-compatible country label. */
  country_name?: string;
  /** Max countries to process (for testing). */
  limit?: number;
  /** Include Gemini grounding metadata in the response. */
  include_grounding?: boolean;
}

export interface CountryResult {
  countryCode: string;
  country: string;
  league: string;
  expectedTeams: number;
  teamsDiscovered: number;
  teamsUpserted: number;
  grounding?: GroundingSummary;
  error?: string;
}

export interface DiscoveryResponse {
  success: boolean;
  requestId: string;
  totalCountries: number;
  expectedTeams: number;
  totalTeamsDiscovered: number;
  totalTeamsUpserted: number;
  results: CountryResult[];
  errors: string[];
  durationMs: number;
}
