-- ============================================================
-- 20260420010000_scalability_gap_closure.sql
-- Comprehensive scalability and architecture gap closure.
--
-- Replaces ALL hardcoded Dart constants with database tables.
-- Adds missing indexes, materialized views, feature flags,
-- config tables, and security policy backfills.
-- ============================================================

BEGIN;

-- =================================================================
-- PHASE 1A: COUNTRY → REGION MAPPING (replaces 3 Dart files)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.country_region_map (
  country_code TEXT PRIMARY KEY,
  region TEXT NOT NULL DEFAULT 'global',
  country_name TEXT NOT NULL,
  flag_emoji TEXT NOT NULL DEFAULT '🌍',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT country_region_map_code_format CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT country_region_map_region_check CHECK (region IN ('africa', 'europe', 'north_america', 'global'))
);

ALTER TABLE public.country_region_map ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'country_region_map'
      AND policyname = 'Public read country region map'
  ) THEN
    CREATE POLICY "Public read country region map"
      ON public.country_region_map FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.country_region_map TO anon, authenticated;

-- Seed: Africa
INSERT INTO public.country_region_map (country_code, region, country_name, flag_emoji) VALUES
  ('RW', 'africa', 'Rwanda', '🇷🇼'),
  ('NG', 'africa', 'Nigeria', '🇳🇬'),
  ('KE', 'africa', 'Kenya', '🇰🇪'),
  ('ZA', 'africa', 'South Africa', '🇿🇦'),
  ('EG', 'africa', 'Egypt', '🇪🇬'),
  ('TZ', 'africa', 'Tanzania', '🇹🇿'),
  ('UG', 'africa', 'Uganda', '🇺🇬'),
  ('GH', 'africa', 'Ghana', '🇬🇭'),
  ('TN', 'africa', 'Tunisia', '🇹🇳'),
  ('DZ', 'africa', 'Algeria', '🇩🇿'),
  ('MA', 'africa', 'Morocco', '🇲🇦'),
  ('CD', 'africa', 'DR Congo', '🇨🇩'),
  ('SN', 'africa', 'Senegal', '🇸🇳'),
  ('CI', 'africa', 'Côte d''Ivoire', '🇨🇮'),
  ('ML', 'africa', 'Mali', '🇲🇱'),
  ('BF', 'africa', 'Burkina Faso', '🇧🇫'),
  ('NE', 'africa', 'Niger', '🇳🇪'),
  ('TG', 'africa', 'Togo', '🇹🇬'),
  ('BJ', 'africa', 'Benin', '🇧🇯'),
  ('GW', 'africa', 'Guinea-Bissau', '🇬🇼'),
  ('ET', 'africa', 'Ethiopia', '🇪🇹'),
  ('CM', 'africa', 'Cameroon', '🇨🇲'),
  ('AO', 'africa', 'Angola', '🇦🇴'),
  ('MZ', 'africa', 'Mozambique', '🇲🇿'),
  ('ZW', 'africa', 'Zimbabwe', '🇿🇼'),
  ('ZM', 'africa', 'Zambia', '🇿🇲'),
  ('BW', 'africa', 'Botswana', '🇧🇼'),
  ('NA', 'africa', 'Namibia', '🇳🇦'),
  ('MW', 'africa', 'Malawi', '🇲🇼'),
  ('SD', 'africa', 'Sudan', '🇸🇩'),
  ('LY', 'africa', 'Libya', '🇱🇾'),
  ('SO', 'africa', 'Somalia', '🇸🇴'),
  ('SL', 'africa', 'Sierra Leone', '🇸🇱'),
  ('LR', 'africa', 'Liberia', '🇱🇷'),
  ('MG', 'africa', 'Madagascar', '🇲🇬')
ON CONFLICT (country_code) DO UPDATE
SET region = EXCLUDED.region,
    country_name = EXCLUDED.country_name,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

