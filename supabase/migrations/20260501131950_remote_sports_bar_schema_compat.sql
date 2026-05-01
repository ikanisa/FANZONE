-- Remote compatibility shim for projects that applied the pre-squash DineIn /
-- FANZONE migrations before the sports-bar baseline was consolidated locally.
-- This migration is intentionally additive: it adds the schema and helper
-- surfaces required by the active sports-bar migrations without dropping or
-- rewriting existing production data.

CREATE OR REPLACE FUNCTION public.app_config_numeric(
  p_key text,
  p_default numeric DEFAULT NULL::numeric
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_value jsonb;
  v_text text;
BEGIN
  SELECT value
  INTO v_value
  FROM public.app_config_remote
  WHERE key = p_key
  LIMIT 1;

  IF v_value IS NULL OR v_value = 'null'::jsonb THEN
    RETURN p_default;
  END IF;

  v_text := trim(both '"' from v_value::text);
  IF v_text = '' THEN
    RETURN p_default;
  END IF;

  RETURN v_text::numeric;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN p_default;
END;
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
  SELECT
    coalesce(auth.role(), '') = 'service_role'
    OR public.is_admin_manager(auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_result_code(
  p_home_score integer,
  p_away_score integer
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_home_score IS NULL OR p_away_score IS NULL THEN NULL
    WHEN p_home_score > p_away_score THEN 'H'
    WHEN p_home_score < p_away_score THEN 'A'
    ELSE 'D'
  END;
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_winner_camp(p_result_code text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_result_code
    WHEN 'H' THEN 'home'
    WHEN 'D' THEN 'draw'
    WHEN 'A' THEN 'away'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_write_audit(
  p_action text,
  p_entity_type text,
  p_entity_id text DEFAULT NULL::text,
  p_before_json jsonb DEFAULT NULL::jsonb,
  p_after_json jsonb DEFAULT NULL::jsonb,
  p_actor_user_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_id uuid;
  v_actor uuid := coalesce(p_actor_user_id, auth.uid());
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = 'actor_user_id'
  ) THEN
    INSERT INTO public.audit_logs (
      actor_user_id,
      actor_role,
      action,
      entity_type,
      entity_id,
      before_json,
      after_json
    )
    VALUES (
      v_actor,
      coalesce(auth.role(), current_user),
      p_action,
      p_entity_type,
      p_entity_id,
      p_before_json,
      p_after_json
    )
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO public.audit_logs (
      actor_type,
      actor_id,
      action,
      details_json
    )
    VALUES (
      CASE WHEN v_actor IS NULL THEN 'system' ELSE 'user' END,
      coalesce(v_actor::text, current_user),
      p_action,
      jsonb_build_object(
        'entity_type', p_entity_type,
        'entity_id', p_entity_id,
        'before_json', coalesce(p_before_json, '{}'::jsonb),
        'after_json', coalesce(p_after_json, '{}'::jsonb),
        'source', 'sports_bar_write_audit'
      )
    )
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

CREATE TABLE IF NOT EXISTS public.countries (
  id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL,
  iso_code text NOT NULL UNIQUE,
  region text DEFAULT 'global'::text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  rollout_priority integer DEFAULT 100 NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  CONSTRAINT countries_iso_code_check CHECK (iso_code ~ '^[A-Z]{2}$'::text),
  CONSTRAINT countries_name_check CHECK (char_length(trim(name)) BETWEEN 2 AND 120),
  CONSTRAINT countries_rollout_priority_check CHECK (rollout_priority >= 0)
);

COMMENT ON TABLE public.countries
IS 'Canonical country rollout catalog for venues, country pools, teams, and curated match visibility.';

CREATE TABLE IF NOT EXISTS public.reward_rules (
  id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
  scope text NOT NULL,
  country_id uuid,
  venue_id uuid,
  welcome_fet_amount bigint DEFAULT 0 NOT NULL,
  order_fet_default_percent numeric(5,2) DEFAULT 0 NOT NULL,
  pool_creator_reward_per_member bigint DEFAULT 0 NOT NULL,
  min_qualified_stake bigint DEFAULT 0 NOT NULL,
  min_qualified_members integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  CONSTRAINT reward_rules_min_qualified_members_check CHECK (min_qualified_members >= 0),
  CONSTRAINT reward_rules_min_qualified_stake_check CHECK (min_qualified_stake >= 0),
  CONSTRAINT reward_rules_order_fet_default_percent_check CHECK (order_fet_default_percent >= 0 AND order_fet_default_percent <= 100),
  CONSTRAINT reward_rules_pool_creator_reward_per_member_check CHECK (pool_creator_reward_per_member >= 0),
  CONSTRAINT reward_rules_scope_check CHECK (scope = ANY (ARRAY['platform'::text, 'country'::text, 'venue'::text])),
  CONSTRAINT reward_rules_scope_target_check CHECK (
    (scope = 'platform'::text AND country_id IS NULL AND venue_id IS NULL)
    OR (scope = 'country'::text AND country_id IS NOT NULL AND venue_id IS NULL)
    OR (scope = 'venue'::text AND venue_id IS NOT NULL)
  ),
  CONSTRAINT reward_rules_welcome_fet_amount_check CHECK (welcome_fet_amount >= 0),
  CONSTRAINT reward_rules_window_check CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS country_id uuid,
  ADD COLUMN IF NOT EXISTS type text,
  ADD COLUMN IF NOT EXISTS priority integer DEFAULT 100;

UPDATE public.competitions
SET type = CASE
      WHEN lower(coalesce(competition_type, '')) IN ('league', 'cup', 'world_cup', 'local_curated')
        THEN lower(competition_type)
      ELSE type
    END,
    priority = coalesce(priority, 100)
WHERE type IS NULL OR priority IS NULL;

ALTER TABLE public.competitions
  ALTER COLUMN priority SET DEFAULT 100,
  ALTER COLUMN priority SET NOT NULL;

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS country_id uuid,
  ADD COLUMN IF NOT EXISTS popularity_score integer DEFAULT 0;

UPDATE public.teams
SET popularity_score = coalesce(popularity_score, 0)
WHERE popularity_score IS NULL;

ALTER TABLE public.teams
  ALTER COLUMN popularity_score SET DEFAULT 0,
  ALTER COLUMN popularity_score SET NOT NULL;

ALTER TABLE public.venues
  ADD COLUMN IF NOT EXISTS country_id uuid,
  ADD COLUMN IF NOT EXISTS owner_user_id uuid,
  ADD COLUMN IF NOT EXISTS type text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'draft'::text,
  ADD COLUMN IF NOT EXISTS fet_reward_percent numeric(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS accepts_fet_spend boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS payment_methods text[] DEFAULT ARRAY['cash'::text];

UPDATE public.venues
SET owner_user_id = coalesce(owner_user_id, owner_id),
    type = coalesce(type, venue_type::text),
    address = coalesce(address, nullif(trim(concat_ws(', ', address_line1, address_line2, city, region, postal_code)), '')),
    status = coalesce(
      nullif(status, ''),
      CASE
        WHEN coalesce(is_active, true) = false THEN 'suspended'
        WHEN onboarding_status::text IN ('draft', 'pending', 'approved', 'rejected') THEN onboarding_status::text
        ELSE 'active'
      END
    ),
    fet_reward_percent = CASE
      WHEN coalesce(features_json, '{}'::jsonb) ->> 'fet_reward_percent' ~ '^[0-9]+(\\.[0-9]+)?$'
        THEN least(greatest((features_json ->> 'fet_reward_percent')::numeric, 0), 100)
      ELSE coalesce(fet_reward_percent, 0)
    END,
    accepts_fet_spend = coalesce(
      accepts_fet_spend,
      CASE
        WHEN lower(coalesce(features_json ->> 'accepts_fet_spend', '')) IN ('true', '1', 'yes', 'on') THEN true
        ELSE false
      END
    ),
    payment_methods = coalesce(payment_methods, ARRAY['cash'::text])
WHERE owner_user_id IS NULL
   OR type IS NULL
   OR address IS NULL
   OR status IS NULL
   OR fet_reward_percent IS NULL
   OR accepts_fet_spend IS NULL
   OR payment_methods IS NULL;

ALTER TABLE public.venues
  ALTER COLUMN status SET DEFAULT 'draft'::text,
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN fet_reward_percent SET DEFAULT 0,
  ALTER COLUMN fet_reward_percent SET NOT NULL,
  ALTER COLUMN accepts_fet_spend SET DEFAULT false,
  ALTER COLUMN accepts_fet_spend SET NOT NULL,
  ALTER COLUMN payment_methods SET DEFAULT ARRAY['cash'::text],
  ALTER COLUMN payment_methods SET NOT NULL;

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS starts_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS status text,
  ADD COLUMN IF NOT EXISTS home_score integer,
  ADD COLUMN IF NOT EXISTS away_score integer,
  ADD COLUMN IF NOT EXISTS winner_camp text,
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS is_curated boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS country_visibility text[] DEFAULT '{}'::text[];

UPDATE public.matches
SET starts_at = coalesce(starts_at, match_date),
    status = coalesce(
      status,
      CASE match_status
        WHEN 'finished' THEN 'final'
        ELSE coalesce(match_status, 'scheduled')
      END
    ),
    home_score = coalesce(home_score, home_goals),
    away_score = coalesce(away_score, away_goals),
    source = coalesce(source, source_name, 'manual'),
    winner_camp = coalesce(winner_camp, public.sports_bar_winner_camp(result_code)),
    is_curated = coalesce(is_curated, false),
    country_visibility = coalesce(country_visibility, '{}'::text[])
WHERE starts_at IS NULL
   OR status IS NULL
   OR home_score IS NULL
   OR away_score IS NULL
   OR source IS NULL
   OR (winner_camp IS NULL AND result_code IS NOT NULL)
   OR is_curated IS NULL
   OR country_visibility IS NULL;

ALTER TABLE public.matches
  ALTER COLUMN is_curated SET DEFAULT false,
  ALTER COLUMN is_curated SET NOT NULL,
  ALTER COLUMN country_visibility SET DEFAULT '{}'::text[],
  ALTER COLUMN country_visibility SET NOT NULL;

ALTER TABLE public.match_pool_camps
  ADD COLUMN IF NOT EXISTS camp_key text,
  ADD COLUMN IF NOT EXISTS team_id text,
  ADD COLUMN IF NOT EXISTS is_winning_camp boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc', now());

UPDATE public.match_pool_camps
SET camp_key = CASE
      WHEN lower(code) IN ('home', 'h') THEN 'home'
      WHEN lower(code) IN ('draw', 'd') THEN 'draw'
      WHEN lower(code) IN ('away', 'a') THEN 'away'
      ELSE 'custom'
    END,
    is_winning_camp = coalesce(is_winning_camp, false),
    updated_at = coalesce(updated_at, created_at, timezone('utc', now()))
WHERE camp_key IS NULL
   OR is_winning_camp IS NULL
   OR updated_at IS NULL;

ALTER TABLE public.match_pool_camps
  ALTER COLUMN is_winning_camp SET DEFAULT false,
  ALTER COLUMN is_winning_camp SET NOT NULL,
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET NOT NULL;

ALTER TABLE public.match_pools
  ADD COLUMN IF NOT EXISTS country_id uuid,
  ADD COLUMN IF NOT EXISTS rules_json jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS allow_multiple boolean DEFAULT false;

UPDATE public.match_pools p
SET country_id = coalesce(p.country_id, c.id),
    rules_json = coalesce(p.rules_json, '{}'::jsonb),
    allow_multiple = coalesce(p.allow_multiple, false)
FROM public.countries c
WHERE p.country_code = c.iso_code
  AND (p.country_id IS NULL OR p.rules_json IS NULL OR p.allow_multiple IS NULL);

UPDATE public.match_pools
SET rules_json = coalesce(rules_json, '{}'::jsonb),
    allow_multiple = coalesce(allow_multiple, false)
WHERE rules_json IS NULL OR allow_multiple IS NULL;

ALTER TABLE public.match_pools
  ALTER COLUMN rules_json SET DEFAULT '{}'::jsonb,
  ALTER COLUMN rules_json SET NOT NULL,
  ALTER COLUMN allow_multiple SET DEFAULT false,
  ALTER COLUMN allow_multiple SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'competitions_type_sports_bar_check'
      AND conrelid = 'public.competitions'::regclass
  ) THEN
    ALTER TABLE public.competitions
      ADD CONSTRAINT competitions_type_sports_bar_check
      CHECK (type IS NULL OR type = ANY (ARRAY['league'::text, 'cup'::text, 'world_cup'::text, 'local_curated'::text]))
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'teams_popularity_score_check'
      AND conrelid = 'public.teams'::regclass
  ) THEN
    ALTER TABLE public.teams
      ADD CONSTRAINT teams_popularity_score_check CHECK (popularity_score >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'venues_fet_reward_percent_check'
      AND conrelid = 'public.venues'::regclass
  ) THEN
    ALTER TABLE public.venues
      ADD CONSTRAINT venues_fet_reward_percent_check
      CHECK (fet_reward_percent >= 0 AND fet_reward_percent <= 100)
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'matches_status_sports_bar_check'
      AND conrelid = 'public.matches'::regclass
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_status_sports_bar_check
      CHECK (status IS NULL OR status = ANY (ARRAY['scheduled'::text, 'live'::text, 'final'::text, 'cancelled'::text, 'postponed'::text]))
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'matches_home_score_check'
      AND conrelid = 'public.matches'::regclass
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_home_score_check CHECK (home_score IS NULL OR home_score >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'matches_away_score_check'
      AND conrelid = 'public.matches'::regclass
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_away_score_check CHECK (away_score IS NULL OR away_score >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'matches_winner_camp_check'
      AND conrelid = 'public.matches'::regclass
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_winner_camp_check
      CHECK (winner_camp IS NULL OR winner_camp = ANY (ARRAY['home'::text, 'draw'::text, 'away'::text]))
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'match_pool_camps_camp_key_check'
      AND conrelid = 'public.match_pool_camps'::regclass
  ) THEN
    ALTER TABLE public.match_pool_camps
      ADD CONSTRAINT match_pool_camps_camp_key_check
      CHECK (camp_key IS NULL OR camp_key = ANY (ARRAY['home'::text, 'draw'::text, 'away'::text, 'custom'::text]))
      NOT VALID;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS competitions_country_id_idx ON public.competitions (country_id);
CREATE INDEX IF NOT EXISTS teams_country_id_idx ON public.teams (country_id);
CREATE INDEX IF NOT EXISTS teams_popularity_idx ON public.teams (popularity_score DESC);
CREATE INDEX IF NOT EXISTS venues_country_id_idx ON public.venues (country_id);
CREATE INDEX IF NOT EXISTS match_pools_country_id_idx ON public.match_pools (country_id);
CREATE INDEX IF NOT EXISTS reward_rules_country_idx ON public.reward_rules (country_id, is_active);
CREATE INDEX IF NOT EXISTS reward_rules_venue_idx ON public.reward_rules (venue_id, is_active);

CREATE UNIQUE INDEX IF NOT EXISTS reward_rules_one_active_platform_idx
ON public.reward_rules (scope)
WHERE scope = 'platform'::text AND is_active = true;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'competitions_country_id_fkey'
      AND conrelid = 'public.competitions'::regclass
  ) THEN
    ALTER TABLE public.competitions
      ADD CONSTRAINT competitions_country_id_fkey
      FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'teams_country_id_fkey'
      AND conrelid = 'public.teams'::regclass
  ) THEN
    ALTER TABLE public.teams
      ADD CONSTRAINT teams_country_id_fkey
      FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'venues_country_id_fkey'
      AND conrelid = 'public.venues'::regclass
  ) THEN
    ALTER TABLE public.venues
      ADD CONSTRAINT venues_country_id_fkey
      FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE RESTRICT
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'match_pools_country_id_fkey'
      AND conrelid = 'public.match_pools'::regclass
  ) THEN
    ALTER TABLE public.match_pools
      ADD CONSTRAINT match_pools_country_id_fkey
      FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'reward_rules_country_id_fkey'
      AND conrelid = 'public.reward_rules'::regclass
  ) THEN
    ALTER TABLE public.reward_rules
      ADD CONSTRAINT reward_rules_country_id_fkey
      FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE CASCADE
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'reward_rules_venue_id_fkey'
      AND conrelid = 'public.reward_rules'::regclass
  ) THEN
    ALTER TABLE public.reward_rules
      ADD CONSTRAINT reward_rules_venue_id_fkey
      FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE
      NOT VALID;
  END IF;
