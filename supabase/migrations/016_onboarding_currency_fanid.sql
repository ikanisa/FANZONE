-- ============================================================
-- 016_onboarding_currency_fanid.sql
-- Guest-first onboarding persistence, backend currency inference,
-- and Fan ID-first wallet transfers.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1) Extend teams for richer onboarding metadata
-- -----------------------------------------------------------------

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS country_code TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS league_name TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS crest_url TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS search_terms TEXT[] DEFAULT '{}'::text[];
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS is_popular_pick BOOLEAN DEFAULT false;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS popular_pick_rank INTEGER;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

UPDATE public.teams
SET updated_at = COALESCE(updated_at, now())
WHERE updated_at IS NULL;

-- -----------------------------------------------------------------
-- 2) Country -> currency mapping (rates remain live, not hardcoded)
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.country_currency_map (
  country_code TEXT PRIMARY KEY,
  currency_code TEXT NOT NULL,
  country_name TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT country_currency_map_country_code_format
    CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT country_currency_map_currency_code_format
    CHECK (currency_code ~ '^[A-Z]{3}$')
);

ALTER TABLE public.country_currency_map ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'country_currency_map'
      AND policyname = 'Public read country currency map'
  ) THEN
    CREATE POLICY "Public read country currency map"
      ON public.country_currency_map
      FOR SELECT
      USING (true);
  END IF;
END $$;

INSERT INTO public.country_currency_map (country_code, currency_code, country_name)
VALUES
  ('MT', 'EUR', 'Malta'),
  ('ES', 'EUR', 'Spain'),
  ('DE', 'EUR', 'Germany'),
  ('FR', 'EUR', 'France'),
  ('IT', 'EUR', 'Italy'),
  ('NL', 'EUR', 'Netherlands'),
  ('PT', 'EUR', 'Portugal'),
  ('BE', 'EUR', 'Belgium'),
  ('AT', 'EUR', 'Austria'),
  ('FI', 'EUR', 'Finland'),
  ('IE', 'EUR', 'Ireland'),
  ('GR', 'EUR', 'Greece'),
  ('GB', 'GBP', 'United Kingdom'),
  ('CH', 'CHF', 'Switzerland'),
  ('SE', 'SEK', 'Sweden'),
  ('NO', 'NOK', 'Norway'),
  ('DK', 'DKK', 'Denmark'),
  ('PL', 'PLN', 'Poland'),
  ('TR', 'TRY', 'Turkey'),
  ('US', 'USD', 'United States'),
  ('CA', 'CAD', 'Canada'),
  ('BR', 'BRL', 'Brazil'),
  ('MX', 'MXN', 'Mexico'),
  ('AR', 'ARS', 'Argentina'),
  ('RW', 'RWF', 'Rwanda'),
  ('NG', 'NGN', 'Nigeria'),
  ('KE', 'KES', 'Kenya'),
  ('ZA', 'ZAR', 'South Africa'),
  ('EG', 'EGP', 'Egypt'),
  ('TZ', 'TZS', 'Tanzania'),
  ('UG', 'UGX', 'Uganda'),
  ('GH', 'GHS', 'Ghana'),
  ('TN', 'TND', 'Tunisia'),
  ('DZ', 'DZD', 'Algeria'),
  ('MA', 'MAD', 'Morocco'),
  ('CD', 'CDF', 'Democratic Republic of the Congo'),
  ('ET', 'ETB', 'Ethiopia'),
  ('SN', 'XOF', 'Senegal'),
  ('CI', 'XOF', 'Côte d''Ivoire'),
  ('ML', 'XOF', 'Mali'),
  ('BF', 'XOF', 'Burkina Faso'),
  ('NE', 'XOF', 'Niger'),
  ('TG', 'XOF', 'Togo'),
  ('BJ', 'XOF', 'Benin'),
  ('GW', 'XOF', 'Guinea-Bissau'),
  ('IN', 'INR', 'India'),
  ('JP', 'JPY', 'Japan'),
  ('CN', 'CNY', 'China'),
  ('AE', 'AED', 'United Arab Emirates'),
  ('SA', 'SAR', 'Saudi Arabia'),
  ('AU', 'AUD', 'Australia'),
  ('NZ', 'NZD', 'New Zealand')