-- Seed: Europe
INSERT INTO public.country_region_map (country_code, region, country_name, flag_emoji) VALUES
  ('MT', 'europe', 'Malta', '🇲🇹'),
  ('GB', 'europe', 'United Kingdom', '🇬🇧'),
  ('ES', 'europe', 'Spain', '🇪🇸'),
  ('DE', 'europe', 'Germany', '🇩🇪'),
  ('FR', 'europe', 'France', '🇫🇷'),
  ('IT', 'europe', 'Italy', '🇮🇹'),
  ('NL', 'europe', 'Netherlands', '🇳🇱'),
  ('PT', 'europe', 'Portugal', '🇵🇹'),
  ('BE', 'europe', 'Belgium', '🇧🇪'),
  ('AT', 'europe', 'Austria', '🇦🇹'),
  ('CH', 'europe', 'Switzerland', '🇨🇭'),
  ('SE', 'europe', 'Sweden', '🇸🇪'),
  ('NO', 'europe', 'Norway', '🇳🇴'),
  ('DK', 'europe', 'Denmark', '🇩🇰'),
  ('FI', 'europe', 'Finland', '🇫🇮'),
  ('IE', 'europe', 'Ireland', '🇮🇪'),
  ('PL', 'europe', 'Poland', '🇵🇱'),
  ('GR', 'europe', 'Greece', '🇬🇷'),
  ('CZ', 'europe', 'Czech Republic', '🇨🇿'),
  ('HU', 'europe', 'Hungary', '🇭🇺'),
  ('RO', 'europe', 'Romania', '🇷🇴'),
  ('BG', 'europe', 'Bulgaria', '🇧🇬'),
  ('HR', 'europe', 'Croatia', '🇭🇷'),
  ('RS', 'europe', 'Serbia', '🇷🇸'),
  ('SK', 'europe', 'Slovakia', '🇸🇰'),
  ('SI', 'europe', 'Slovenia', '🇸🇮'),
  ('TR', 'europe', 'Turkey', '🇹🇷'),
  ('UA', 'europe', 'Ukraine', '🇺🇦'),
  ('IS', 'europe', 'Iceland', '🇮🇸'),
  ('CY', 'europe', 'Cyprus', '🇨🇾'),
  ('LU', 'europe', 'Luxembourg', '🇱🇺'),
  ('EE', 'europe', 'Estonia', '🇪🇪'),
  ('LV', 'europe', 'Latvia', '🇱🇻'),
  ('LT', 'europe', 'Lithuania', '🇱🇹'),
  ('RU', 'europe', 'Russia', '🇷🇺')
ON CONFLICT (country_code) DO UPDATE
SET region = EXCLUDED.region,
    country_name = EXCLUDED.country_name,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

-- Seed: North America + Americas
INSERT INTO public.country_region_map (country_code, region, country_name, flag_emoji) VALUES
  ('US', 'north_america', 'United States', '🇺🇸'),
  ('CA', 'north_america', 'Canada', '🇨🇦'),
  ('MX', 'north_america', 'Mexico', '🇲🇽'),
  ('BR', 'north_america', 'Brazil', '🇧🇷'),
  ('AR', 'north_america', 'Argentina', '🇦🇷')
ON CONFLICT (country_code) DO UPDATE
SET region = EXCLUDED.region,
    country_name = EXCLUDED.country_name,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

-- Seed: Global / Asia / Oceania
INSERT INTO public.country_region_map (country_code, region, country_name, flag_emoji) VALUES
  ('IN', 'global', 'India', '🇮🇳'),
  ('JP', 'global', 'Japan', '🇯🇵'),
  ('CN', 'global', 'China', '🇨🇳'),
  ('KR', 'global', 'South Korea', '🇰🇷'),
  ('AE', 'global', 'United Arab Emirates', '🇦🇪'),
  ('SA', 'global', 'Saudi Arabia', '🇸🇦'),
  ('AU', 'global', 'Australia', '🇦🇺'),
  ('NZ', 'global', 'New Zealand', '🇳🇿')
ON CONFLICT (country_code) DO UPDATE
SET region = EXCLUDED.region,
    country_name = EXCLUDED.country_name,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

-- =================================================================
-- PHASE 1B: PHONE PRESETS TABLE (replaces phone_presets.dart)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.phone_presets (
  country_code TEXT PRIMARY KEY,
  dial_code TEXT NOT NULL,
  hint TEXT NOT NULL,
  min_digits INTEGER NOT NULL DEFAULT 9,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT phone_presets_code_format CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT phone_presets_dial_format CHECK (dial_code ~ '^\+\d+$'),
  CONSTRAINT phone_presets_min_digits CHECK (min_digits BETWEEN 5 AND 15)
);

ALTER TABLE public.phone_presets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'phone_presets'
      AND policyname = 'Public read phone presets'
  ) THEN
    CREATE POLICY "Public read phone presets"
      ON public.phone_presets FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.phone_presets TO anon, authenticated;

