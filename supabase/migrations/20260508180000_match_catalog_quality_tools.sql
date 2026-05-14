-- Match catalog repair and quality tools.
--
-- These helpers keep imported feeds as raw catalog data. They do not curate,
-- feature, or make matches pool eligible; admins must still use the curated
-- match controls for the public/pool surface.

CREATE TABLE IF NOT EXISTS public.match_catalog_timezone_rules (
  id text PRIMARY KEY,
  competition_id text REFERENCES public.competitions(id) ON DELETE CASCADE,
  country_code text,
  venue_pattern text,
  timezone_name text NOT NULL,
  default_local_time time without time zone,
  confidence text NOT NULL DEFAULT 'default',
  requires_review boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT match_catalog_timezone_rules_country_code_check
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT match_catalog_timezone_rules_confidence_check
    CHECK (confidence = ANY (ARRAY['venue', 'competition', 'country', 'default', 'manual']))
);

COMMENT ON TABLE public.match_catalog_timezone_rules IS
'Timezone defaults used by match catalog repair functions. Rules are only defaults; verified kickoff overrides remain the source of truth.';

CREATE TABLE IF NOT EXISTS public.match_catalog_time_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id text NOT NULL UNIQUE REFERENCES public.matches(id) ON DELETE CASCADE,
  local_date date NOT NULL,
  local_time time without time zone NOT NULL,
  timezone_name text NOT NULL,
  starts_at timestamptz NOT NULL,
  venue text,
  source_url text,
  correction_source text NOT NULL DEFAULT 'admin',
  notes text,
  applied_by uuid,
  applied_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.match_catalog_time_overrides IS
'Auditable verified kickoff corrections applied to imported match catalog rows.';

CREATE INDEX IF NOT EXISTS match_catalog_time_overrides_match_idx
ON public.match_catalog_time_overrides (match_id, applied_at DESC);

CREATE OR REPLACE FUNCTION public.match_catalog_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS match_catalog_timezone_rules_updated_at
ON public.match_catalog_timezone_rules;
CREATE TRIGGER match_catalog_timezone_rules_updated_at
BEFORE UPDATE ON public.match_catalog_timezone_rules
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_set_updated_at();

DROP TRIGGER IF EXISTS match_catalog_time_overrides_updated_at
ON public.match_catalog_time_overrides;
CREATE TRIGGER match_catalog_time_overrides_updated_at
BEFORE UPDATE ON public.match_catalog_time_overrides
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_set_updated_at();

CREATE OR REPLACE FUNCTION public.match_catalog_validate_timezone(
  p_timezone text
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_catalog'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM pg_timezone_names
    WHERE name = nullif(trim(p_timezone), '')
  );
$$;

CREATE OR REPLACE FUNCTION public.match_catalog_validate_timezone_rule()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NOT public.match_catalog_validate_timezone(NEW.timezone_name) THEN
    RAISE EXCEPTION 'Invalid IANA timezone: %', NEW.timezone_name;
  END IF;

  IF NEW.venue_pattern IS NULL AND NEW.competition_id IS NULL AND NEW.country_code IS NULL THEN
    RAISE EXCEPTION 'Timezone rule must target a competition, country, or venue pattern';
  END IF;

  NEW.country_code := nullif(upper(trim(coalesce(NEW.country_code, ''))), '');
  NEW.venue_pattern := nullif(trim(coalesce(NEW.venue_pattern, '')), '');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS match_catalog_timezone_rules_validate
ON public.match_catalog_timezone_rules;
CREATE TRIGGER match_catalog_timezone_rules_validate
BEFORE INSERT OR UPDATE ON public.match_catalog_timezone_rules
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_validate_timezone_rule();

CREATE OR REPLACE FUNCTION public.match_catalog_validate_time_override()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NOT public.match_catalog_validate_timezone(NEW.timezone_name) THEN
    RAISE EXCEPTION 'Invalid IANA timezone: %', NEW.timezone_name;
  END IF;

  NEW.starts_at := (NEW.local_date::timestamp + NEW.local_time) AT TIME ZONE NEW.timezone_name;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS match_catalog_time_overrides_validate
ON public.match_catalog_time_overrides;
CREATE TRIGGER match_catalog_time_overrides_validate
BEFORE INSERT OR UPDATE ON public.match_catalog_time_overrides
FOR EACH ROW EXECUTE FUNCTION public.match_catalog_validate_time_override();