ON CONFLICT (country_code) DO UPDATE
SET currency_code = EXCLUDED.currency_code,
    country_name = EXCLUDED.country_name,
    updated_at = now();

-- -----------------------------------------------------------------
-- 3) Live Gemini-backed EUR exchange rates cache
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.currency_rates (
  base_currency TEXT NOT NULL DEFAULT 'EUR',
  target_currency TEXT NOT NULL,
  rate NUMERIC NOT NULL CHECK (rate > 0),
  source TEXT NOT NULL DEFAULT 'gemini',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (base_currency, target_currency),
  CONSTRAINT currency_rates_base_format CHECK (base_currency ~ '^[A-Z]{3}$'),
  CONSTRAINT currency_rates_target_format CHECK (target_currency ~ '^[A-Z]{3}$')
);

ALTER TABLE public.currency_rates ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'currency_rates'
      AND policyname = 'Public read currency rates'
  ) THEN
    CREATE POLICY "Public read currency rates"
      ON public.currency_rates
      FOR SELECT
      USING (true);
  END IF;
END $$;

INSERT INTO public.currency_rates (
  base_currency,
  target_currency,
  rate,
  source,
  updated_at
) VALUES (
  'EUR',
  'EUR',
  1,
  'reference',
  now()
)
ON CONFLICT (base_currency, target_currency) DO UPDATE
SET rate = EXCLUDED.rate,
    source = EXCLUDED.source,
    updated_at = EXCLUDED.updated_at;

-- -----------------------------------------------------------------
-- 4) Favorite team selections (local + popular + settings)
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_favorite_teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id TEXT NOT NULL,
  team_name TEXT NOT NULL,
  team_short_name TEXT,
  team_country TEXT,
  team_country_code TEXT,
  team_league TEXT,
  team_crest_url TEXT,
  source TEXT NOT NULL DEFAULT 'popular',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_favorite_teams_source_check
    CHECK (source IN ('local', 'popular', 'settings', 'synced')),
  CONSTRAINT user_favorite_teams_country_code_format
    CHECK (
      team_country_code IS NULL
      OR team_country_code = ''
      OR team_country_code ~ '^[A-Z]{2}$'
    ),
  UNIQUE (user_id, team_id)
);

ALTER TABLE public.user_favorite_teams ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_favorite_teams'
      AND policyname = 'Users can read own favorite teams'
  ) THEN
    CREATE POLICY "Users can read own favorite teams"
      ON public.user_favorite_teams
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_favorite_teams'
      AND policyname = 'Users can insert own favorite teams'
  ) THEN
    CREATE POLICY "Users can insert own favorite teams"
      ON public.user_favorite_teams
      FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_favorite_teams'
      AND policyname = 'Users can update own favorite teams'
  ) THEN
    CREATE POLICY "Users can update own favorite teams"
      ON public.user_favorite_teams
      FOR UPDATE
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_favorite_teams'
      AND policyname = 'Users can delete own favorite teams'
  ) THEN
    CREATE POLICY "Users can delete own favorite teams"
      ON public.user_favorite_teams
      FOR DELETE
      USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_favorite_teams_user
  ON public.user_favorite_teams (user_id, source, sort_order, created_at);

CREATE INDEX IF NOT EXISTS idx_user_favorite_teams_country
  ON public.user_favorite_teams (team_country_code);

-- -----------------------------------------------------------------
-- 5) Profiles: 6-digit Fan IDs and inferred currency ownership
-- -----------------------------------------------------------------

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS currency_code TEXT;