INSERT INTO public.phone_presets (country_code, dial_code, hint, min_digits) VALUES
  ('MT', '+356', '79XX XXXX', 8),
  ('RW', '+250', '7XX XXX XXX', 9),
  ('NG', '+234', '80X XXX XXXX', 10),
  ('KE', '+254', '7XX XXX XXX', 9),
  ('UG', '+256', '7XX XXX XXX', 9),
  ('GB', '+44', '7XXX XXX XXX', 10),
  ('DE', '+49', '15XX XXX XXX', 10),
  ('FR', '+33', '6 XX XX XX XX', 9),
  ('IT', '+39', '3XX XXX XXXX', 10),
  ('ES', '+34', '6XX XXX XXX', 9),
  ('PT', '+351', '9XX XXX XXX', 9),
  ('NL', '+31', '6 XX XX XX XX', 9),
  ('US', '+1', '555 123 4567', 10),
  ('CA', '+1', '555 123 4567', 10),
  ('MX', '+52', '55 1234 5678', 10),
  ('GH', '+233', '2XX XXX XXXX', 10),
  ('ZA', '+27', '7X XXX XXXX', 9),
  ('EG', '+20', '10 XXXX XXXX', 10),
  ('TZ', '+255', '7XX XXX XXX', 9),
  ('TN', '+216', 'XX XXX XXX', 8),
  ('MA', '+212', '6XX-XXXXXX', 9),
  ('SN', '+221', '7X XXX XXXX', 9),
  ('CM', '+237', '6 XX XX XX XX', 9),
  ('ET', '+251', '9XX XXX XXXX', 9),
  ('BR', '+55', '11 9XXXX-XXXX', 11),
  ('AR', '+54', '11 XXXX-XXXX', 10),
  ('IN', '+91', '9XXXXXXXXX', 10),
  ('JP', '+81', '90-XXXX-XXXX', 10),
  ('AE', '+971', '5X XXX XXXX', 9),
  ('AU', '+61', '4XX XXX XXX', 9),
  ('TR', '+90', '5XX XXX XXXX', 10),
  ('PL', '+48', 'XXX XXX XXX', 9),
  ('CH', '+41', '7X XXX XX XX', 9),
  ('SE', '+46', '7X XXX XX XX', 9),
  ('NO', '+47', 'XXX XX XXX', 8),
  ('DK', '+45', 'XX XX XX XX', 8),
  ('BE', '+32', '4XX XX XX XX', 9),
  ('AT', '+43', '6XX XXXXXXX', 10),
  ('IE', '+353', '8X XXX XXXX', 9),
  ('GR', '+30', '69X XXX XXXX', 10)
ON CONFLICT (country_code) DO UPDATE
SET dial_code = EXCLUDED.dial_code,
    hint = EXCLUDED.hint,
    min_digits = EXCLUDED.min_digits,
    updated_at = now();

-- =================================================================
-- PHASE 1C: CURRENCY DISPLAY METADATA (replaces currencyMetadata)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.currency_display_metadata (
  currency_code TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  decimals INTEGER NOT NULL DEFAULT 2,
  space_separated BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT currency_display_code_format CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT currency_display_decimals CHECK (decimals BETWEEN 0 AND 4)
);

ALTER TABLE public.currency_display_metadata ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'currency_display_metadata'
      AND policyname = 'Public read currency display'
  ) THEN
    CREATE POLICY "Public read currency display"
      ON public.currency_display_metadata FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.currency_display_metadata TO anon, authenticated;

INSERT INTO public.currency_display_metadata (currency_code, symbol, decimals, space_separated) VALUES
  ('EUR', '€', 2, false),
  ('GBP', '£', 2, false),
  ('USD', '$', 2, false),
  ('CAD', 'C$', 2, false),
  ('CHF', 'CHF', 2, true),
  ('SEK', 'kr', 2, true),
  ('NOK', 'kr', 2, true),
  ('DKK', 'kr', 2, true),
  ('PLN', 'zł', 2, true),
  ('TRY', '₺', 2, false),
  ('BRL', 'R$', 2, false),
  ('MXN', 'MX$', 0, true),
  ('ARS', 'ARS', 0, true),
  ('RWF', 'FRW', 0, true),
  ('NGN', '₦', 0, false),
  ('KES', 'KSh', 0, true),
  ('ZAR', 'R', 2, false),
  ('EGP', 'E£', 0, false),
  ('TZS', 'TSh', 0, true),
  ('UGX', 'USh', 0, true),
  ('GHS', 'GH₵', 2, false),
  ('XOF', 'CFA', 0, true),
  ('TND', 'DT', 2, true),
  ('DZD', 'DA', 0, true),
  ('MAD', 'MAD', 2, true),
  ('CDF', 'FC', 0, true),
  ('ETB', 'Br', 0, true),
  ('INR', '₹', 0, false),
  ('JPY', '¥', 0, false),
  ('CNY', '¥', 2, false),
  ('AED', 'AED', 2, true),
  ('SAR', 'SAR', 2, true),
  ('AUD', 'A$', 2, false),
  ('NZD', 'NZ$', 2, false)