INSERT INTO public.match_catalog_timezone_rules (
  id,
  competition_id,
  country_code,
  venue_pattern,
  timezone_name,
  default_local_time,
  confidence,
  requires_review,
  notes
) VALUES
  ('comp-epl-timezone', 'comp_epl', 'GB', NULL, 'Europe/London', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-bl-timezone', 'comp_bl', 'DE', NULL, 'Europe/Berlin', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-laliga-timezone', 'comp_laliga', 'ES', NULL, 'Europe/Madrid', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-ll-timezone', 'comp_ll', 'ES', NULL, 'Europe/Madrid', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-l1-timezone', 'comp_l1', 'FR', NULL, 'Europe/Paris', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-sa-timezone', 'comp_sa', 'IT', NULL, 'Europe/Rome', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-mpl-timezone', 'comp_mpl', 'MT', NULL, 'Europe/Malta', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-rpl-timezone', 'comp_rpl', 'RW', NULL, 'Africa/Kigali', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-zsl-timezone', 'comp_zsl', 'ZM', NULL, 'Africa/Lusaka', NULL, 'competition', true, 'Competition timezone only. Kickoff time still requires verified source data.'),
  ('comp-drc-timezone', 'comp_drc', 'CD', NULL, 'Africa/Kinshasa', NULL, 'competition', true, 'Default only; DRC venues may need manual timezone verification.'),
  ('wc-venue-mexico-city', 'fifa_world_cup', NULL, '%Mexico City%', 'America/Mexico_City', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-zapopan', 'fifa_world_cup', NULL, '%Zapopan%', 'America/Mexico_City', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-monterrey', 'fifa_world_cup', NULL, '%Monterrey%', 'America/Monterrey', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-vancouver', 'fifa_world_cup', NULL, '%Vancouver%', 'America/Vancouver', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-toronto', 'fifa_world_cup', NULL, '%Toronto%', 'America/Toronto', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-los-angeles', 'fifa_world_cup', NULL, '%Inglewood%', 'America/Los_Angeles', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-santa-clara', 'fifa_world_cup', NULL, '%Santa Clara%', 'America/Los_Angeles', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-seattle', 'fifa_world_cup', NULL, '%Seattle%', 'America/Los_Angeles', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-arlington', 'fifa_world_cup', NULL, '%Arlington%', 'America/Chicago', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-houston', 'fifa_world_cup', NULL, '%Houston%', 'America/Chicago', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-kansas-city', 'fifa_world_cup', NULL, '%Kansas City%', 'America/Chicago', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-east-rutherford', 'fifa_world_cup', NULL, '%East Rutherford%', 'America/New_York', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-foxborough', 'fifa_world_cup', NULL, '%Foxborough%', 'America/New_York', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-philadelphia', 'fifa_world_cup', NULL, '%Philadelphia%', 'America/New_York', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-atlanta', 'fifa_world_cup', NULL, '%Atlanta%', 'America/New_York', NULL, 'venue', false, 'World Cup venue timezone mapping.'),
  ('wc-venue-miami', 'fifa_world_cup', NULL, '%Miami%', 'America/New_York', NULL, 'venue', false, 'World Cup venue timezone mapping.')
ON CONFLICT (id) DO UPDATE SET
  competition_id = EXCLUDED.competition_id,
  country_code = EXCLUDED.country_code,
  venue_pattern = EXCLUDED.venue_pattern,
  timezone_name = EXCLUDED.timezone_name,
  default_local_time = EXCLUDED.default_local_time,
  confidence = EXCLUDED.confidence,
  requires_review = EXCLUDED.requires_review,
  notes = EXCLUDED.notes,
  updated_at = timezone('utc', now());

CREATE OR REPLACE FUNCTION public.match_catalog_local_kickoff_to_utc(
  p_local_date date,
  p_local_time time without time zone,
  p_timezone text
) RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF p_local_date IS NULL THEN
    RAISE EXCEPTION 'local date is required';
  END IF;

  IF p_local_time IS NULL THEN
    RAISE EXCEPTION 'local time is required';
  END IF;

  IF NOT public.match_catalog_validate_timezone(p_timezone) THEN
    RAISE EXCEPTION 'Invalid IANA timezone: %', p_timezone;
  END IF;

  RETURN (p_local_date::timestamp + p_local_time) AT TIME ZONE p_timezone;
END;
$$;