CREATE OR REPLACE FUNCTION public.generate_profile_fan_id(
  p_seed TEXT,
  p_attempt INTEGER DEFAULT 0,
  p_profile_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seed TEXT := COALESCE(NULLIF(trim(p_seed), ''), gen_random_uuid()::text);
  v_attempt INTEGER := GREATEST(COALESCE(p_attempt, 0), 0);
  v_candidate TEXT;
BEGIN
  LOOP
    v_candidate := LPAD(
      (
        ABS(
          ('x' || substr(md5(v_seed || ':' || v_attempt::text), 1, 8))::bit(32)::int
        ) % 1000000
      )::text,
      6,
      '0'
    );

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE fan_id = v_candidate
        AND (p_profile_id IS NULL OR id <> p_profile_id)
    );

    v_attempt := v_attempt + 1;
  END LOOP;

  RETURN v_candidate;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_fan_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.generate_profile_fan_id(gen_random_uuid()::text);
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_profile_fan_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seed TEXT;
BEGIN
  v_seed := COALESCE(NEW.user_id::text, NEW.id::text, gen_random_uuid()::text);

  IF NEW.fan_id IS NULL OR NEW.fan_id !~ '^\d{6}$' THEN
    NEW.fan_id := public.generate_profile_fan_id(
      v_seed,
      0,
      COALESCE(NEW.id, NEW.user_id)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_assign_fan_id ON public.profiles;
CREATE TRIGGER trg_profiles_assign_fan_id
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_profile_fan_id();

DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT id, COALESCE(user_id::text, id::text) AS seed
    FROM public.profiles
    ORDER BY created_at NULLS FIRST, id
  LOOP
    UPDATE public.profiles
    SET fan_id = public.generate_profile_fan_id(rec.seed, 0, rec.id)
    WHERE id = rec.id;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_fan_id_six_digits'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_fan_id_six_digits
      CHECK (fan_id ~ '^\d{6}$');
  END IF;
END $$;

-- -----------------------------------------------------------------
-- 6) Backend currency inference from team selections
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guess_user_currency(
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := COALESCE(p_user_id, auth.uid());
  v_country_code TEXT;
  v_currency_code TEXT := 'EUR';
  v_source TEXT := 'fallback';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT upper(team_country_code), source
  INTO v_country_code, v_source
  FROM public.user_favorite_teams
  WHERE user_id = v_user_id
    AND source = 'local'
    AND NULLIF(team_country_code, '') IS NOT NULL
  ORDER BY sort_order ASC, created_at ASC
  LIMIT 1;

  IF v_country_code IS NULL THEN
    SELECT upper(team_country_code), source
    INTO v_country_code, v_source
    FROM public.user_favorite_teams
    WHERE user_id = v_user_id
      AND NULLIF(team_country_code, '') IS NOT NULL
      AND upper(team_country_code) <> ALL (ARRAY['GB', 'ES', 'DE', 'FR', 'IT', 'NL', 'PT'])
    ORDER BY
      CASE source
        WHEN 'settings' THEN 0
        WHEN 'popular' THEN 1
        ELSE 2
      END,
      sort_order ASC,
      created_at ASC
    LIMIT 1;
  END IF;

  IF v_country_code IS NULL THEN
    SELECT upper(team_country_code), source
    INTO v_country_code, v_source
    FROM public.user_favorite_teams
    WHERE user_id = v_user_id
      AND NULLIF(team_country_code, '') IS NOT NULL
    ORDER BY
      CASE source
        WHEN 'local' THEN 0
        WHEN 'settings' THEN 1
        WHEN 'popular' THEN 2
        ELSE 3
      END,
      sort_order ASC,
      created_at ASC
    LIMIT 1;
  END IF;

  IF v_country_code IS NULL THEN
    SELECT
      upper(
        CASE
          WHEN COALESCE(active_country, '') ~ '^[A-Za-z]{2}$' THEN active_country
          WHEN COALESCE(country_code, '') ~ '^[A-Za-z]{2}$' THEN country_code
          ELSE NULL
        END
      ),
      'profile'
    INTO v_country_code, v_source
    FROM public.profiles
    WHERE id = v_user_id OR user_id = v_user_id
    LIMIT 1;
  END IF;

  IF v_country_code IS NOT NULL THEN
    SELECT c.currency_code
    INTO v_currency_code
    FROM public.country_currency_map AS c
    WHERE c.country_code = upper(v_country_code)
    LIMIT 1;
  END IF;

  v_currency_code := COALESCE(v_currency_code, 'EUR');

  UPDATE public.profiles
  SET currency_code = v_currency_code,
      active_country = COALESCE(v_country_code, active_country),
      updated_at = now()
  WHERE id = v_user_id OR user_id = v_user_id;

  RETURN jsonb_build_object(
    'currency_code', v_currency_code,
    'country_code', COALESCE(v_country_code, 'MT'),
    'source', v_source
  );
END;
$$;

UPDATE public.profiles AS p
SET currency_code = c.currency_code,
    updated_at = now()
FROM public.country_currency_map AS c
WHERE p.currency_code IS NULL
  AND COALESCE(NULLIF(upper(p.active_country), ''), NULLIF(upper(p.country_code), '')) = c.country_code;

-- -----------------------------------------------------------------
-- 7) Fan ID-first transfers
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.transfer_fet_by_fan_id(
  p_recipient_fan_id TEXT,
  p_amount_fet BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_sender_fan_id TEXT;
  v_recipient_id UUID;
  v_sender_balance BIGINT;
  v_recipient_balance_before BIGINT := 0;
  v_clean_fan_id TEXT := regexp_replace(COALESCE(p_recipient_fan_id, ''), '[^0-9]', '', 'g');
BEGIN
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_sender_id);

  IF NOT public.check_rate_limit(v_sender_id, 'transfer_fet', 10, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 10 transfers per day';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  IF v_clean_fan_id !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'Recipient Fan ID must be exactly 6 digits';
  END IF;

  SELECT fan_id
  INTO v_sender_fan_id
  FROM public.profiles
  WHERE id = v_sender_id OR user_id = v_sender_id
  LIMIT 1;

  IF v_sender_fan_id IS NULL THEN
    UPDATE public.profiles
    SET fan_id = public.generate_profile_fan_id(v_sender_id::text, 0, id)
    WHERE id = v_sender_id OR user_id = v_sender_id;

    SELECT fan_id
    INTO v_sender_fan_id
    FROM public.profiles
    WHERE id = v_sender_id OR user_id = v_sender_id
    LIMIT 1;
  END IF;

  IF v_sender_fan_id = v_clean_fan_id THEN
    RAISE EXCEPTION 'You cannot transfer tokens to yourself.';
  END IF;

  SELECT COALESCE(user_id, id)
  INTO v_recipient_id
  FROM public.profiles
  WHERE fan_id = v_clean_fan_id
  LIMIT 1;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Fan ID not found. Please check the number and try again.';
  END IF;

  SELECT available_balance_fet
  INTO v_sender_balance
  FROM public.fet_wallets
  WHERE user_id = v_sender_id
  FOR UPDATE;

  IF v_sender_balance IS NULL OR v_sender_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_recipient_id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT available_balance_fet
  INTO v_recipient_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_recipient_id
  FOR UPDATE;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_sender_id;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet + p_amount_fet,
      updated_at = now()
  WHERE user_id = v_recipient_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  ) VALUES
    (
      v_sender_id,
      'transfer',
      'debit',
      p_amount_fet,
      v_sender_balance,
      v_sender_balance - p_amount_fet,
      'transfer',
      v_clean_fan_id,
      'Transfer to Fan #' || v_clean_fan_id
    ),
    (
      v_recipient_id,
      'transfer',
      'credit',
      p_amount_fet,
      COALESCE(v_recipient_balance_before, 0),
      COALESCE(v_recipient_balance_before, 0) + p_amount_fet,
      'transfer',
      v_sender_fan_id,
      'Transfer from Fan #' || COALESCE(v_sender_fan_id, '000000')
    );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_fan_id', v_clean_fan_id,
    'amount_fet', p_amount_fet
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.transfer_fet(
  p_recipient_identifier TEXT,
  p_amount_fet BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_clean_fan_id TEXT := regexp_replace(COALESCE(p_recipient_identifier, ''), '[^0-9]', '', 'g');
BEGIN
  IF v_clean_fan_id !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'Recipient Fan ID must be exactly 6 digits';
  END IF;

  RETURN public.transfer_fet_by_fan_id(v_clean_fan_id, p_amount_fet);
END;
$$;

GRANT EXECUTE ON FUNCTION public.guess_user_currency(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_fet_by_fan_id(TEXT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_fet(TEXT, BIGINT) TO authenticated;

COMMIT;