ON CONFLICT (currency_code) DO UPDATE
SET symbol = EXCLUDED.symbol,
    decimals = EXCLUDED.decimals,
    space_separated = EXCLUDED.space_separated,
    updated_at = now();

-- =================================================================
-- PHASE 1D: FEATURE FLAGS (replaces --dart-define flags)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
  key TEXT NOT NULL,
  market TEXT NOT NULL DEFAULT 'global',
  platform TEXT NOT NULL DEFAULT 'all',
  enabled BOOLEAN NOT NULL DEFAULT false,
  rollout_pct INTEGER NOT NULL DEFAULT 100,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (key, market, platform),
  CONSTRAINT feature_flags_market_check CHECK (market ~ '^[a-z_]+$'),
  CONSTRAINT feature_flags_platform_check CHECK (platform IN ('all', 'android', 'ios', 'web')),
  CONSTRAINT feature_flags_rollout_check CHECK (rollout_pct BETWEEN 0 AND 100)
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'feature_flags'
      AND policyname = 'Public read feature flags'
  ) THEN
    CREATE POLICY "Public read feature flags"
      ON public.feature_flags FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.feature_flags TO anon, authenticated;

-- Seed the existing compile-time flags as DB rows
INSERT INTO public.feature_flags (key, market, platform, enabled, description) VALUES
  ('predictions', 'global', 'all', true, 'Enable prediction pool system'),
  ('wallet', 'global', 'all', true, 'Enable FET wallet and transactions'),
  ('leaderboard', 'global', 'all', true, 'Enable global leaderboard'),
  ('rewards', 'global', 'all', true, 'Enable marketplace rewards'),
  ('membership', 'global', 'all', false, 'Enable membership hub'),
  ('notifications', 'global', 'all', false, 'Enable push notifications'),
  ('team_communities', 'global', 'all', true, 'Enable team community features'),
  ('social_feed', 'global', 'all', false, 'Enable social feed'),
  ('fan_identity', 'global', 'all', true, 'Enable fan identity / XP / badges'),
  ('marketplace', 'global', 'all', true, 'Enable reward marketplace'),
  ('ai_analysis', 'global', 'all', false, 'Enable AI match analysis'),
  ('advanced_stats', 'global', 'all', false, 'Enable advanced match statistics'),
  ('community_contests', 'global', 'all', false, 'Enable community fan clash contests'),
  ('seasonal_leaderboards', 'global', 'all', false, 'Enable seasonal leaderboard periods'),
  ('deep_linking', 'global', 'all', true, 'Enable deep linking support'),
  ('featured_events', 'global', 'all', true, 'Enable featured event banners'),
  ('global_challenges', 'global', 'all', false, 'Enable global multi-match challenges'),
  ('region_discovery', 'global', 'all', true, 'Enable region-based content discovery')
ON CONFLICT (key, market, platform) DO UPDATE
SET enabled = EXCLUDED.enabled,
    description = EXCLUDED.description,
    updated_at = now();

-- =================================================================
-- PHASE 1E: APP CONFIG / REMOTE CONFIG
-- =================================================================

CREATE TABLE IF NOT EXISTS public.app_config_remote (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config_remote ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'app_config_remote'
      AND policyname = 'Public read app config'
  ) THEN
    CREATE POLICY "Public read app config"
      ON public.app_config_remote FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.app_config_remote TO anon, authenticated;

