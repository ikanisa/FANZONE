export interface Competition {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
  tier: number | null;
  created_at: string;
}

export interface Match {
  id: string;
  competition_id: string;
  season: string;
  round: string | null;
  match_group: string | null;
  date: string;
  kickoff_time: string | null;
  home_team_id: string | null;
  away_team_id: string | null;
  home_team: string;
  away_team: string;
  ft_home: number | null;
  ft_away: number | null;
  ht_home: number | null;
  ht_away: number | null;
  et_home: number | null;
  et_away: number | null;
  status: string;
  venue: string | null;
  data_source: string;
  source_url: string | null;
  home_logo_url: string | null;
  away_logo_url: string | null;
  home_multiplier: number | null;
  draw_multiplier: number | null;
  away_multiplier: number | null;
  created_at: string;
  updated_at: string;
}

export interface Team {
  id: string;
  name: string;
  short_name: string | null;
  country: string | null;
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

export interface Challenge {
  id: string;
  match_id: string;
  creator_user_id: string;
  stake_fet: number;
  currency_code: string | null;
  status: string;
  lock_at: string;
  settled_at: string | null;
  cancelled_at: string | null;
  void_reason: string | null;
  total_participants: number;
  total_pool_fet: number;
  winner_count: number | null;
  loser_count: number | null;
  payout_per_winner_fet: number | null;
  official_home_score: number | null;
  official_away_score: number | null;
  created_at: string;
  updated_at: string;
}

export interface ChallengeEntry {
  id: string;
  challenge_id: string;
  user_id: string;
  predicted_home_score: number;
  predicted_away_score: number;
  stake_fet: number;
  status: string;
  payout_fet: number | null;
  joined_at: string;
  settled_at: string | null;
}