CREATE OR REPLACE FUNCTION public.match_catalog_resolve_timezone(
  p_competition_id text,
  p_venue text DEFAULT NULL::text,
  p_country_code text DEFAULT NULL::text,
  p_source_name text DEFAULT NULL::text
) RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT r.timezone_name
  FROM public.match_catalog_timezone_rules r
  WHERE (r.competition_id IS NULL OR r.competition_id = p_competition_id)
    AND (
      r.country_code IS NULL
      OR nullif(upper(trim(coalesce(p_country_code, ''))), '') IS NULL
      OR r.country_code = nullif(upper(trim(coalesce(p_country_code, ''))), '')
    )
    AND (r.venue_pattern IS NULL OR coalesce(p_venue, '') ILIKE r.venue_pattern)
  ORDER BY
    CASE WHEN r.venue_pattern IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN r.competition_id IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN r.country_code IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN r.requires_review THEN 1 ELSE 0 END,
    r.id
  LIMIT 1;
$$;

CREATE OR REPLACE VIEW public.match_catalog_quality_issues AS
WITH raw_matches AS (
  SELECT
    m.*,
    ht.team_type AS home_team_type,
    ht.country_code AS home_country_code,
    at.team_type AS away_team_type,
    at.country_code AS away_country_code,
    substring(m.notes FROM 'source_match_id=([^;]+)') AS raw_source_match_id,
    public.match_catalog_resolve_timezone(
      m.competition_id,
      m.venue,
      coalesce(ht.country_code, at.country_code),
      m.source_name
    ) AS resolved_timezone
  FROM public.matches m
  LEFT JOIN public.teams ht ON ht.id = m.home_team_id
  LEFT JOIN public.teams at ON at.id = m.away_team_id
),
duplicate_keys AS (
  SELECT
    source_name,
    competition_id,
    season_id,
    raw_source_match_id,
    count(*) AS duplicate_count
  FROM raw_matches
  WHERE raw_source_match_id IS NOT NULL
  GROUP BY source_name, competition_id, season_id, raw_source_match_id
  HAVING count(*) > 1
),
base_issues AS (
  SELECT
    'missing_verified_kickoff_time'::text AS issue_type,
    'high'::text AS severity,
    m.id AS match_id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object(
      'starts_at', m.starts_at,
      'resolved_timezone', m.resolved_timezone,
      'reason', 'Imported row has date-only kickoff. Apply a verified local_date, local_time, and timezone override.'
    ) AS details
  FROM raw_matches m
  WHERE m.source_name = 'csv_matches_all'
    AND m.match_status = 'scheduled'
    AND NOT EXISTS (
      SELECT 1
      FROM public.match_catalog_time_overrides o
      WHERE o.match_id = m.id
    )
    AND (
      m.starts_at IS NULL
      OR (m.starts_at AT TIME ZONE 'UTC')::time = time '00:00'
    )

  UNION ALL

  SELECT
    'missing_venue'::text,
    'medium'::text,
    m.id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object('reason', 'Imported scheduled row has no venue. Venue is needed for World Cup timezone resolution and review context.')
  FROM raw_matches m
  WHERE m.source_name = 'csv_matches_all'
    AND m.match_status = 'scheduled'
    AND nullif(trim(coalesce(m.venue, '')), '') IS NULL

  UNION ALL

  SELECT
    'unresolved_timezone_rule'::text,
    'medium'::text,
    m.id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object('reason', 'No timezone rule matches this competition/country/venue.', 'venue', m.venue)
  FROM raw_matches m
  WHERE m.source_name = 'csv_matches_all'
    AND m.match_status = 'scheduled'
    AND m.resolved_timezone IS NULL

  UNION ALL

  SELECT
    'placeholder_team'::text,
    'high'::text,
    m.id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object(
      'home_team_id', m.home_team_id,
      'away_team_id', m.away_team_id,
      'reason', 'Fixture uses TBD/winner/runner-up placeholder teams and should not be pool eligible until resolved.'
    )
  FROM raw_matches m
  WHERE m.home_team_type = 'placeholder'
     OR m.away_team_type = 'placeholder'

  UNION ALL

  SELECT
    'duplicate_raw_source_match_id'::text,
    'high'::text,
    m.id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object(
      'raw_source_match_id', m.raw_source_match_id,
      'duplicate_count', d.duplicate_count,
      'reason', 'The source CSV reused this match_id for multiple rows; review before curation.'
    )
  FROM raw_matches m
  JOIN duplicate_keys d
    ON d.source_name IS NOT DISTINCT FROM m.source_name
   AND d.competition_id = m.competition_id
   AND d.season_id IS NOT DISTINCT FROM m.season_id
   AND d.raw_source_match_id = m.raw_source_match_id

  UNION ALL

  SELECT
    'world_cup_2026_date_out_of_range'::text,
    'blocker'::text,
    m.id,
    m.competition_id,
    m.season_id,
    m.source_name,
    m.match_date,
    jsonb_build_object('reason', 'World Cup 2026 match date is outside the expected June/July 2026 tournament window.')
  FROM raw_matches m
  WHERE m.season_id = 'fifa_world_cup_2026'
    AND (m.match_date < '2026-06-01'::timestamptz OR m.match_date >= '2026-08-01'::timestamptz)
)
SELECT * FROM base_issues
UNION ALL
SELECT
  'pool_eligible_with_catalog_issue'::text,
  'blocker'::text,
  m.id,
  m.competition_id,
  m.season_id,
  m.source_name,
  m.match_date,
  jsonb_build_object(
    'curation_id', cm.id,
    'reason', 'Pool-eligible curated match still has blocker/high catalog quality issues.'
  )