INSERT INTO public.app_config_remote (key, value, description) VALUES
  ('min_app_version', '"1.0.0"'::jsonb, 'Minimum required app version'),
  ('maintenance_mode', 'false'::jsonb, 'Global maintenance mode toggle'),
  ('maintenance_message', '"FANZONE is undergoing scheduled maintenance. We''ll be back soon!"'::jsonb, 'Message shown during maintenance'),
  ('min_stake_fet', '10'::jsonb, 'Minimum FET stake for prediction pools'),
  ('max_daily_transfers', '10'::jsonb, 'Maximum FET transfers per day per user'),
  ('fan_id_digits', '6'::jsonb, 'Number of digits in Fan ID'),
  ('otp_expiry_seconds', '600'::jsonb, 'OTP validity in seconds'),
  ('default_region', '"global"'::jsonb, 'Default region for new users')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

-- =================================================================
-- PHASE 1F: LAUNCH MOMENTS TABLE (replaces launchMomentOptions)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.launch_moments (
  tag TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  kicker TEXT NOT NULL,
  region_key TEXT NOT NULL DEFAULT 'global',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT launch_moments_region_check CHECK (region_key IN ('africa', 'europe', 'north_america', 'global'))
);

ALTER TABLE public.launch_moments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'launch_moments'
      AND policyname = 'Public read launch moments'
  ) THEN
    CREATE POLICY "Public read launch moments"
      ON public.launch_moments FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.launch_moments TO anon, authenticated;

INSERT INTO public.launch_moments (tag, title, subtitle, kicker, region_key, sort_order) VALUES
  ('road-to-world-cup-2026', 'Road to World Cup 2026',
   'Track the build-up across host markets, qualification stories, and global supporter momentum.',
   'World Cup lead-up', 'global', 1),
  ('worldcup2026', 'World Cup 2026',
   'Follow the tournament itself with prediction windows, global challenges, and host-market relevance.',
   'Tournament proper', 'global', 2),
  ('ucl-final-2026', 'UEFA Champions League Final',
   'Keep Europe''s biggest club night central during the run-in and final-week conversion window.',
   'European club peak', 'europe', 3),
  ('africa-fan-momentum-2026', 'Africa Fan Momentum',
   'Grow supporter communities, club discovery, and challenge participation around African football audiences.',
   'Africa growth', 'africa', 4),
  ('north-america-host-cities-2026', 'North America Host Cities',
   'Surface USA, Canada, and Mexico interest as host-city football attention accelerates.',
   'Host-market growth', 'north_america', 5)
ON CONFLICT (tag) DO UPDATE
SET title = EXCLUDED.title,
    subtitle = EXCLUDED.subtitle,
    kicker = EXCLUDED.kicker,
    region_key = EXCLUDED.region_key,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();

-- =================================================================
-- PHASE 1G: COMPETITION SEASONS (replaces free-text season columns)
-- =================================================================

CREATE TABLE IF NOT EXISTS public.competition_seasons (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  competition_id TEXT NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
  season_name TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  is_current BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (competition_id, season_name)
);

ALTER TABLE public.competition_seasons ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'competition_seasons'
      AND policyname = 'Public read competition seasons'
  ) THEN
    CREATE POLICY "Public read competition seasons"
      ON public.competition_seasons FOR SELECT USING (true);
  END IF;
END $$;

GRANT SELECT ON public.competition_seasons TO anon, authenticated;

-- =================================================================
-- PHASE 1H: BOOTSTRAP CONFIG RPC
-- =================================================================

CREATE OR REPLACE FUNCTION public.get_app_bootstrap_config(
  p_market TEXT DEFAULT 'global',
  p_platform TEXT DEFAULT 'all'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'regions', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'country_code', crm.country_code,
        'region', crm.region,
        'country_name', crm.country_name,
        'flag_emoji', crm.flag_emoji
      ) ORDER BY crm.country_name), '[]'::jsonb)
      FROM public.country_region_map crm
    ),
    'phone_presets', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'country_code', pp.country_code,
        'dial_code', pp.dial_code,
        'hint', pp.hint,
        'min_digits', pp.min_digits
      ) ORDER BY pp.country_code), '[]'::jsonb)
      FROM public.phone_presets pp
    ),
    'currency_display', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'currency_code', cdm.currency_code,
        'symbol', cdm.symbol,
        'decimals', cdm.decimals,
        'space_separated', cdm.space_separated
      ) ORDER BY cdm.currency_code), '[]'::jsonb)
      FROM public.currency_display_metadata cdm
    ),
    'feature_flags', (
      SELECT COALESCE(jsonb_object_agg(
        ff.key,
        ff.enabled
      ), '{}'::jsonb)
      FROM public.feature_flags ff
      WHERE (ff.market = p_market OR ff.market = 'global')
        AND (ff.platform = p_platform OR ff.platform = 'all')
    ),
    'app_config', (
      SELECT COALESCE(jsonb_object_agg(
        acr.key,
        acr.value
      ), '{}'::jsonb)
      FROM public.app_config_remote acr
    ),
    'launch_moments', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'tag', lm.tag,
        'title', lm.title,
        'subtitle', lm.subtitle,
        'kicker', lm.kicker,
        'region_key', lm.region_key
      ) ORDER BY lm.sort_order), '[]'::jsonb)
      FROM public.launch_moments lm
      WHERE lm.is_active = true
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_app_bootstrap_config(TEXT, TEXT) TO anon, authenticated;

