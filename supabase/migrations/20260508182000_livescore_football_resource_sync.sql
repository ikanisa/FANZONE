-- LiveScore/provider football resource sync.
--
-- Provider data lands in staging/raw catalog first. It does not curate,
-- feature, or make matches pool eligible; admins still control the public
-- match and pool surface through curated_matches.

CREATE OR REPLACE FUNCTION public.football_catalog_slug(
  p_value text
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT trim(both '-' FROM regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]+', '-', 'g'));
$$;

CREATE OR REPLACE FUNCTION public.football_catalog_validate_url(
  p_url text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT coalesce(
    nullif(trim(p_url), '') ~* '^https://[a-z0-9][a-z0-9.-]+[a-z0-9](/|$)'
    AND lower(trim(p_url)) NOT LIKE 'https://localhost%'
    AND lower(trim(p_url)) NOT LIKE 'https://127.%'
    AND lower(trim(p_url)) NOT LIKE 'https://10.%'
    AND lower(trim(p_url)) NOT LIKE 'https://192.168.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.16.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.17.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.18.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.19.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.2%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.30.%'
    AND lower(trim(p_url)) NOT LIKE 'https://172.31.%'
    AND lower(trim(p_url)) NOT LIKE 'https://[::1]%',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.football_catalog_livescore_image_url(
  p_path text,
  p_asset_type text DEFAULT 'team'
) RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $$
DECLARE
  v_path text := nullif(trim(coalesce(p_path, '')), '');
  v_asset_type text := lower(nullif(trim(coalesce(p_asset_type, '')), ''));
BEGIN
  IF v_path IS NULL THEN
    RETURN NULL;
  END IF;

  IF v_path ~* '^https?://' THEN
    RETURN v_path;
  END IF;

  IF v_asset_type = 'competition' THEN
    RETURN 'https://storage.livescore.com/images/competition/high/' || v_path;
  END IF;

  RETURN 'https://storage.livescore.com/images/team/high/' || v_path;
END;
$$;

CREATE OR REPLACE FUNCTION public.football_catalog_require_admin()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.football_official_resources (
  id text PRIMARY KEY,
  fixture_source_id text REFERENCES public.fixture_sources(id) ON DELETE SET NULL,
  name text NOT NULL,
  provider text NOT NULL,
  resource_type text NOT NULL DEFAULT 'fixtures',
  sport text NOT NULL DEFAULT 'soccer',
  resource_url text NOT NULL,
  api_url text,
  competition_id text REFERENCES public.competitions(id) ON DELETE SET NULL,
  season_id text REFERENCES public.seasons(id) ON DELETE SET NULL,
  category_slug text,
  competition_slug text,
  provider_competition_id text,
  provider_stage_id text,
  timezone_name text NOT NULL DEFAULT 'UTC',
  priority integer NOT NULL DEFAULT 100,
  fetch_mode text NOT NULL DEFAULT 'livescore_public_api',
  parser_key text NOT NULL DEFAULT 'livescore_competition_fixtures',
  is_authoritative boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  requires_review boolean NOT NULL DEFAULT true,
  requires_license boolean NOT NULL DEFAULT false,
  rate_limit_delay_ms integer NOT NULL DEFAULT 750,
  config_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT football_official_resources_type_check
    CHECK (resource_type = ANY (ARRAY['fixtures', 'teams', 'competitions', 'standings', 'results'])),
  CONSTRAINT football_official_resources_fetch_mode_check
    CHECK (fetch_mode = ANY (ARRAY['livescore_public_api', 'next_data', 'json_url', 'csv_url', 'manual_review'])),
  CONSTRAINT football_official_resources_priority_check CHECK (priority >= 0),
  CONSTRAINT football_official_resources_delay_check CHECK (rate_limit_delay_ms >= 0),
  CONSTRAINT football_official_resources_url_check CHECK (public.football_catalog_validate_url(resource_url)),
  CONSTRAINT football_official_resources_api_url_check CHECK (api_url IS NULL OR public.football_catalog_validate_url(api_url))
);

COMMENT ON TABLE public.football_official_resources IS
'Authoritative/public football data resources used for raw catalog sync. Imported rows still require staging review and match curation before public display or pool eligibility.';

CREATE TABLE IF NOT EXISTS public.football_resource_sync_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id text NOT NULL REFERENCES public.football_official_resources(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'running',
  started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  completed_at timestamptz,
  requested_by uuid,
  fetched_url text,
  http_status integer,
  rows_found integer NOT NULL DEFAULT 0,
  rows_staged integer NOT NULL DEFAULT 0,
  rows_applied integer NOT NULL DEFAULT 0,
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT football_resource_sync_runs_status_check
    CHECK (status = ANY (ARRAY['queued', 'running', 'succeeded', 'failed', 'skipped'])),
  CONSTRAINT football_resource_sync_runs_counts_check
    CHECK (rows_found >= 0 AND rows_staged >= 0 AND rows_applied >= 0),
  CONSTRAINT football_resource_sync_runs_fetched_url_check
    CHECK (fetched_url IS NULL OR public.football_catalog_validate_url(fetched_url))
);

CREATE INDEX IF NOT EXISTS football_resource_sync_runs_resource_idx
ON public.football_resource_sync_runs (resource_id, started_at DESC);

CREATE TABLE IF NOT EXISTS public.football_team_asset_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  source_team_id text NOT NULL,
  team_id text REFERENCES public.teams(id) ON DELETE SET NULL,
  team_name text NOT NULL,
  short_name text,
  team_type text NOT NULL DEFAULT 'club',
  country_code text,
  crest_url text,
  logo_url text,
  source_url text,
  status text NOT NULL DEFAULT 'applied',
  source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_seen_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT football_team_asset_sources_unique UNIQUE (provider, source_team_id),
  CONSTRAINT football_team_asset_sources_status_check
    CHECK (status = ANY (ARRAY['staged', 'applied', 'rejected'])),
  CONSTRAINT football_team_asset_sources_country_check
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2,3}$'),
  CONSTRAINT football_team_asset_sources_crest_url_check
    CHECK (crest_url IS NULL OR public.football_catalog_validate_url(crest_url)),
  CONSTRAINT football_team_asset_sources_logo_url_check
    CHECK (logo_url IS NULL OR public.football_catalog_validate_url(logo_url)),
  CONSTRAINT football_team_asset_sources_source_url_check
    CHECK (source_url IS NULL OR public.football_catalog_validate_url(source_url))
);

CREATE INDEX IF NOT EXISTS football_team_asset_sources_team_idx
ON public.football_team_asset_sources (team_id);

CREATE TABLE IF NOT EXISTS public.football_official_fixture_staging (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id text NOT NULL REFERENCES public.football_official_resources(id) ON DELETE CASCADE,
  sync_run_id uuid REFERENCES public.football_resource_sync_runs(id) ON DELETE SET NULL,
  source_match_id text NOT NULL,
  provider_match_id text,
  match_id text,
  competition_id text REFERENCES public.competitions(id) ON DELETE SET NULL,
  season_id text REFERENCES public.seasons(id) ON DELETE SET NULL,
  competition_name text,
  stage text,
  matchday_or_round text,
  home_team_source_id text,
  away_team_source_id text,
  home_team_name text,
  away_team_name text,
  home_team_abbr text,
  away_team_abbr text,
  home_team_logo_url text,
  away_team_logo_url text,
  home_team_id text REFERENCES public.teams(id) ON DELETE SET NULL,
  away_team_id text REFERENCES public.teams(id) ON DELETE SET NULL,
  local_date date,
  local_time time without time zone,
  timezone_name text,
  starts_at timestamptz,
  venue text,
  venue_city text,
  source_url text,
  match_status text NOT NULL DEFAULT 'scheduled',
  is_neutral boolean NOT NULL DEFAULT false,
  confidence text NOT NULL DEFAULT 'provider',
  status text NOT NULL DEFAULT 'staged',
  review_reason text,
  source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT football_official_fixture_staging_unique UNIQUE (resource_id, source_match_id),
  CONSTRAINT football_official_fixture_staging_status_check
    CHECK (status = ANY (ARRAY['staged', 'applied', 'rejected', 'needs_review'])),
  CONSTRAINT football_official_fixture_staging_confidence_check
    CHECK (confidence = ANY (ARRAY['provider', 'official', 'manual', 'inferred'])),
  CONSTRAINT football_official_fixture_staging_match_status_check
    CHECK (match_status = ANY (ARRAY['scheduled', 'live', 'finished', 'postponed', 'cancelled'])),
  CONSTRAINT football_official_fixture_staging_source_url_check
    CHECK (source_url IS NULL OR public.football_catalog_validate_url(source_url)),
  CONSTRAINT football_official_fixture_staging_logo_check
    CHECK (
      (home_team_logo_url IS NULL OR public.football_catalog_validate_url(home_team_logo_url))
      AND (away_team_logo_url IS NULL OR public.football_catalog_validate_url(away_team_logo_url))
    )
);

CREATE INDEX IF NOT EXISTS football_official_fixture_staging_resource_status_idx
ON public.football_official_fixture_staging (resource_id, status, starts_at);

DROP TRIGGER IF EXISTS football_official_resources_updated_at
ON public.football_official_resources;
CREATE TRIGGER football_official_resources_updated_at
BEFORE UPDATE ON public.football_official_resources
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_set_updated_at();

DROP TRIGGER IF EXISTS football_team_asset_sources_updated_at
ON public.football_team_asset_sources;
CREATE TRIGGER football_team_asset_sources_updated_at
BEFORE UPDATE ON public.football_team_asset_sources
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_set_updated_at();

DROP TRIGGER IF EXISTS football_official_fixture_staging_updated_at
ON public.football_official_fixture_staging;
CREATE TRIGGER football_official_fixture_staging_updated_at
BEFORE UPDATE ON public.football_official_fixture_staging
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_set_updated_at();

CREATE OR REPLACE FUNCTION public.football_catalog_validate_resource()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  NEW.provider := lower(nullif(trim(NEW.provider), ''));
  NEW.resource_type := lower(nullif(trim(NEW.resource_type), ''));
  NEW.sport := lower(nullif(trim(NEW.sport), ''));
  NEW.timezone_name := coalesce(nullif(trim(NEW.timezone_name), ''), 'UTC');

  IF NEW.provider IS NULL THEN
    RAISE EXCEPTION 'provider is required';
  END IF;

  IF NOT public.match_catalog_validate_timezone(NEW.timezone_name) THEN
    RAISE EXCEPTION 'Invalid IANA timezone: %', NEW.timezone_name;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS football_official_resources_validate
ON public.football_official_resources;
CREATE TRIGGER football_official_resources_validate
BEFORE INSERT OR UPDATE ON public.football_official_resources
FOR EACH ROW EXECUTE FUNCTION public.football_catalog_validate_resource();

CREATE OR REPLACE FUNCTION public.football_catalog_normalize_match_status(
  p_status text
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT CASE
    WHEN lower(coalesce(p_status, '')) = ANY (ARRAY['live', 'inplay', 'ip', '1h', '2h', 'ht']) THEN 'live'
    WHEN lower(coalesce(p_status, '')) = ANY (ARRAY['finished', 'final', 'ft', 'aet', 'ap']) THEN 'finished'
    WHEN lower(coalesce(p_status, '')) = ANY (ARRAY['postponed', 'ppd']) THEN 'postponed'
    WHEN lower(coalesce(p_status, '')) = ANY (ARRAY['cancelled', 'canceled', 'can']) THEN 'cancelled'
    ELSE 'scheduled'
  END;
$$;

CREATE OR REPLACE FUNCTION public.football_catalog_is_placeholder_team(
  p_name text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT
    lower(coalesce(p_name, '')) ~ '(winner|runner|loser|2nd|third|tbd|to be decided|pending|play-off|playoff)'
    OR upper(trim(coalesce(p_name, ''))) ~ '^([123][A-L]{1,8})(/[123]?[A-L]{1,8})*$';
$$;

CREATE OR REPLACE FUNCTION public.football_catalog_resolve_team(
  p_provider text,
  p_source_team_id text,
  p_team_name text,
  p_short_name text DEFAULT NULL::text,
  p_country_code text DEFAULT NULL::text,
  p_team_type text DEFAULT 'club'::text,
  p_logo_url text DEFAULT NULL::text,
  p_source_url text DEFAULT NULL::text,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_provider text := lower(nullif(trim(coalesce(p_provider, '')), ''));
  v_source_team_id text := nullif(trim(coalesce(p_source_team_id, '')), '');
  v_team_name text := nullif(trim(coalesce(p_team_name, '')), '');
  v_short_name text := nullif(trim(coalesce(p_short_name, '')), '');
  v_country_code text := nullif(upper(trim(coalesce(p_country_code, ''))), '');
  v_team_type text := lower(coalesce(nullif(trim(p_team_type), ''), 'club'));
  v_logo_url text := nullif(trim(coalesce(p_logo_url, '')), '');
  v_team_id text;
  v_alias text;
BEGIN
  IF v_team_name IS NULL OR public.football_catalog_is_placeholder_team(v_team_name) THEN
    RETURN NULL;
  END IF;

  IF v_provider IS NULL THEN
    v_provider := 'provider';
  END IF;

  IF v_source_team_id IS NOT NULL THEN
    v_alias := v_provider || ':' || v_source_team_id;
    SELECT ta.team_id
    INTO v_team_id
    FROM public.team_aliases ta
    WHERE lower(ta.alias_name) = lower(v_alias)
    LIMIT 1;
  END IF;

  IF v_team_id IS NULL THEN
    SELECT t.id
    INTO v_team_id
    FROM public.teams t
    WHERE lower(t.name) = lower(v_team_name)
       OR lower(coalesce(t.short_name, '')) = lower(v_team_name)
    ORDER BY CASE WHEN lower(t.name) = lower(v_team_name) THEN 0 ELSE 1 END, t.id
    LIMIT 1;
  END IF;

  IF v_team_id IS NULL THEN
    v_team_id := v_provider || '_team_' || coalesce(public.football_catalog_slug(v_source_team_id), public.football_catalog_slug(v_team_name));
    INSERT INTO public.teams (
      id,
      name,
      short_name,
      country_code,
      country,
      team_type,
      crest_url,
      logo_url,
      is_active,
      updated_at
    ) VALUES (
      v_team_id,
      v_team_name,
      v_short_name,
      v_country_code,
      v_country_code,
      v_team_type,
      v_logo_url,
      v_logo_url,
      true,
      timezone('utc', now())
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      short_name = coalesce(EXCLUDED.short_name, teams.short_name),
      country_code = coalesce(EXCLUDED.country_code, teams.country_code),
      country = coalesce(EXCLUDED.country, teams.country),
      team_type = coalesce(EXCLUDED.team_type, teams.team_type),
      crest_url = coalesce(EXCLUDED.crest_url, teams.crest_url),
      logo_url = coalesce(EXCLUDED.logo_url, teams.logo_url),
      is_active = true,
      updated_at = timezone('utc', now());
  ELSE
    UPDATE public.teams
    SET short_name = coalesce(v_short_name, short_name),
        country_code = coalesce(v_country_code, country_code),
        country = coalesce(country, v_country_code),
        team_type = coalesce(nullif(team_type, ''), v_team_type),
        crest_url = coalesce(v_logo_url, crest_url),
        logo_url = coalesce(v_logo_url, logo_url),
        is_active = true,
        updated_at = timezone('utc', now())
    WHERE id = v_team_id;
  END IF;

  IF v_alias IS NOT NULL THEN
    INSERT INTO public.team_aliases (team_id, alias_name, source_name)
    VALUES (v_team_id, v_alias, v_provider)
    ON CONFLICT DO NOTHING;
  END IF;

  INSERT INTO public.team_aliases (team_id, alias_name, source_name)
  VALUES (v_team_id, v_team_name, v_provider)
  ON CONFLICT DO NOTHING;

  IF v_source_team_id IS NOT NULL THEN
    INSERT INTO public.football_team_asset_sources (
      provider,
      source_team_id,
      team_id,
      team_name,
      short_name,
      team_type,
      country_code,
      crest_url,
      logo_url,
      source_url,
      status,
      source_payload,
      last_seen_at
    ) VALUES (
      v_provider,
      v_source_team_id,
      v_team_id,
      v_team_name,
      v_short_name,
      v_team_type,
      v_country_code,
      v_logo_url,
      v_logo_url,
      nullif(trim(coalesce(p_source_url, '')), ''),
      'applied',
      coalesce(p_payload, '{}'::jsonb),
      timezone('utc', now())
    )
    ON CONFLICT (provider, source_team_id) DO UPDATE SET
      team_id = EXCLUDED.team_id,
      team_name = EXCLUDED.team_name,
      short_name = coalesce(EXCLUDED.short_name, football_team_asset_sources.short_name),
      team_type = EXCLUDED.team_type,
      country_code = coalesce(EXCLUDED.country_code, football_team_asset_sources.country_code),
      crest_url = coalesce(EXCLUDED.crest_url, football_team_asset_sources.crest_url),
      logo_url = coalesce(EXCLUDED.logo_url, football_team_asset_sources.logo_url),
      source_url = coalesce(EXCLUDED.source_url, football_team_asset_sources.source_url),
      status = 'applied',
      source_payload = EXCLUDED.source_payload,
      last_seen_at = timezone('utc', now()),
      updated_at = timezone('utc', now());
  END IF;

  RETURN v_team_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_register_football_official_resource(
  p_resource_id text,
  p_name text,
  p_provider text,
  p_resource_url text,
  p_resource_type text DEFAULT 'fixtures'::text,
  p_competition_id text DEFAULT NULL::text,
  p_season_id text DEFAULT NULL::text,
  p_api_url text DEFAULT NULL::text,
  p_provider_competition_id text DEFAULT NULL::text,
  p_timezone text DEFAULT 'UTC'::text,
  p_fetch_mode text DEFAULT 'livescore_public_api'::text,
  p_is_authoritative boolean DEFAULT false,
  p_config_json jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_resource_id text := nullif(trim(coalesce(p_resource_id, '')), '');
  v_name text := nullif(trim(coalesce(p_name, '')), '');
  v_provider text := lower(nullif(trim(coalesce(p_provider, '')), ''));
  v_timezone text := coalesce(nullif(trim(p_timezone), ''), 'UTC');
  v_resource public.football_official_resources%ROWTYPE;
BEGIN
  PERFORM public.football_catalog_require_admin();

  IF v_resource_id IS NULL OR v_name IS NULL OR v_provider IS NULL THEN
    RAISE EXCEPTION 'resource id, name, and provider are required';
  END IF;

  IF NOT public.football_catalog_validate_url(p_resource_url) THEN
    RAISE EXCEPTION 'Invalid resource URL';
  END IF;

  IF p_api_url IS NOT NULL AND NOT public.football_catalog_validate_url(p_api_url) THEN
    RAISE EXCEPTION 'Invalid API URL';
  END IF;

  IF NOT public.match_catalog_validate_timezone(v_timezone) THEN
    RAISE EXCEPTION 'Invalid IANA timezone: %', v_timezone;
  END IF;

  INSERT INTO public.fixture_sources (
    id,
    name,
    source_type,
    is_approved,
    is_active,
    config_json,
    updated_at
  ) VALUES (
    v_resource_id,
    v_name,
    'api',
    true,
    true,
    jsonb_build_object(
      'provider', v_provider,
      'resource_url', p_resource_url,
      'api_url', p_api_url,
      'authoritative', coalesce(p_is_authoritative, false)
    ) || coalesce(p_config_json, '{}'::jsonb),
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    source_type = 'api',
    is_approved = true,
    is_active = true,
    config_json = EXCLUDED.config_json,
    updated_at = timezone('utc', now());

  INSERT INTO public.football_official_resources (
    id,
    fixture_source_id,
    name,
    provider,
    resource_type,
    sport,
    resource_url,
    api_url,
    competition_id,
    season_id,
    provider_competition_id,
    timezone_name,
    fetch_mode,
    is_authoritative,
    config_json
  ) VALUES (
    v_resource_id,
    v_resource_id,
    v_name,
    v_provider,
    coalesce(nullif(lower(trim(p_resource_type)), ''), 'fixtures'),
    'soccer',
    trim(p_resource_url),
    nullif(trim(coalesce(p_api_url, '')), ''),
    nullif(trim(coalesce(p_competition_id, '')), ''),
    nullif(trim(coalesce(p_season_id, '')), ''),
    nullif(trim(coalesce(p_provider_competition_id, '')), ''),
    v_timezone,
    coalesce(nullif(trim(p_fetch_mode), ''), 'livescore_public_api'),
    coalesce(p_is_authoritative, false),
    coalesce(p_config_json, '{}'::jsonb)
  )
  ON CONFLICT (id) DO UPDATE SET
    fixture_source_id = EXCLUDED.fixture_source_id,
    name = EXCLUDED.name,
    provider = EXCLUDED.provider,
    resource_type = EXCLUDED.resource_type,
    sport = EXCLUDED.sport,
    resource_url = EXCLUDED.resource_url,
    api_url = EXCLUDED.api_url,
    competition_id = EXCLUDED.competition_id,
    season_id = EXCLUDED.season_id,
    provider_competition_id = EXCLUDED.provider_competition_id,
    timezone_name = EXCLUDED.timezone_name,
    fetch_mode = EXCLUDED.fetch_mode,
    is_authoritative = EXCLUDED.is_authoritative,
    is_active = true,
    config_json = EXCLUDED.config_json,
    updated_at = timezone('utc', now())
  RETURNING * INTO v_resource;

  RETURN to_jsonb(v_resource);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_start_football_resource_sync(
  p_resource_id text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_run_id uuid;
BEGIN
  PERFORM public.football_catalog_require_admin();

  IF NOT EXISTS (
    SELECT 1 FROM public.football_official_resources
    WHERE id = p_resource_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Active football resource not found: %', p_resource_id;
  END IF;

  INSERT INTO public.football_resource_sync_runs (
    resource_id,
    status,
    requested_by,
    metadata
  ) VALUES (
    p_resource_id,
    'running',
    auth.uid(),
    coalesce(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_run_id;

  RETURN v_run_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_finish_football_resource_sync(
  p_sync_run_id uuid,
  p_status text,
  p_rows_found integer DEFAULT 0,
  p_rows_staged integer DEFAULT 0,
  p_rows_applied integer DEFAULT 0,
  p_error_message text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_run public.football_resource_sync_runs%ROWTYPE;
BEGIN
  PERFORM public.football_catalog_require_admin();

  UPDATE public.football_resource_sync_runs
  SET status = coalesce(nullif(trim(p_status), ''), 'succeeded'),
      rows_found = greatest(0, coalesce(p_rows_found, rows_found)),
      rows_staged = greatest(0, coalesce(p_rows_staged, rows_staged)),
      rows_applied = greatest(0, coalesce(p_rows_applied, rows_applied)),
      error_message = nullif(trim(coalesce(p_error_message, '')), ''),
      metadata = metadata || coalesce(p_metadata, '{}'::jsonb),
      completed_at = timezone('utc', now())
  WHERE id = p_sync_run_id
  RETURNING * INTO v_run;

  IF v_run.id IS NULL THEN
    RAISE EXCEPTION 'Sync run not found: %', p_sync_run_id;
  END IF;

  UPDATE public.football_official_resources
  SET last_checked_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = v_run.resource_id;

  RETURN to_jsonb(v_run);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_stage_official_fixture_rows(
  p_resource_id text,
  p_rows jsonb,
  p_sync_run_id uuid DEFAULT NULL::uuid,
  p_timezone text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_resource public.football_official_resources%ROWTYPE;
  v_row jsonb;
  v_source_match_id text;
  v_timezone text;
  v_local_date date;
  v_local_time time without time zone;
  v_starts_at timestamptz;
  v_home_team_id text;
  v_away_team_id text;
  v_home_name text;
  v_away_name text;
  v_home_logo text;
  v_away_logo text;
  v_venue text;
  v_status text;
  v_review_reason text;
  v_count integer := 0;
  v_needs_review integer := 0;
  v_run_id uuid := p_sync_run_id;
BEGIN
  PERFORM public.football_catalog_require_admin();

  IF jsonb_typeof(coalesce(p_rows, 'null'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'p_rows must be a JSON array';
  END IF;

  SELECT *
  INTO v_resource
  FROM public.football_official_resources
  WHERE id = p_resource_id
    AND is_active = true;

  IF v_resource.id IS NULL THEN
    RAISE EXCEPTION 'Active football resource not found: %', p_resource_id;
  END IF;

  IF v_run_id IS NULL THEN
    INSERT INTO public.football_resource_sync_runs (
      resource_id,
      status,
      requested_by,
      rows_found,
      metadata
    ) VALUES (
      p_resource_id,
      'running',
      auth.uid(),
      jsonb_array_length(p_rows),
      jsonb_build_object('created_by_rpc', true)
    )
    RETURNING id INTO v_run_id;
  END IF;

  FOR v_row IN
    SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    v_source_match_id := coalesce(
      nullif(trim(v_row ->> 'source_match_id'), ''),
      nullif(trim(v_row ->> 'external_match_id'), ''),
      nullif(trim(v_row ->> 'provider_match_id'), ''),
      nullif(trim(v_row ->> 'id'), '')
    );
    v_home_name := nullif(trim(coalesce(v_row ->> 'home_team_name', v_row ->> 'homeTeamName', '')), '');
    v_away_name := nullif(trim(coalesce(v_row ->> 'away_team_name', v_row ->> 'awayTeamName', '')), '');
    v_home_logo := coalesce(
      nullif(trim(v_row ->> 'home_team_logo_url'), ''),
      public.football_catalog_livescore_image_url(v_row ->> 'home_team_image_path', 'team')
    );
    v_away_logo := coalesce(
      nullif(trim(v_row ->> 'away_team_logo_url'), ''),
      public.football_catalog_livescore_image_url(v_row ->> 'away_team_image_path', 'team')
    );
    v_venue := nullif(trim(concat_ws(', ', nullif(v_row ->> 'venue', ''), nullif(v_row ->> 'venue_city', ''))), '');
    v_timezone := coalesce(
      nullif(trim(v_row ->> 'timezone_name'), ''),
      nullif(trim(v_row ->> 'timezone'), ''),
      nullif(trim(p_timezone), ''),
      v_resource.timezone_name,
      public.match_catalog_resolve_timezone(
        coalesce(nullif(v_row ->> 'competition_id', ''), v_resource.competition_id),
        v_venue,
        null,
        p_resource_id
      ),
      'UTC'
    );

    IF v_source_match_id IS NULL THEN
      RAISE EXCEPTION 'source_match_id is required for every staged fixture row';
    END IF;

    IF NOT public.match_catalog_validate_timezone(v_timezone) THEN
      RAISE EXCEPTION 'Invalid IANA timezone for source match %: %', v_source_match_id, v_timezone;
    END IF;

    v_local_date := nullif(trim(coalesce(v_row ->> 'local_date', '')), '')::date;
    v_local_time := nullif(trim(coalesce(v_row ->> 'local_time', '')), '')::time without time zone;
    v_starts_at := coalesce(
      nullif(trim(coalesce(v_row ->> 'starts_at', '')), '')::timestamptz,
      public.match_catalog_local_kickoff_to_utc(v_local_date, v_local_time, v_timezone)
    );

    v_home_team_id := public.football_catalog_resolve_team(
      v_resource.provider,
      nullif(trim(coalesce(v_row ->> 'home_team_source_id', v_row ->> 'home_team_provider_id', '')), ''),
      v_home_name,
      nullif(trim(coalesce(v_row ->> 'home_team_abbr', '')), ''),
      nullif(trim(coalesce(v_row ->> 'home_team_country_code', '')), ''),
      coalesce(nullif(trim(v_row ->> 'home_team_type'), ''), 'national'),
      v_home_logo,
      coalesce(nullif(trim(v_row ->> 'source_url'), ''), v_resource.resource_url),
      v_row
    );

    v_away_team_id := public.football_catalog_resolve_team(
      v_resource.provider,
      nullif(trim(coalesce(v_row ->> 'away_team_source_id', v_row ->> 'away_team_provider_id', '')), ''),
      v_away_name,
      nullif(trim(coalesce(v_row ->> 'away_team_abbr', '')), ''),
      nullif(trim(coalesce(v_row ->> 'away_team_country_code', '')), ''),
      coalesce(nullif(trim(v_row ->> 'away_team_type'), ''), 'national'),
      v_away_logo,
      coalesce(nullif(trim(v_row ->> 'source_url'), ''), v_resource.resource_url),
      v_row
    );

    v_status := public.football_catalog_normalize_match_status(
      coalesce(v_row ->> 'match_status', v_row ->> 'status', v_row ->> 'event_status')
    );

    v_review_reason := NULL;
    IF v_home_team_id IS NULL OR v_away_team_id IS NULL THEN
      v_review_reason := concat_ws('; ', v_review_reason, 'team mapping requires review');
    END IF;
    IF v_starts_at IS NULL THEN
      v_review_reason := concat_ws('; ', v_review_reason, 'kickoff requires review');
    END IF;

    INSERT INTO public.football_official_fixture_staging (
      resource_id,
      sync_run_id,
      source_match_id,
      provider_match_id,
      competition_id,
      season_id,
      competition_name,
      stage,
      matchday_or_round,
      home_team_source_id,
      away_team_source_id,
      home_team_name,
      away_team_name,
      home_team_abbr,
      away_team_abbr,
      home_team_logo_url,
      away_team_logo_url,
      home_team_id,
      away_team_id,
      local_date,
      local_time,
      timezone_name,
      starts_at,
      venue,
      venue_city,
      source_url,
      match_status,
      is_neutral,
      confidence,
      status,
      review_reason,
      source_payload
    ) VALUES (
      p_resource_id,
      v_run_id,
      v_source_match_id,
      coalesce(nullif(trim(v_row ->> 'provider_match_id'), ''), v_source_match_id),
      coalesce(nullif(trim(v_row ->> 'competition_id'), ''), v_resource.competition_id),
      coalesce(nullif(trim(v_row ->> 'season_id'), ''), v_resource.season_id),
      coalesce(nullif(trim(v_row ->> 'competition_name'), ''), v_resource.name),
      nullif(trim(coalesce(v_row ->> 'stage', '')), ''),
      nullif(trim(coalesce(v_row ->> 'matchday_or_round', v_row ->> 'round', '')), ''),
      nullif(trim(coalesce(v_row ->> 'home_team_source_id', v_row ->> 'home_team_provider_id', '')), ''),
      nullif(trim(coalesce(v_row ->> 'away_team_source_id', v_row ->> 'away_team_provider_id', '')), ''),
      v_home_name,
      v_away_name,
      nullif(trim(coalesce(v_row ->> 'home_team_abbr', '')), ''),
      nullif(trim(coalesce(v_row ->> 'away_team_abbr', '')), ''),
      v_home_logo,
      v_away_logo,
      v_home_team_id,
      v_away_team_id,
      v_local_date,
      v_local_time,
      v_timezone,
      v_starts_at,
      nullif(trim(coalesce(v_row ->> 'venue', '')), ''),
      nullif(trim(coalesce(v_row ->> 'venue_city', '')), ''),
      coalesce(nullif(trim(v_row ->> 'source_url'), ''), v_resource.resource_url),
      v_status,
      coalesce((v_row ->> 'is_neutral')::boolean, false),
      coalesce(nullif(trim(v_row ->> 'confidence'), ''), CASE WHEN v_resource.is_authoritative THEN 'official' ELSE 'provider' END),
      CASE WHEN v_review_reason IS NULL THEN 'staged' ELSE 'needs_review' END,
      v_review_reason,
      v_row
    )
    ON CONFLICT (resource_id, source_match_id) DO UPDATE SET
      sync_run_id = EXCLUDED.sync_run_id,
      provider_match_id = EXCLUDED.provider_match_id,
      competition_id = EXCLUDED.competition_id,
      season_id = EXCLUDED.season_id,
      competition_name = EXCLUDED.competition_name,
      stage = EXCLUDED.stage,
      matchday_or_round = EXCLUDED.matchday_or_round,
      home_team_source_id = EXCLUDED.home_team_source_id,
      away_team_source_id = EXCLUDED.away_team_source_id,
      home_team_name = EXCLUDED.home_team_name,
      away_team_name = EXCLUDED.away_team_name,
      home_team_abbr = EXCLUDED.home_team_abbr,
      away_team_abbr = EXCLUDED.away_team_abbr,
      home_team_logo_url = EXCLUDED.home_team_logo_url,
      away_team_logo_url = EXCLUDED.away_team_logo_url,
      home_team_id = EXCLUDED.home_team_id,
      away_team_id = EXCLUDED.away_team_id,
      local_date = EXCLUDED.local_date,
      local_time = EXCLUDED.local_time,
      timezone_name = EXCLUDED.timezone_name,
      starts_at = EXCLUDED.starts_at,
      venue = EXCLUDED.venue,
      venue_city = EXCLUDED.venue_city,
      source_url = EXCLUDED.source_url,
      match_status = EXCLUDED.match_status,
      is_neutral = EXCLUDED.is_neutral,
      confidence = EXCLUDED.confidence,
      status = CASE WHEN football_official_fixture_staging.status = 'applied' THEN 'staged' ELSE EXCLUDED.status END,
      review_reason = EXCLUDED.review_reason,
      source_payload = EXCLUDED.source_payload,
      updated_at = timezone('utc', now());

    v_count := v_count + 1;
    IF v_review_reason IS NOT NULL THEN
      v_needs_review := v_needs_review + 1;
    END IF;
  END LOOP;

  UPDATE public.football_resource_sync_runs
  SET rows_found = greatest(rows_found, jsonb_array_length(p_rows)),
      rows_staged = rows_staged + v_count,
      status = CASE WHEN v_needs_review > 0 THEN 'succeeded' ELSE status END,
      metadata = metadata || jsonb_build_object('last_stage_needs_review', v_needs_review)
  WHERE id = v_run_id;

  UPDATE public.football_official_resources
  SET last_checked_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = p_resource_id;

  RETURN jsonb_build_object(
    'status', 'staged',
    'resource_id', p_resource_id,
    'sync_run_id', v_run_id,
    'received_rows', jsonb_array_length(p_rows),
    'staged_rows', v_count,
    'needs_review_rows', v_needs_review
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_official_fixture_staging(
  p_staging_id uuid,
  p_create_missing boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_staging public.football_official_fixture_staging%ROWTYPE;
  v_resource public.football_official_resources%ROWTYPE;
  v_competition_id text;
  v_season_id text;
  v_match_id text;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.football_catalog_require_admin();

  SELECT *
  INTO v_staging
  FROM public.football_official_fixture_staging
  WHERE id = p_staging_id
  FOR UPDATE;

  IF v_staging.id IS NULL THEN
    RAISE EXCEPTION 'Staging row not found: %', p_staging_id;
  END IF;

  SELECT *
  INTO v_resource
  FROM public.football_official_resources
  WHERE id = v_staging.resource_id;

  IF v_resource.id IS NULL THEN
    RAISE EXCEPTION 'Resource not found: %', v_staging.resource_id;
  END IF;

  IF v_staging.starts_at IS NULL
     OR v_staging.home_team_id IS NULL
     OR v_staging.away_team_id IS NULL THEN
    UPDATE public.football_official_fixture_staging
    SET status = 'needs_review',
        review_reason = concat_ws(
          '; ',
          review_reason,
          CASE WHEN starts_at IS NULL THEN 'kickoff missing' END,
          CASE WHEN home_team_id IS NULL OR away_team_id IS NULL THEN 'team mapping missing' END
        )
    WHERE id = p_staging_id;

    RETURN jsonb_build_object(
      'status', 'needs_review',
      'staging_id', p_staging_id,
      'reason', 'missing kickoff or team mapping'
    );
  END IF;

  v_competition_id := coalesce(
    v_staging.competition_id,
    v_resource.competition_id,
    v_resource.provider || '_competition_' || public.football_catalog_slug(coalesce(v_resource.provider_competition_id, v_staging.competition_name, v_resource.name))
  );

  INSERT INTO public.competitions (
    id,
    name,
    short_name,
    country,
    data_source,
    country_or_region,
    competition_type,
    type,
    is_international,
    is_active,
    status,
    priority,
    updated_at
  ) VALUES (
    v_competition_id,
    coalesce(v_staging.competition_name, v_resource.name),
    coalesce(v_staging.competition_name, v_resource.name),
    'International',
    v_resource.id,
    'International',
    CASE
      WHEN v_competition_id ILIKE '%world_cup%'
        OR coalesce(v_staging.competition_name, v_resource.name) ILIKE '%World Cup%'
      THEN 'world_cup'
      ELSE 'cup'
    END,
    CASE
      WHEN v_competition_id ILIKE '%world_cup%'
        OR coalesce(v_staging.competition_name, v_resource.name) ILIKE '%World Cup%'
      THEN 'world_cup'
      ELSE 'cup'
    END,
    true,
    true,
    'active',
    v_resource.priority,
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    data_source = EXCLUDED.data_source,
    country_or_region = EXCLUDED.country_or_region,
    is_international = true,
    is_active = true,
    status = 'active',
    updated_at = timezone('utc', now());

  v_season_id := coalesce(
    v_staging.season_id,
    v_resource.season_id,
    v_competition_id || ':' || to_char(v_staging.starts_at AT TIME ZONE 'UTC', 'YYYY')
  );

  INSERT INTO public.seasons (
    id,
    competition_id,
    season_label,
    start_year,
    end_year,
    is_current,
    updated_at
  ) VALUES (
    v_season_id,
    v_competition_id,
    to_char(v_staging.starts_at AT TIME ZONE 'UTC', 'YYYY'),
    extract(year FROM v_staging.starts_at AT TIME ZONE 'UTC')::integer,
    extract(year FROM v_staging.starts_at AT TIME ZONE 'UTC')::integer,
    true,
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE SET
    competition_id = EXCLUDED.competition_id,
    season_label = EXCLUDED.season_label,
    is_current = EXCLUDED.is_current,
    updated_at = timezone('utc', now());

  v_match_id := coalesce(
    v_staging.match_id,
    v_resource.provider || '_match_' || public.football_catalog_slug(v_staging.source_match_id)
  );

  SELECT to_jsonb(m.*)
  INTO v_before
  FROM public.matches m
  WHERE m.id = v_match_id;

  INSERT INTO public.matches (
    id,
    competition_id,
    season_id,
    stage,
    matchday_or_round,
    match_date,
    starts_at,
    home_team_id,
    away_team_id,
    venue,
    source_url,
    match_status,
    status,
    is_neutral,
    source_name,
    source,
    notes,
    updated_at
  ) VALUES (
    v_match_id,
    v_competition_id,
    v_season_id,
    v_staging.stage,
    v_staging.matchday_or_round,
    v_staging.starts_at,
    v_staging.starts_at,
    v_staging.home_team_id,
    v_staging.away_team_id,
    nullif(trim(concat_ws(', ', v_staging.venue, v_staging.venue_city)), ''),
    v_staging.source_url,
    v_staging.match_status,
    v_staging.match_status,
    v_staging.is_neutral,
    v_resource.id,
    v_resource.provider,
    concat_ws(
      ' ',
      'Provider fixture sync:',
      v_resource.provider,
      'source_match_id=' || v_staging.source_match_id,
      'timezone=' || coalesce(v_staging.timezone_name, 'UTC')
    ),
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE SET
    competition_id = EXCLUDED.competition_id,
    season_id = EXCLUDED.season_id,
    stage = EXCLUDED.stage,
    matchday_or_round = EXCLUDED.matchday_or_round,
    match_date = EXCLUDED.match_date,
    starts_at = EXCLUDED.starts_at,
    home_team_id = EXCLUDED.home_team_id,
    away_team_id = EXCLUDED.away_team_id,
    venue = coalesce(EXCLUDED.venue, matches.venue),
    source_url = coalesce(EXCLUDED.source_url, matches.source_url),
    match_status = EXCLUDED.match_status,
    status = EXCLUDED.status,
    is_neutral = EXCLUDED.is_neutral,
    source_name = EXCLUDED.source_name,
    source = EXCLUDED.source,
    notes = concat_ws(' ', matches.notes, EXCLUDED.notes),
    updated_at = timezone('utc', now())
  RETURNING to_jsonb(matches.*) INTO v_after;

  UPDATE public.football_official_fixture_staging
  SET status = 'applied',
      match_id = v_match_id,
      review_reason = NULL,
      updated_at = timezone('utc', now())
  WHERE id = p_staging_id;

  UPDATE public.football_resource_sync_runs
  SET rows_applied = rows_applied + 1
  WHERE id = v_staging.sync_run_id;

  PERFORM public.sports_bar_write_audit(
    'admin_apply_official_fixture_staging',
    'match',
    v_match_id,
    v_before,
    v_after,
    auth.uid()
  );

  RETURN jsonb_build_object(
    'status', 'applied',
    'staging_id', p_staging_id,
    'match_id', v_match_id,
    'match', v_after
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_official_fixture_staging_batch(
  p_resource_id text,
  p_limit integer DEFAULT 500
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_row record;
  v_applied integer := 0;
  v_review integer := 0;
  v_result jsonb;
BEGIN
  PERFORM public.football_catalog_require_admin();

  FOR v_row IN
    SELECT id
    FROM public.football_official_fixture_staging
    WHERE resource_id = p_resource_id
      AND status = 'staged'
    ORDER BY starts_at NULLS LAST, source_match_id
    LIMIT greatest(1, least(coalesce(p_limit, 500), 1000))
  LOOP
    v_result := public.admin_apply_official_fixture_staging(v_row.id, true);
    IF v_result ->> 'status' = 'applied' THEN
      v_applied := v_applied + 1;
    ELSE
      v_review := v_review + 1;
    END IF;
  END LOOP;

  UPDATE public.football_resource_sync_runs
  SET status = 'succeeded',
      completed_at = coalesce(completed_at, timezone('utc', now()))
  WHERE resource_id = p_resource_id
    AND status = 'running';

  RETURN jsonb_build_object(
    'status', 'completed',
    'resource_id', p_resource_id,
    'applied_rows', v_applied,
    'needs_review_rows', v_review
  );
END;
$$;

CREATE OR REPLACE VIEW public.football_official_resource_status AS
SELECT
  r.id,
  r.name,
  r.provider,
  r.resource_type,
  r.resource_url,
  r.api_url,
  r.competition_id,
  r.season_id,
  r.provider_competition_id,
  r.timezone_name,
  r.priority,
  r.is_authoritative,
  r.is_active,
  r.requires_review,
  r.last_checked_at,
  latest_run.id AS latest_sync_run_id,
  latest_run.status AS latest_sync_status,
  latest_run.started_at AS latest_sync_started_at,
  latest_run.completed_at AS latest_sync_completed_at,
  latest_run.rows_found AS latest_rows_found,
  latest_run.rows_staged AS latest_rows_staged,
  latest_run.rows_applied AS latest_rows_applied,
  latest_run.error_message AS latest_error_message,
  coalesce(staging_counts.staged_rows, 0) AS staged_rows,
  coalesce(staging_counts.needs_review_rows, 0) AS needs_review_rows,
  coalesce(staging_counts.applied_rows, 0) AS applied_rows
FROM public.football_official_resources r
LEFT JOIN LATERAL (
  SELECT sr.*
  FROM public.football_resource_sync_runs sr
  WHERE sr.resource_id = r.id
  ORDER BY sr.started_at DESC
  LIMIT 1
) latest_run ON true
LEFT JOIN LATERAL (
  SELECT
    count(*) FILTER (WHERE fs.status = 'staged') AS staged_rows,
    count(*) FILTER (WHERE fs.status = 'needs_review') AS needs_review_rows,
    count(*) FILTER (WHERE fs.status = 'applied') AS applied_rows
  FROM public.football_official_fixture_staging fs
  WHERE fs.resource_id = r.id
) staging_counts ON true;

CREATE OR REPLACE FUNCTION public.get_football_official_resource_status()
RETURNS SETOF public.football_official_resource_status
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT *
  FROM public.football_official_resource_status
  ORDER BY is_active DESC, priority ASC, name ASC;
$$;

INSERT INTO public.competitions (
  id,
  name,
  short_name,
  country,
  data_source,
  country_or_region,
  competition_type,
  type,
  is_international,
  is_active,
  status,
  priority,
  updated_at
) VALUES (
  'fifa_world_cup',
  'FIFA World Cup',
  'World Cup',
  'International',
  'livescore_world_cup_2026',
  'International',
  'world_cup',
  'world_cup',
  true,
  true,
  'active',
  10,
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  country = EXCLUDED.country,
  country_or_region = EXCLUDED.country_or_region,
  competition_type = EXCLUDED.competition_type,
  type = EXCLUDED.type,
  is_international = true,
  is_active = true,
  status = 'active',
  priority = least(public.competitions.priority, EXCLUDED.priority),
  updated_at = timezone('utc', now());

INSERT INTO public.seasons (
  id,
  competition_id,
  season_label,
  start_year,
  end_year,
  is_current,
  updated_at
) VALUES (
  'fifa_world_cup_2026',
  'fifa_world_cup',
  '2026',
  2026,
  2026,
  true,
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE SET
  competition_id = EXCLUDED.competition_id,
  season_label = EXCLUDED.season_label,
  start_year = EXCLUDED.start_year,
  end_year = EXCLUDED.end_year,
  is_current = EXCLUDED.is_current,
  updated_at = timezone('utc', now());

INSERT INTO public.fixture_sources (
  id,
  name,
  source_type,
  is_approved,
  is_active,
  config_json,
  updated_at
) VALUES (
  'livescore_world_cup_2026',
  'LiveScore World Cup 2026 fixtures',
  'api',
  true,
  true,
  jsonb_build_object(
    'provider', 'livescore',
    'resource_url', 'https://www.livescore.com/en/football/international/world-cup-2026/fixtures/',
    'api_url', 'https://prod-cdn-public-api.livescore.com/v1/api/app/competition/734/fixtures-w/UTC?locale=en&limit=200',
    'image_base_url', 'https://storage.livescore.com/images/'
  ),
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  source_type = EXCLUDED.source_type,
  is_approved = EXCLUDED.is_approved,
  is_active = EXCLUDED.is_active,
  config_json = EXCLUDED.config_json,
  updated_at = timezone('utc', now());

INSERT INTO public.football_official_resources (
  id,
  fixture_source_id,
  name,
  provider,
  resource_type,
  sport,
  resource_url,
  api_url,
  competition_id,
  season_id,
  category_slug,
  competition_slug,
  provider_competition_id,
  timezone_name,
  priority,
  fetch_mode,
  parser_key,
  is_authoritative,
  is_active,
  requires_review,
  config_json
) VALUES (
  'livescore_world_cup_2026',
  'livescore_world_cup_2026',
  'LiveScore World Cup 2026 fixtures',
  'livescore',
  'fixtures',
  'soccer',
  'https://www.livescore.com/en/football/international/world-cup-2026/fixtures/',
  'https://prod-cdn-public-api.livescore.com/v1/api/app/competition/734/fixtures-w/UTC?locale=en&limit=200',
  'fifa_world_cup',
  'fifa_world_cup_2026',
  'international',
  'world-cup-2026',
  '734',
  'UTC',
  10,
  'livescore_public_api',
  'livescore_competition_fixtures',
  true,
  true,
  true,
  jsonb_build_object(
    'details_endpoint', 'https://prod-cdn-public-api.livescore.com/v1/api/app/info/soccer/{eventId}?locale=en',
    'team_image_base_url', 'https://storage.livescore.com/images/team/high/',
    'competition_image_base_url', 'https://storage.livescore.com/images/competition/high/'
  )
)
ON CONFLICT (id) DO UPDATE SET
  fixture_source_id = EXCLUDED.fixture_source_id,
  name = EXCLUDED.name,
  provider = EXCLUDED.provider,
  resource_type = EXCLUDED.resource_type,
  sport = EXCLUDED.sport,
  resource_url = EXCLUDED.resource_url,
  api_url = EXCLUDED.api_url,
  competition_id = EXCLUDED.competition_id,
  season_id = EXCLUDED.season_id,
  category_slug = EXCLUDED.category_slug,
  competition_slug = EXCLUDED.competition_slug,
  provider_competition_id = EXCLUDED.provider_competition_id,
  timezone_name = EXCLUDED.timezone_name,
  priority = EXCLUDED.priority,
  fetch_mode = EXCLUDED.fetch_mode,
  parser_key = EXCLUDED.parser_key,
  is_authoritative = EXCLUDED.is_authoritative,
  is_active = EXCLUDED.is_active,
  requires_review = EXCLUDED.requires_review,
  config_json = EXCLUDED.config_json,
  updated_at = timezone('utc', now());

DELETE FROM public.matches m
USING public.football_official_fixture_staging fs
WHERE fs.resource_id = 'livescore_world_cup_2026'
  AND fs.match_id = m.id
  AND m.source_name = 'livescore_world_cup_2026'
  AND (
    public.football_catalog_is_placeholder_team(fs.home_team_name)
    OR public.football_catalog_is_placeholder_team(fs.away_team_name)
  );

UPDATE public.football_official_fixture_staging
SET status = 'needs_review',
    match_id = NULL,
    home_team_id = CASE
      WHEN public.football_catalog_is_placeholder_team(home_team_name) THEN NULL
      ELSE home_team_id
    END,
    away_team_id = CASE
      WHEN public.football_catalog_is_placeholder_team(away_team_name) THEN NULL
      ELSE away_team_id
    END,
    review_reason = concat_ws('; ', review_reason, 'team mapping requires review'),
    updated_at = timezone('utc', now())
WHERE resource_id = 'livescore_world_cup_2026'
  AND (
    public.football_catalog_is_placeholder_team(home_team_name)
    OR public.football_catalog_is_placeholder_team(away_team_name)
  );

DELETE FROM public.team_aliases ta
USING public.football_team_asset_sources tas
WHERE tas.provider = 'livescore'
  AND tas.team_id = ta.team_id
  AND public.football_catalog_is_placeholder_team(tas.team_name);

DELETE FROM public.football_team_asset_sources tas
WHERE tas.provider = 'livescore'
  AND public.football_catalog_is_placeholder_team(tas.team_name);

DELETE FROM public.teams t
WHERE t.id LIKE 'livescore_team_%'
  AND public.football_catalog_is_placeholder_team(t.name)
  AND NOT EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE m.home_team_id = t.id
       OR m.away_team_id = t.id
  );

UPDATE public.football_resource_sync_runs sr
SET rows_applied = applied_counts.applied_rows,
    metadata = sr.metadata || jsonb_build_object(
      'placeholder_cleanup_applied', true,
      'placeholder_rows_held_for_review', applied_counts.needs_review_rows
    )
FROM (
  SELECT
    count(*) FILTER (WHERE status = 'applied')::integer AS applied_rows,
    count(*) FILTER (WHERE status = 'needs_review')::integer AS needs_review_rows
  FROM public.football_official_fixture_staging
  WHERE resource_id = 'livescore_world_cup_2026'
) applied_counts
WHERE sr.resource_id = 'livescore_world_cup_2026'
  AND sr.completed_at IS NOT NULL;

ALTER TABLE public.football_official_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.football_resource_sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.football_team_asset_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.football_official_fixture_staging ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS football_official_resources_admin_read ON public.football_official_resources;
CREATE POLICY football_official_resources_admin_read
ON public.football_official_resources
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS football_resource_sync_runs_admin_read ON public.football_resource_sync_runs;
CREATE POLICY football_resource_sync_runs_admin_read
ON public.football_resource_sync_runs
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS football_team_asset_sources_admin_read ON public.football_team_asset_sources;
CREATE POLICY football_team_asset_sources_admin_read
ON public.football_team_asset_sources
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS football_official_fixture_staging_admin_read ON public.football_official_fixture_staging;
CREATE POLICY football_official_fixture_staging_admin_read
ON public.football_official_fixture_staging
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

GRANT SELECT ON TABLE public.football_official_resources TO authenticated, service_role;
GRANT SELECT ON TABLE public.football_resource_sync_runs TO authenticated, service_role;
GRANT SELECT ON TABLE public.football_team_asset_sources TO authenticated, service_role;
GRANT SELECT ON TABLE public.football_official_fixture_staging TO authenticated, service_role;
GRANT SELECT ON TABLE public.football_official_resource_status TO authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.football_official_resources TO service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.football_resource_sync_runs TO service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.football_team_asset_sources TO service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.football_official_fixture_staging TO service_role;

REVOKE ALL ON FUNCTION public.football_catalog_slug(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_slug(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_validate_url(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_validate_url(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_livescore_image_url(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_livescore_image_url(text, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_require_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_require_admin() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_normalize_match_status(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_normalize_match_status(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_is_placeholder_team(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_is_placeholder_team(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.football_catalog_resolve_team(text, text, text, text, text, text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_resolve_team(text, text, text, text, text, text, text, text, jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_register_football_official_resource(text, text, text, text, text, text, text, text, text, text, text, boolean, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_register_football_official_resource(text, text, text, text, text, text, text, text, text, text, text, boolean, jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_start_football_resource_sync(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_start_football_resource_sync(text, jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_finish_football_resource_sync(uuid, text, integer, integer, integer, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_finish_football_resource_sync(uuid, text, integer, integer, integer, text, jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_stage_official_fixture_rows(text, jsonb, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_stage_official_fixture_rows(text, jsonb, uuid, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_apply_official_fixture_staging(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_apply_official_fixture_staging(uuid, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_apply_official_fixture_staging_batch(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_apply_official_fixture_staging_batch(text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_football_official_resource_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_football_official_resource_status() TO authenticated, service_role;