FROM public.curated_matches cm
JOIN raw_matches m ON m.id = cm.match_id
WHERE cm.is_active = true
  AND cm.is_pool_eligible = true
  AND EXISTS (
    SELECT 1
    FROM base_issues bi
    WHERE bi.match_id = m.id
      AND bi.severity IN ('blocker', 'high')
  );

COMMENT ON VIEW public.match_catalog_quality_issues IS
'Actionable data-quality findings for imported match catalog rows. Raw matches remain hidden until admin curation resolves relevant issues.';

CREATE OR REPLACE FUNCTION public.get_match_catalog_quality_report(
  p_source_name text DEFAULT NULL::text
) RETURNS TABLE (
  issue_type text,
  severity text,
  affected_count bigint,
  sample_match_ids jsonb
)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  WITH filtered AS (
    SELECT *
    FROM public.match_catalog_quality_issues
    WHERE p_source_name IS NULL OR source_name = p_source_name
  ),
  grouped AS (
    SELECT issue_type, severity, count(*) AS affected_count
    FROM filtered
    GROUP BY issue_type, severity
  )
  SELECT
    g.issue_type,
    g.severity,
    g.affected_count,
    (
      SELECT coalesce(jsonb_agg(s.match_id ORDER BY s.match_date, s.match_id), '[]'::jsonb)
      FROM (
        SELECT f.match_id, f.match_date
        FROM filtered f
        WHERE f.issue_type = g.issue_type
          AND f.severity = g.severity
        ORDER BY f.match_date, f.match_id
        LIMIT 10
      ) s
    ) AS sample_match_ids
  FROM grouped g
  ORDER BY
    CASE g.severity WHEN 'blocker' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    g.affected_count DESC,
    g.issue_type;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_match_kickoff_override(
  p_match_id text,
  p_local_date date,
  p_local_time time without time zone,
  p_timezone text,
  p_venue text DEFAULT NULL::text,
  p_source_url text DEFAULT NULL::text,
  p_correction_source text DEFAULT 'admin'::text,
  p_notes text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
  v_starts_at timestamptz;
  v_actor uuid := auth.uid();
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF nullif(trim(coalesce(p_match_id, '')), '') IS NULL THEN
    RAISE EXCEPTION 'match_id is required';
  END IF;

  v_starts_at := public.match_catalog_local_kickoff_to_utc(p_local_date, p_local_time, p_timezone);

  SELECT to_jsonb(m.*)
  INTO v_before
  FROM public.matches m
  WHERE m.id = p_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Match not found: %', p_match_id;
  END IF;

  INSERT INTO public.match_catalog_time_overrides (
    match_id,
    local_date,
    local_time,
    timezone_name,
    starts_at,
    venue,
    source_url,
    correction_source,
    notes,
    applied_by,
    applied_at
  ) VALUES (
    p_match_id,
    p_local_date,
    p_local_time,
    p_timezone,
    v_starts_at,
    nullif(trim(coalesce(p_venue, '')), ''),
    nullif(trim(coalesce(p_source_url, '')), ''),
    coalesce(nullif(trim(p_correction_source), ''), 'admin'),
    nullif(trim(coalesce(p_notes, '')), ''),
    v_actor,
    timezone('utc', now())
  )
  ON CONFLICT (match_id) DO UPDATE SET
    local_date = EXCLUDED.local_date,
    local_time = EXCLUDED.local_time,
    timezone_name = EXCLUDED.timezone_name,
    starts_at = EXCLUDED.starts_at,
    venue = EXCLUDED.venue,
    source_url = EXCLUDED.source_url,
    correction_source = EXCLUDED.correction_source,
    notes = EXCLUDED.notes,
    applied_by = EXCLUDED.applied_by,
    applied_at = EXCLUDED.applied_at,
    updated_at = timezone('utc', now());

  UPDATE public.matches
  SET match_date = v_starts_at,
      starts_at = v_starts_at,
      venue = coalesce(nullif(trim(coalesce(p_venue, '')), ''), venue),
      source_url = coalesce(nullif(trim(coalesce(p_source_url, '')), ''), source_url),
      last_live_review_required = false,
      notes = concat_ws(
        ' ',
        notes,
        concat(
          'Kickoff override applied: local_date=',
          p_local_date::text,
          ', local_time=',
          p_local_time::text,
          ', timezone=',
          p_timezone,
          '.'
        ),
        nullif(trim(coalesce(p_notes, '')), '')
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_after;

  PERFORM public.sports_bar_write_audit(
    'admin_apply_match_kickoff_override',
    'match',
    p_match_id,
    v_before,
    v_after,
    v_actor
  );

  RETURN jsonb_build_object(
    'status', 'updated',
    'match_id', p_match_id,
    'starts_at_utc', v_starts_at,
    'local_date', p_local_date,
    'local_time', p_local_time,
    'timezone', p_timezone,
    'match', v_after
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_match_kickoff_overrides(
  p_overrides jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_item jsonb;
  v_results jsonb := '[]'::jsonb;
  v_count integer := 0;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF jsonb_typeof(p_overrides) <> 'array' THEN
    RAISE EXCEPTION 'p_overrides must be a JSON array';
  END IF;

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_overrides)
  LOOP
    v_results := v_results || jsonb_build_array(
      public.admin_apply_match_kickoff_override(
        v_item ->> 'match_id',
        (v_item ->> 'local_date')::date,
        (v_item ->> 'local_time')::time,
        v_item ->> 'timezone',
        v_item ->> 'venue',
        v_item ->> 'source_url',
        coalesce(v_item ->> 'correction_source', 'bulk_admin'),
        v_item ->> 'notes'
      )
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('status', 'updated', 'updated_count', v_count, 'results', v_results);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_mark_match_catalog_review_required(
  p_source_name text DEFAULT 'csv_matches_all'::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_count integer;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.matches m
  SET last_live_review_required = true,
      notes = concat_ws(' ', m.notes, 'Catalog quality review required before curation/pool eligibility.'),
      updated_at = timezone('utc', now())
  WHERE EXISTS (
    SELECT 1
    FROM public.match_catalog_quality_issues q
    WHERE q.match_id = m.id
      AND (p_source_name IS NULL OR q.source_name = p_source_name)
  );

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('status', 'marked', 'updated_count', v_count, 'source_name', p_source_name);
END;
$$;

GRANT SELECT ON TABLE public.match_catalog_timezone_rules TO authenticated, service_role;
GRANT SELECT ON TABLE public.match_catalog_time_overrides TO authenticated, service_role;
GRANT SELECT ON TABLE public.match_catalog_quality_issues TO authenticated, service_role;

GRANT INSERT, UPDATE, DELETE ON TABLE public.match_catalog_timezone_rules TO service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.match_catalog_time_overrides TO service_role;

REVOKE ALL ON FUNCTION public.match_catalog_validate_timezone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_catalog_validate_timezone(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.match_catalog_local_kickoff_to_utc(date, time without time zone, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_catalog_local_kickoff_to_utc(date, time without time zone, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.match_catalog_resolve_timezone(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_catalog_resolve_timezone(text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_match_catalog_quality_report(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_match_catalog_quality_report(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_apply_match_kickoff_override(text, date, time without time zone, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_apply_match_kickoff_override(text, date, time without time zone, text, text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_apply_match_kickoff_overrides(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_apply_match_kickoff_overrides(jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_mark_match_catalog_review_required(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_mark_match_catalog_review_required(text) TO authenticated, service_role;
