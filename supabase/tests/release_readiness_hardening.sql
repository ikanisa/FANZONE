\pset tuples_only on
\pset pager off

\echo 'Verifying release-readiness auth hardening and privacy wiring...'

DO $$
BEGIN
  IF to_regprocedure('public.auth_user_is_anonymous(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing helper RPC: public.auth_user_is_anonymous(uuid)';
  END IF;

  IF to_regprocedure('public.current_session_is_anonymous()') IS NULL THEN
    RAISE EXCEPTION 'Missing helper RPC: public.current_session_is_anonymous()';
  END IF;

  IF to_regprocedure('public.assert_verified_account_required(text)') IS NULL THEN
    RAISE EXCEPTION 'Missing helper RPC: public.assert_verified_account_required(text)';
  END IF;

  IF to_regprocedure('public.get_public_leaderboard_rank(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing helper RPC: public.get_public_leaderboard_rank(uuid)';
  END IF;
END;
$$;

DO $$
DECLARE
  submit_definition text;
  transfer_definition text;
  foundation_definition text;
  leaderboard_view text;
BEGIN
  submit_definition := pg_get_functiondef(
    'public.submit_user_prediction(text,text,boolean,boolean,integer,integer)'::regprocedure
  );
  transfer_definition := pg_get_functiondef(
    'public.transfer_fet_by_fan_id(text,bigint)'::regprocedure
  );
  foundation_definition := pg_get_functiondef(
    'public.ensure_user_foundation(uuid)'::regprocedure
  );
  leaderboard_view := pg_get_viewdef('public.prediction_leaderboard'::regclass, true);

  IF submit_definition NOT ILIKE '%assert_verified_account_required%' THEN
    RAISE EXCEPTION 'submit_user_prediction is missing the verified-account guard';
  END IF;

  IF transfer_definition NOT ILIKE '%assert_verified_account_required%' THEN
    RAISE EXCEPTION 'transfer_fet_by_fan_id is missing the verified-account guard';
  END IF;

  IF foundation_definition NOT ILIKE '%auth_user_is_anonymous%' THEN
    RAISE EXCEPTION 'ensure_user_foundation no longer checks anonymous auth state';
  END IF;

  IF leaderboard_view NOT ILIKE '%show_name_on_leaderboards%' THEN
    RAISE EXCEPTION 'prediction_leaderboard no longer respects show_name_on_leaderboards';
  END IF;
END;
$$;

\echo 'Release-readiness hardening verification passed'