END;
$$;

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_rules ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'countries'
      AND policyname = 'countries_admin_manage'
  ) THEN
    CREATE POLICY countries_admin_manage
    ON public.countries
    TO authenticated
    USING (public.sports_bar_is_admin())
    WITH CHECK (public.sports_bar_is_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'countries'
      AND policyname = 'countries_select_active'
  ) THEN
    CREATE POLICY countries_select_active
    ON public.countries
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.sports_bar_is_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reward_rules'
      AND policyname = 'reward_rules_admin_manage'
  ) THEN
    CREATE POLICY reward_rules_admin_manage
    ON public.reward_rules
    TO authenticated
    USING (public.sports_bar_is_admin())
    WITH CHECK (public.sports_bar_is_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reward_rules'
      AND policyname = 'reward_rules_select_active'
  ) THEN
    CREATE POLICY reward_rules_select_active
    ON public.reward_rules
    FOR SELECT
    TO authenticated
    USING (
      is_active = true
      OR public.sports_bar_is_admin()
      OR (
        venue_id IS NOT NULL
        AND public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role])
      )
    );
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'countries_set_updated_at'
      AND tgrelid = 'public.countries'::regclass
  ) THEN
    CREATE TRIGGER countries_set_updated_at
    BEFORE UPDATE ON public.countries
    FOR EACH ROW EXECUTE FUNCTION public.sports_bar_set_updated_at();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'reward_rules_set_updated_at'
      AND tgrelid = 'public.reward_rules'::regclass
  ) THEN
    CREATE TRIGGER reward_rules_set_updated_at
    BEFORE UPDATE ON public.reward_rules
    FOR EACH ROW EXECUTE FUNCTION public.sports_bar_set_updated_at();
  END IF;
END;
$$;

GRANT SELECT ON TABLE public.countries TO anon, authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.countries TO authenticated, service_role;
GRANT SELECT ON TABLE public.reward_rules TO authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.reward_rules TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.app_config_numeric(text, numeric) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_result_code(integer, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_winner_camp(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid) TO authenticated, service_role;
