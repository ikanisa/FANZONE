-- ============================================================
-- 001_engagement_tables.sql
-- Authoritative bootstrap for core FANZONE engagement objects.
--
-- Canonical bootstrap for the early FANZONE engagement schema.
-- Kept at version `001` so existing environments stay aligned while
-- fresh environments can still build from the migration chain alone.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- Core helper: resolve a user's phone number from auth.users
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.resolve_auth_user_phone(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_phone text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(
    nullif(trim(u.phone), ''),
    nullif(trim(u.raw_user_meta_data->>'phone_number'), ''),
    nullif(trim(u.raw_user_meta_data->>'phone'), '')
  )
  INTO v_phone
  FROM auth.users u
  WHERE u.id = p_user_id;

  RETURN v_phone;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_auth_user_phone(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_auth_user_phone(uuid) TO authenticated;

-- -----------------------------------------------------------------
-- Profiles + preferences foundation
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  phone_number text,
  favorite_team_id text,
  favorite_team_name text,
  favorite_malta_team text,
  favorite_euro_team text,
  active_country text,
  country_code text,
  currency_code text DEFAULT 'EUR',
  onboarding_completed boolean NOT NULL DEFAULT false,
  fan_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_number text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS favorite_team_id text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS favorite_team_name text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS favorite_malta_team text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS favorite_euro_team text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS active_country text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS country_code text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'EUR';
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fan_id text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.profiles
SET user_id = id
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_user_id_unique
  ON public.profiles (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_fan_id_unique
  ON public.profiles (fan_id)
  WHERE fan_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.app_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_preferences
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.app_preferences
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_preferences ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users read own profile'
  ) THEN
    CREATE POLICY "Users read own profile"
      ON public.profiles
      FOR SELECT
      TO authenticated
      USING (auth.uid() = id OR auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users insert own profile'
  ) THEN
    CREATE POLICY "Users insert own profile"
      ON public.profiles
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = id OR auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users update own profile'
  ) THEN
    CREATE POLICY "Users update own profile"
      ON public.profiles
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = id OR auth.uid() = user_id)
      WITH CHECK (auth.uid() = id OR auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'app_preferences'
      AND policyname = 'Users manage own app preferences'
  ) THEN
    CREATE POLICY "Users manage own app preferences"
      ON public.app_preferences
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_preferences TO authenticated;

-- -----------------------------------------------------------------
-- Wallet foundation
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fet_wallets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  available_balance_fet bigint NOT NULL DEFAULT 0,
  locked_balance_fet bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fet_wallets_available_non_negative CHECK (available_balance_fet >= 0),
  CONSTRAINT fet_wallets_locked_non_negative CHECK (locked_balance_fet >= 0)
);

ALTER TABLE public.fet_wallets
  ADD COLUMN IF NOT EXISTS available_balance_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.fet_wallets
  ADD COLUMN IF NOT EXISTS locked_balance_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.fet_wallets
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.fet_wallets
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_fet_wallets_updated_at
  ON public.fet_wallets (updated_at DESC);

CREATE TABLE IF NOT EXISTS public.fet_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tx_type text NOT NULL,
  direction text NOT NULL,
  amount_fet bigint NOT NULL,
  balance_before_fet bigint NOT NULL DEFAULT 0,
  balance_after_fet bigint NOT NULL DEFAULT 0,
  reference_type text,
  reference_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  title text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fet_wallet_transactions_direction_check
    CHECK (direction IN ('credit', 'debit')),
  CONSTRAINT fet_wallet_transactions_amount_non_negative
    CHECK (amount_fet >= 0)
);

ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS tx_type text;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS direction text;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS amount_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS balance_before_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS balance_after_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS reference_type text;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS reference_id text;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_fet_wallet_transactions_user_created
  ON public.fet_wallet_transactions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fet_wallet_transactions_type_created
  ON public.fet_wallet_transactions (tx_type, created_at DESC);

ALTER TABLE public.fet_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fet_wallet_transactions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'fet_wallets'
      AND policyname = 'Users read own wallet'
  ) THEN
    CREATE POLICY "Users read own wallet"
      ON public.fet_wallets
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'fet_wallet_transactions'
      AND policyname = 'Users read own transactions'
  ) THEN
    CREATE POLICY "Users read own transactions"
      ON public.fet_wallet_transactions
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END;
$$;

GRANT SELECT ON public.fet_wallets TO authenticated;
GRANT SELECT ON public.fet_wallet_transactions TO authenticated;

