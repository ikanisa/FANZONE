export type TeamCrestInput = {
  team_id: string;
  team_name: string;
  competition: string | null;
  country: string | null;
  aliases: string[];
};

export type CrestFetchOptions = {
  force: boolean;
  apply_to_team: boolean;
  dry_run: boolean;
  refresh_if_older_than_hours: number;
  delay_ms: number;
};

export type ParsedRequestPayload = {
  teams: TeamCrestInput[];
  options: CrestFetchOptions;
};

export type GeminiSourceType =
  | "official_club"
  | "official_federation"
  | "official_competition"
  | "trusted_reference"
  | "unknown";

export type GeminiCrestCandidate = {
  source_url: string;
  image_url: string;
  source_name: string | null;
  source_domain: string | null;
  source_type: GeminiSourceType;
  matched_name: string | null;
  matched_alias: string | null;
  official_signal: string | null;
  match_reason: string | null;
  competition_match: boolean;
  country_match: boolean;
  validation_notes: string | null;
};

export type GeminiAlternativeCandidate = {
  source_url: string | null;
  image_url: string | null;
  source_domain: string | null;
  source_type: GeminiSourceType;
  reason: string | null;
};

export type GeminiCrestResponse = {
  selected_candidate: GeminiCrestCandidate | null;
  alternative_candidates: GeminiAlternativeCandidate[];
  search_summary: string | null;
};

export type GroundingSummary = {
  sources: Array<{ uri: string; title: string | null }>;
  grounded_urls: string[];
};

export type GeminiLookupResult = {
  raw_response: Record<string, unknown>;
  parsed: GeminiCrestResponse;
  grounding: GroundingSummary;
  model_name: string;
};

export type ImageFetchResult = {
  final_url: string;
  content_type: string;
  extension: string;
  bytes: Uint8Array;
  sha256: string;
};

export type ValidationResult = {
  confidence_score: number;
  status: "fetched" | "low_confidence" | "manual_review" | "failed";
  flags: string[];
  notes: string | null;
};

export type TeamSnapshot = {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  league_name: string | null;
  crest_url: string | null;
  logo_url: string | null;
};

export type ExistingCrestMetadata = {
  team_id: string;
  image_url: string | null;
  remote_image_url: string | null;
  storage_path: string | null;
  image_sha256: string | null;
  source_url: string | null;
  source_domain: string | null;
  status: string;
  confidence_score: number | null;
  retry_count: number;
  fetch_count: number;
  last_attempt_at: string | null;
  stale_after: string | null;
  next_retry_at: string | null;
};

export type TeamCrestOutput = {
  team_id: string;
  team_name: string;
  source_url: string | null;
  image_url: string | null;
  source_domain: string | null;
  confidence_score: number;
  fetched_at: string;
  status:
    | "fetched"
    | "low_confidence"
    | "manual_review"
    | "failed"
    | "skipped";
};
