\pset tuples_only on
\pset pager off

\echo 'Verifying curated sports-bar match platform...'

DO $$
DECLARE
  missing_objects text[];
  v_feed_def text;
  v_score_def text;
  v_settle_def text;
BEGIN
  SELECT array_agg(required_object ORDER BY required_object)
  INTO missing_objects
  FROM (
    VALUES
      ('public.curated_active_matches'::text),
      ('public.fixture_sources'::text),
      ('public.get_curated_matches(text,uuid,timestamp with time zone,timestamp with time zone,text,text,text,integer)'::text),
      ('public.admin_curate_match_control(text,text,uuid,integer,text,jsonb,timestamp with time zone,timestamp with time zone,boolean)'::text),
      ('public.admin_set_curated_match_active(uuid,boolean)'::text),
      ('public.update_match_live_score(text,integer,integer,text,text)'::text)
  ) AS expected(required_object)
  WHERE (
    expected.required_object LIKE 'public.%(%'
    AND to_regprocedure(expected.required_object) IS NULL
  ) OR (
    expected.required_object NOT LIKE 'public.%(%'
    AND to_regclass(expected.required_object) IS NULL
  );

  IF missing_objects IS NOT NULL THEN
    RAISE EXCEPTION 'Missing curated match platform objects: %', array_to_string(missing_objects, ', ');
  END IF;

  v_feed_def := pg_get_viewdef('public.curated_active_matches'::regclass, true);
  IF v_feed_def NOT ILIKE '%curated_matches%'
     OR v_feed_def NOT ILIKE '%cm.is_active = true%'
     OR v_feed_def NOT ILIKE '%hidden%'
     OR v_feed_def NOT ILIKE '%final%' THEN
    RAISE EXCEPTION 'curated_active_matches must expose only active curated matches with canonical final status';
  END IF;

  v_score_def := pg_get_functiondef('public.update_match_live_score(text,integer,integer,text,text)'::regprocedure);
  IF v_score_def NOT ILIKE '%settle_finished_match_pools%'
     OR v_score_def NOT ILIKE '%reverse_or_refund_pool_if_match_cancelled%'
     OR v_score_def NOT ILIKE '%final result requires home and away scores%'
     OR v_score_def NOT ILIKE '%sports_bar_write_audit%' THEN
    RAISE EXCEPTION 'update_match_live_score must audit, settle finals, and refund cancelled/postponed matches';
  END IF;

  v_settle_def := pg_get_functiondef('public.settle_finished_match_pools(integer)'::regprocedure);
  IF v_settle_def NOT ILIKE '%open%'
     OR v_settle_def NOT ILIKE '%locked%'
     OR v_settle_def NOT ILIKE '%live%'
     OR v_settle_def NOT ILIKE '%settling%'
     OR v_settle_def NOT ILIKE '%idempotency_key%' THEN
    RAISE EXCEPTION 'settle_finished_match_pools must cover all active pool states and preserve idempotency logging';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.competitions
    WHERE id = 'fifa_world_cup'
      AND is_active = true
      AND coalesce(type, competition_type) = 'world_cup'
  ) THEN
    RAISE EXCEPTION 'FIFA World Cup approved competition seed is missing';
  END IF;
END;
$$;

\echo 'Curated sports-bar match platform verified'
