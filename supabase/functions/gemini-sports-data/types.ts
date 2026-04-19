import { EVENT_TYPES, MATCH_STATES } from "./constants.ts";

export type FetchType = "events" | "odds";
export type EventType = (typeof EVENT_TYPES)[number];
export type MatchState = (typeof MATCH_STATES)[number];

export interface MatchDataRequest {
  teamA: string;
  teamB: string;
  matchId: string;
  fetchType: FetchType;
}

export interface MatchEvent {
  minute: number;
  event_type: EventType;
  team: string;
  player: string;
  details: string;
}

export interface MatchEventsPayload {
  match_status: MatchState;
  home_score: number;
  away_score: number;
  events: MatchEvent[];
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
  status: string | null;
  ft_home: number | null;
  ft_away: number | null;
}

export interface GroundingSource {
  uri: string;
  title: string | null;
}

export interface GroundingSummary {
  webSearchQueries: string[];
  sources: GroundingSource[];
  googleSearchDynamicRetrievalScore: number | null;
}

export interface StructuredMatchDataResult<T> {
  data: T;
  grounding: GroundingSummary;
  rawText: string;
}

export type MatchPatch = Record<string, unknown>;

export interface PendingLiveMatchEventRow extends MatchEvent {
  match_id: string;
}