-- =================================================================
-- PHASE 1I: DB-DRIVEN REGION RESOLUTION RPC
-- =================================================================

CREATE OR REPLACE FUNCTION public.get_country_region(p_country_code TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT COALESCE(
    (SELECT region FROM public.country_region_map WHERE country_code = UPPER(p_country_code) LIMIT 1),
    'global'
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_country_region(TEXT) TO anon, authenticated;

-- =================================================================
-- PHASE 2A: MISSING INDEXES
-- =================================================================

-- Matches: date + status (home screen listing)
CREATE INDEX IF NOT EXISTS idx_matches_date_status
  ON public.matches (date, status);

-- Matches: competition + date (competition detail)
CREATE INDEX IF NOT EXISTS idx_matches_competition_date
  ON public.matches (competition_id, date DESC);

-- Matches: team FK indexes (team detail)
CREATE INDEX IF NOT EXISTS idx_matches_home_team
  ON public.matches (home_team_id)
  WHERE home_team_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_matches_away_team
  ON public.matches (away_team_id)
  WHERE away_team_id IS NOT NULL;

-- Teams: country + popularity (onboarding)
CREATE INDEX IF NOT EXISTS idx_teams_country
  ON public.teams (country);

CREATE INDEX IF NOT EXISTS idx_teams_popular_pick
  ON public.teams (is_popular_pick, popular_pick_rank)
  WHERE is_popular_pick = true;

-- Competitions: country + tier (discovery screen)
CREATE INDEX IF NOT EXISTS idx_competitions_country_tier
  ON public.competitions (country, tier);

-- Notifications: user + read status (badge count)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notifications'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_notifications_user_read
      ON public.notifications (user_id, is_read, created_at DESC)';
  END IF;
END $$;

-- Social feed posts: team + date (team feed)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'social_feed_posts'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_social_feed_posts_team_date
      ON public.social_feed_posts (team_id, created_at DESC)';
  END IF;
END $$;

-- =================================================================
-- PHASE 2B: CRON JOB LOG TABLE
-- =================================================================

CREATE TABLE IF NOT EXISTS public.cron_job_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'running',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  duration_ms INTEGER,
  result JSONB DEFAULT '{}'::jsonb,
  error_message TEXT,
  CONSTRAINT cron_job_log_status_check CHECK (status IN ('running', 'completed', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_cron_job_log_name_started
  ON public.cron_job_log (job_name, started_at DESC);

ALTER TABLE public.cron_job_log ENABLE ROW LEVEL SECURITY;
-- Admin-only access; no public policies

-- =================================================================
-- PHASE 3: SECURITY POLICY BACKFILLS
-- =================================================================

-- Admin write policies for sports data tables (explicit, not relying on service_role bypass)
-- These enable future admin RPCs to write sports data.

-- Ensure is_admin column exists BEFORE creating policies that reference it
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

DO $$ BEGIN
  -- competitions: admin write
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'competitions'
      AND policyname = 'Admin write competitions'
  ) THEN
    CREATE POLICY "Admin write competitions"
      ON public.competitions
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- is_admin column already added above before policies

-- Consistent anon read access for public tables
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'competitions'
      AND policyname = 'Anon read competitions'
  ) THEN
    -- The existing policy "Public read access for competitions" already covers anon via USING(true)
    -- Just ensure GRANT is explicit
    NULL;
  END IF;
END $$;

GRANT SELECT ON public.competitions TO anon;
GRANT SELECT ON public.teams TO anon;
GRANT SELECT ON public.matches TO anon;
GRANT SELECT ON public.live_match_events TO anon;
GRANT SELECT ON public.news TO anon;

COMMIT;