-- -----------------------------------------------------------------
-- Prediction pools foundation
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.prediction_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id text NOT NULL,
  match_name text NOT NULL DEFAULT '',
  creator_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stake_fet bigint NOT NULL,
  currency_code text NOT NULL DEFAULT 'FET',
  status text NOT NULL DEFAULT 'open',
  lock_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz,
  cancelled_at timestamptz,
  void_reason text,
  total_participants integer NOT NULL DEFAULT 0,
  total_pool_fet bigint NOT NULL DEFAULT 0,
  winner_count integer,
  loser_count integer,
  payout_per_winner_fet bigint,
  official_home_score integer,
  official_away_score integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT prediction_challenges_status_check
    CHECK (status IN ('open', 'locked', 'settled', 'cancelled'))
);

ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS match_name text NOT NULL DEFAULT '';
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS creator_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS stake_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS currency_code text NOT NULL DEFAULT 'FET';
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open';
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS lock_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS settled_at timestamptz;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS void_reason text;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS total_participants integer NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS total_pool_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS winner_count integer;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS loser_count integer;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS payout_per_winner_fet bigint;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS official_home_score integer;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS official_away_score integer;
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_prediction_challenges_match_status
  ON public.prediction_challenges (match_id, status, lock_at);
CREATE INDEX IF NOT EXISTS idx_prediction_challenges_creator
  ON public.prediction_challenges (creator_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.prediction_challenge_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.prediction_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  predicted_home_score integer NOT NULL,
  predicted_away_score integer NOT NULL,
  stake_fet bigint NOT NULL,
  status text NOT NULL DEFAULT 'active',
  payout_fet bigint NOT NULL DEFAULT 0,
  joined_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz,
  CONSTRAINT prediction_challenge_entries_status_check
    CHECK (status IN ('active', 'won', 'lost', 'cancelled', 'refunded')),
  CONSTRAINT prediction_challenge_entries_unique_user
    UNIQUE (challenge_id, user_id)
);

ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS predicted_home_score integer NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS predicted_away_score integer NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS stake_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS payout_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS settled_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_prediction_challenge_entries_user_joined
  ON public.prediction_challenge_entries (user_id, joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_prediction_challenge_entries_challenge
  ON public.prediction_challenge_entries (challenge_id, status);

ALTER TABLE public.prediction_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prediction_challenge_entries ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'prediction_challenges'
      AND policyname = 'Public read challenges'
  ) THEN
    CREATE POLICY "Public read challenges"
      ON public.prediction_challenges
      FOR SELECT
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'prediction_challenge_entries'
      AND policyname = 'Users read own entries'
  ) THEN
    CREATE POLICY "Users read own entries"
      ON public.prediction_challenge_entries
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END;
$$;

GRANT SELECT ON public.prediction_challenges TO anon, authenticated;
GRANT SELECT ON public.prediction_challenge_entries TO authenticated;

-- -----------------------------------------------------------------
-- Favorites / follows
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_followed_teams (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, team_id)
);

CREATE TABLE IF NOT EXISTS public.user_followed_competitions (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  competition_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, competition_id)
);

ALTER TABLE public.user_followed_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_followed_competitions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_followed_teams'
      AND policyname = 'Users manage own team follows'
  ) THEN
    CREATE POLICY "Users manage own team follows"
      ON public.user_followed_teams
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_followed_competitions'
      AND policyname = 'Users manage own competition follows'
  ) THEN
    CREATE POLICY "Users manage own competition follows"
      ON public.user_followed_competitions
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_followed_teams TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_followed_competitions TO authenticated;

-- -----------------------------------------------------------------
-- Standings staging relation
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.competition_standings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id text NOT NULL,
  season text NOT NULL DEFAULT '',
  team_id text,
  team_name text NOT NULL,
  position integer NOT NULL DEFAULT 0,
  played integer NOT NULL DEFAULT 0,
  won integer NOT NULL DEFAULT 0,
  drawn integer NOT NULL DEFAULT 0,
  lost integer NOT NULL DEFAULT 0,
  goals_for integer NOT NULL DEFAULT 0,
  goals_against integer NOT NULL DEFAULT 0,
  goal_difference integer NOT NULL DEFAULT 0,
  points integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competition_standings_lookup
  ON public.competition_standings (competition_id, season, position);

ALTER TABLE public.competition_standings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'competition_standings'
      AND policyname = 'Public read competition standings'
  ) THEN
    CREATE POLICY "Public read competition standings"
      ON public.competition_standings
      FOR SELECT
      USING (true);
  END IF;
END;
$$;

GRANT SELECT ON public.competition_standings TO anon, authenticated;

-- -----------------------------------------------------------------
-- Public leaderboard view
-- -----------------------------------------------------------------

DO $$
DECLARE
  v_relkind "char";
BEGIN
  SELECT c.relkind
  INTO v_relkind
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'public_leaderboard';

  IF v_relkind IS NULL OR v_relkind IN ('v', 'm') THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.public_leaderboard AS
      SELECT
        fw.user_id,
        p.fan_id,
        coalesce(
          nullif(trim(p.display_name), ''),
          nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
          nullif(u.phone, ''),
          'Fan'
        ) AS display_name,
        coalesce(fw.available_balance_fet, 0) + coalesce(fw.locked_balance_fet, 0) AS total_fet
      FROM public.fet_wallets fw
      LEFT JOIN public.profiles p
        ON p.id = fw.user_id OR p.user_id = fw.user_id
      LEFT JOIN auth.users u
        ON u.id = fw.user_id
    $view$;
  END IF;
END;
$$;

GRANT SELECT ON public.public_leaderboard TO anon, authenticated;

COMMIT;
