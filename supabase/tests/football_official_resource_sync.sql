-- Verifies the LiveScore/provider football resource sync contract.

DO $$
DECLARE
  v_missing text[];
  v_stage_def text;
  v_resolve_team_def text;
  v_apply_def text;
  v_status_count integer;
BEGIN
  SELECT array_agg(required_object)
  INTO v_missing
  FROM (
    VALUES
      ('public.football_official_resources'::text),
      ('public.football_resource_sync_runs'::text),
      ('public.football_team_asset_sources'::text),
      ('public.football_official_fixture_staging'::text),
      ('public.football_official_resource_status'::text),
      ('public.football_catalog_slug(text)'::text),
      ('public.football_catalog_validate_url(text)'::text),
      ('public.football_catalog_livescore_image_url(text,text)'::text),
      ('public.football_catalog_resolve_team(text,text,text,text,text,text,text,text,jsonb)'::text),
      ('public.admin_register_football_official_resource(text,text,text,text,text,text,text,text,text,text,text,boolean,jsonb)'::text),
      ('public.admin_start_football_resource_sync(text,jsonb)'::text),
      ('public.admin_finish_football_resource_sync(uuid,text,integer,integer,integer,text,jsonb)'::text),
      ('public.admin_stage_official_fixture_rows(text,jsonb,uuid,text)'::text),
      ('public.admin_apply_official_fixture_staging(uuid,boolean)'::text),
      ('public.admin_apply_official_fixture_staging_batch(text,integer)'::text),
      ('public.get_football_official_resource_status()'::text)
  ) AS required(required_object)
  WHERE to_regclass(required_object) IS NULL
    AND to_regprocedure(required_object) IS NULL;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing football resource sync objects: %', v_missing;
  END IF;

  IF public.football_catalog_validate_url('https://www.livescore.com/en/football/international/world-cup-2026/fixtures/') IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'LiveScore URL should pass provider URL validation';
  END IF;

  IF public.football_catalog_validate_url('https://127.0.0.1/admin') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Private loopback URL should fail provider URL validation';
  END IF;

  IF public.football_catalog_livescore_image_url('enet/6710.png', 'team')
     <> 'https://storage.livescore.com/images/team/high/enet/6710.png' THEN
    RAISE EXCEPTION 'LiveScore team image URL helper returned an unexpected path';
  END IF;

  IF public.football_catalog_normalize_match_status('NS') <> 'scheduled'
     OR public.football_catalog_normalize_match_status('FT') <> 'finished' THEN
    RAISE EXCEPTION 'LiveScore status normalization failed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.football_official_resources
    WHERE id = 'livescore_world_cup_2026'
      AND provider = 'livescore'
      AND provider_competition_id = '734'
      AND competition_id = 'fifa_world_cup'
      AND fetch_mode = 'livescore_public_api'
      AND is_authoritative = true
  ) THEN
    RAISE EXCEPTION 'Seeded LiveScore World Cup 2026 resource is missing or misconfigured';
  END IF;

  v_stage_def := pg_get_functiondef('public.admin_stage_official_fixture_rows(text,jsonb,uuid,text)'::regprocedure);
  IF v_stage_def NOT ILIKE '%football_catalog_resolve_team%'
     OR v_stage_def NOT ILIKE '%football_official_fixture_staging%' THEN
    RAISE EXCEPTION 'Staging RPC must resolve team assets and write fixture staging rows';
  END IF;

  v_resolve_team_def := pg_get_functiondef('public.football_catalog_resolve_team(text,text,text,text,text,text,text,text,jsonb)'::regprocedure);
  IF v_resolve_team_def NOT ILIKE '%football_team_asset_sources%'
     OR v_resolve_team_def NOT ILIKE '%UPDATE public.teams%' THEN
    RAISE EXCEPTION 'Team resolver must update teams and audit provider crest/logo assets';
  END IF;

  v_apply_def := pg_get_functiondef('public.admin_apply_official_fixture_staging(uuid,boolean)'::regprocedure);
  IF v_apply_def NOT ILIKE '%INSERT INTO public.matches%'
     OR v_apply_def ILIKE '%curated_matches%' THEN
    RAISE EXCEPTION 'Apply RPC must update raw matches and must not directly curate/pool-enable fixtures';
  END IF;

  SELECT count(*)
  INTO v_status_count
  FROM public.get_football_official_resource_status()
  WHERE id = 'livescore_world_cup_2026';

  IF v_status_count <> 1 THEN
    RAISE EXCEPTION 'Resource status view/function did not expose the LiveScore resource';
  END IF;
END;
$$;
