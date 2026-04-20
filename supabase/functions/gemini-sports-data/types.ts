import type { EVENT_TYPES, MATCH_PHASES, MATCH_STATES } from "./constants.ts";

export type FetchType = "events" | "odds";
export type EventType = (typeof EVENT_TYPES)[number];
export type MatchState = (typeof MATCH_STATES)[number];
export type MatchPhase = (typeof MATCH_PHASES)[number];

export interface MatchDataRequest {
  teamA: string;
  teamB: string;
  matchId: string;
  fetchType: FetchType;
  competitionName?: string | null;
  sourceUrl?: string | null;
  kickoffAt?: string | null;
}

export interface MatchEvent {
  minute: number;
  event_type: EventType;
  team: string;
  player: string;
  assist_player?: string | null;
  details: string;
}

export interface MatchEventsPayload {
  match_status: MatchState;
  phase: MatchPhase;
  minute: number | null;
  home_score: number;
  away_score: number;
  events: MatchEvent[];
  summary: string | null;
  uncertainty_notes: string[];
}

export interface MatchOdds {
  home_multiplier: number;
  draw_multiplier: number;
  away_multiplier: number;
}

export interface MatchSnapshot {
  id: string;
  home_team: string;
  away_team: string;
  home_team_id: string | null;
  away_team_id: string | null;
  status: string | null;
  ft_home: number | null;
  ft_away: number | null;
  live_home_score: number | null;
  live_away_score: number | null;
  live_minute: number | null;
  live_phase: string | null;
  source_url: string | null;
}

export interface TrustedMatchSource {
  domain_pattern: string;
  source_name: string;
  source_type: string;
  trust_score: number;
  active: boolean;
}

export interface RuntimeSettings {
  live_poll_interval_seconds: number;
  low_confidence_backoff_seconds: number;
  failed_backoff_seconds: number;
}

export interface GroundingSource {
  uri: string;
  title: string | null;
  domain: string | null;
  source_type: string;
  trust_score: number;
  trusted: boolean;
}

export interface UrlContextResultSummary {
  retrievedUrl: string;
  status: string;
}

export interface GroundingSummary {
  webSearchQueries: string[];
  sources: GroundingSource[];
  urlContextResults: UrlContextResultSummary[];
  googleSearchDynamicRetrievalScore: number | null;
}

export interface StructuredMatchDataResult<T> {
  data: T;
  grounding: GroundingSummary;
  rawText: string;
}

export type MatchPatch = Record<string, unknown>;

export interface LiveStatePatch {
  match_id: string;
  status: string;
  minute: number | null;
  phase: string;
  home_score: number;
  away_score: number;
  confidence_score: number;
  confidence_status: "confirmed" | "low_confidence" | "manual_review";
  review_required: boolean;
  review_reason: string | null;
  provider: string;
  last_checked_at: string;
  last_success_at: string | null;
  next_check_at: string | null;
  last_event_count: number;
  last_error: string | null;
  consecutive_failures: number;
  grounding_sources: Array<Record<string, unknown>>;
  source_payload: Record<string, unknown>;
  updated_at: string;
}

export interface PendingLiveMatchEventRow extends MatchEvent {
  match_id: string;
  provider: string;
  confidence_score: number;
  source_payload: Record<string, unknown>;
}

export interface CanonicalMatchEventRow {
  match_id: string;
  minute: number;
  event_type:
    | "goal"
    | "own_goal"
    | "penalty_scored"
    | "penalty_missed"
    | "yellow_card"
    | "red_card"
    | "substitution"
    | "var_decision"
    | "kick_off"
    | "half_time"
    | "full_time";
  team_id: string | null;
  team_name: string | null;
  player_name: string | null;
  assist_player_name: string | null;
  description: string | null;
  metadata: Record<string, unknown>;
  source_provider: string;
  source_confidence: number;
  source_payload: Record<string, unknown>;
}

export interface ValidationResult {
  confidence_score: number;
  status: "confirmed" | "low_confidence" | "manual_review";
  flags: string[];
  review_reason: string | null;
  official_sources: number;
  trusted_sources: number;
}

export interface MatchRunSummary {
  insertedLiveEventCount: number;
  insertedMatchEventCount: number;
  updatedMatch: boolean;
}
