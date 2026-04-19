-- ============================================================
-- FANZONE Engagement Tables — REFERENCE SCHEMA
-- This file documents the REAL tables that the Flutter app queries.
-- These tables already exist in the Supabase database.
-- DO NOT re-run this file — it is for documentation only.
-- ============================================================

-- ======================
-- REAL TABLES (already exist in DB)
-- ======================

-- fet_wallets
--   user_id UUID PRIMARY KEY
--   available_balance_fet BIGINT
--   locked_balance_fet BIGINT
--   updated_at TIMESTAMPTZ
--   created_at TIMESTAMPTZ

-- fet_wallet_transactions
--   id UUID PRIMARY KEY
--   user_id UUID
--   tx_type TEXT
--   direction TEXT ('credit' | 'debit')
--   amount_fet BIGINT
--   balance_before_fet BIGINT
--   balance_after_fet BIGINT
--   reference_type TEXT
--   reference_id UUID
--   metadata JSONB
--   created_at TIMESTAMPTZ
--   title TEXT

-- prediction_challenges
--   id UUID PRIMARY KEY
--   match_id TEXT
--   creator_user_id UUID
--   stake_fet BIGINT
--   currency_code TEXT
--   status TEXT ('open' | 'locked' | 'settled' | 'cancelled')
--   lock_at TIMESTAMPTZ
--   settled_at TIMESTAMPTZ
--   cancelled_at TIMESTAMPTZ
--   void_reason TEXT
--   total_participants INT
--   total_pool_fet BIGINT
--   winner_count INT
--   loser_count INT
--   payout_per_winner_fet BIGINT
--   official_home_score INT
--   official_away_score INT
--   created_at TIMESTAMPTZ
--   updated_at TIMESTAMPTZ

-- prediction_challenge_entries
--   id UUID PRIMARY KEY
--   challenge_id UUID REFERENCES prediction_challenges(id)
--   user_id UUID
--   predicted_home_score INT
--   predicted_away_score INT
--   stake_fet BIGINT
--   status TEXT ('active' | 'won' | 'lost' | 'cancelled')
--   payout_fet BIGINT
--   joined_at TIMESTAMPTZ
--   settled_at TIMESTAMPTZ

-- challenge_feed (VIEW — read-only, used by Flutter for display)
--   id, match_id, home_team, away_team, match_name, creator_user_id,
--   creator_name, creator_prediction, stake_fet, status, lock_at,
--   settled_at, total_participants, total_pool_fet, winner_count,
--   payout_per_winner_fet, official_home_score, official_away_score,
--   date, kickoff_time

-- public_leaderboard (VIEW — read-only)
--   user_id UUID
--   fan_id TEXT
--   display_name TEXT
--   total_fet BIGINT

-- fan_clubs
--   id TEXT PRIMARY KEY
--   name TEXT
--   members INT
--   total_pool INT
--   crest TEXT
--   league TEXT
--   rank INT

-- user_followed_teams
--   user_id UUID
--   team_id TEXT
--   created_at TIMESTAMPTZ
--   PRIMARY KEY (user_id, team_id)

-- user_followed_competitions
--   user_id UUID
--   competition_id TEXT
--   created_at TIMESTAMPTZ
--   PRIMARY KEY (user_id, competition_id)

-- ======================
-- RPC FUNCTIONS
-- ======================

-- transfer_fet(p_recipient_email TEXT, p_amount INT)
--   SECURITY DEFINER — uses auth.uid() internally, never trusts client
--   Validates: authenticated, amount > 0, recipient exists, not self, sufficient balance
--   Debits sender fet_wallets, credits recipient, records fet_wallet_transactions
