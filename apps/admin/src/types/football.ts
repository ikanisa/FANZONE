export interface Competition {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  tier: number | null;
  competition_type?: string | null;
  is_international?: boolean;
  is_active?: boolean;
  created_at: string;
  updated_at?: string;
}

export interface Match {
  id: string;
  competition_id: string;
  competition_name?: string | null;
  season_id?: string | null;
  season_label?: string | null;
  season?: string | null;
  stage?: string | null;
  round: string | null;
  matchday_or_round?: string | null;
  date: string;
  match_date?: string | null;
  kickoff_time: string | null;
  home_team_id: string | null;
  away_team_id: string | null;
  home_team: string;
  away_team: string;
  ft_home: number | null;
  ft_away: number | null;
  home_goals?: number | null;
  away_goals?: number | null;
  result_code?: string | null;
  status: string;
  match_status?: string | null;
  is_neutral?: boolean;
  data_source?: string | null;
  source_name?: string | null;
  source_url: string | null;
  notes?: string | null;
  home_logo_url: string | null;
  away_logo_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Team {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  country_id?: string | null;
  popularity_score?: number | null;
  competition_ids: string[] | null;
  logo_url: string | null;
  slug: string | null;
  crest_url: string | null;
  cover_image_url: string | null;
  description: string | null;
  league_name: string | null;
  is_active: boolean;
  is_featured: boolean;
  fan_count: number;
  created_at: string;
  updated_at: string;
}
