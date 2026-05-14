\pset tuples_only on
\pset pager off

\echo 'Verifying match catalog quality tools...'

DO $$
DECLARE
  missing_objects text[];
  v_override_def text;
  v_bulk_def text;
  v_report_rows integer;
  v_missing_time_count bigint;
BEGIN
  SELECT array_agg(required_object ORDER BY required_object)
  INTO missing_objects
  FROM (
    VALUES
      ('public.match_catalog_timezone_rules'::text),
      ('public.match_catalog_time_overrides'::text),
      ('public.match_catalog_quality_issues'::text),
      ('public.match_catalog_validate_timezone(text)'::text),
      ('public.match_catalog_local_kickoff_to_utc(date,time without time zone,text)'::text),
      ('public.match_catalog_resolve_timezone(text,text,text,text)'::text),
      ('public.get_match_catalog_quality_report(text)'::text),
      ('public.admin_apply_match_kickoff_override(text,date,time without time zone,text,text,text,text,text)'::text),
      ('public.admin_apply_match_kickoff_overrides(jsonb)'::text),
      ('public.admin_mark_match_catalog_review_required(text)'::text)
  ) AS expected(required_object)
  WHERE (
    expected.required_object LIKE 'public.%(%'
    AND to_regprocedure(expected.required_object) IS NULL
  ) OR (
    expected.required_object NOT LIKE 'public.%(%'
    AND to_regclass(expected.required_object) IS NULL
  );

  IF missing_objects IS NOT NULL THEN
    RAISE EXCEPTION 'Missing match catalog quality objects: %', array_to_string(missing_objects, ', ');
  END IF;

  IF public.match_catalog_validate_timezone('Europe/Malta') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Europe/Malta must validate as an IANA timezone';
  END IF;

  IF public.match_catalog_validate_timezone('Not/AZone') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Invalid timezones must be rejected';
  END IF;

  IF public.match_catalog_resolve_timezone('comp_mpl', NULL, NULL, 'csv_matches_all') <> 'Europe/Malta' THEN
    RAISE EXCEPTION 'Malta Premier League timezone rule is not resolving';
  END IF;

  IF public.match_catalog_resolve_timezone('fifa_world_cup', 'Estadio Azteca, Mexico City', NULL, 'csv_matches_all') <> 'America/Mexico_City' THEN
    RAISE EXCEPTION 'World Cup venue timezone rule is not resolving';
  END IF;

  IF public.match_catalog_local_kickoff_to_utc('2026-06-11'::date, '20:00'::time, 'Europe/Malta')
     <> '2026-06-11 18:00:00+00'::timestamptz THEN
    RAISE EXCEPTION 'Local kickoff to UTC conversion is incorrect';
  END IF;

  v_override_def := pg_get_functiondef('public.admin_apply_match_kickoff_override(text,date,time without time zone,text,text,text,text,text)'::regprocedure);
  IF v_override_def NOT ILIKE '%current_user_has_admin_role%'
     OR v_override_def NOT ILIKE '%service_role%'
     OR v_override_def NOT ILIKE '%match_catalog_local_kickoff_to_utc%'
     OR v_override_def NOT ILIKE '%sports_bar_write_audit%'
     OR v_override_def NOT ILIKE '%last_live_review_required = false%' THEN
    RAISE EXCEPTION 'admin_apply_match_kickoff_override must validate, audit, and clear review flag';
  END IF;

  v_bulk_def := pg_get_functiondef('public.admin_apply_match_kickoff_overrides(jsonb)'::regprocedure);
  IF v_bulk_def NOT ILIKE '%jsonb_array_elements%'
     OR v_bulk_def NOT ILIKE '%admin_apply_match_kickoff_override%' THEN
    RAISE EXCEPTION 'bulk kickoff override function must iterate JSON overrides through the single override function';
  END IF;

  SELECT count(*)
  INTO v_report_rows
  FROM public.get_match_catalog_quality_report('csv_matches_all');

  IF v_report_rows = 0 THEN
    RAISE EXCEPTION 'Quality report must return issues for the imported Matches ALL feed';
  END IF;

  SELECT affected_count
  INTO v_missing_time_count
  FROM public.get_match_catalog_quality_report('csv_matches_all')
  WHERE issue_type = 'missing_verified_kickoff_time'
  LIMIT 1;

  IF coalesce(v_missing_time_count, 0) < 600 THEN
    RAISE EXCEPTION 'Expected imported date-only fixtures to be flagged for kickoff review, found %', coalesce(v_missing_time_count, 0);
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.match_catalog_quality_issues
    WHERE issue_type = 'world_cup_2026_date_out_of_range'
  ) THEN
    RAISE EXCEPTION 'World Cup 2026 date corrections should keep fixtures inside the tournament window';
  END IF;
END;
$$;

\echo 'Match catalog quality tools verified'
