\pset tuples_only on
\pset pager off

\echo 'Auditing RLS and client grants...'

DO $$
DECLARE
  exposed text[];
BEGIN
  SELECT array_agg(table_name ORDER BY table_name)
  INTO exposed
  FROM (
    VALUES
      ('fet_wallets'),
      ('fet_wallet_transactions'),
      ('venue_fet_wallets'),
      ('venue_fet_wallet_transactions'),
      ('game_templates'),
      ('game_questions'),
      ('game_sessions'),
      ('game_session_questions'),
      ('game_teams'),
      ('game_team_members'),
      ('game_answers'),
      ('music_bingo_cards'),
      ('music_bingo_claims'),
      ('venue_screen_states'),
      ('match_pool_settlements'),
      ('pool_operation_audit_logs'),
      ('payment_events'),
      ('orders')
  ) AS sensitive(table_name)
  WHERE has_table_privilege('anon', format('public.%I', sensitive.table_name), 'INSERT')
     OR has_table_privilege('anon', format('public.%I', sensitive.table_name), 'UPDATE')
     OR has_table_privilege('anon', format('public.%I', sensitive.table_name), 'DELETE');

  IF exposed IS NOT NULL THEN
    RAISE EXCEPTION 'Anonymous role has write access to sensitive tables: %', array_to_string(exposed, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  exposed text[];
BEGIN
  SELECT array_agg(table_name ORDER BY table_name)
  INTO exposed
  FROM (
    VALUES
      ('platform_features'),
      ('platform_feature_rules'),
      ('platform_feature_channels'),
      ('platform_content_blocks'),
      ('curated_matches'),
      ('venue_fet_wallets'),
      ('venue_fet_wallet_transactions'),
      ('game_templates'),
      ('game_questions'),
      ('game_sessions'),
      ('game_session_questions'),
      ('game_teams'),
      ('game_team_members'),
      ('game_answers'),
      ('music_bingo_cards'),
      ('music_bingo_claims'),
      ('venue_screen_states'),
      ('match_pool_settlements'),
      ('pool_operation_audit_logs')
  ) AS sensitive(table_name)
  WHERE has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'INSERT')
     OR has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'UPDATE')
     OR has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'DELETE');

  IF exposed IS NOT NULL THEN
    RAISE EXCEPTION 'Authenticated role has direct write access to managed tables: %', array_to_string(exposed, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(signature ORDER BY signature)
  INTO unsafe_functions
  FROM (
    VALUES
      ('public.settle_match_pool(uuid)'),
      ('public.settle_finished_match_pools(integer)'),
      ('public.admin_run_pool_settlement(integer)'),
      ('public.lock_pool_for_match_start(text)'),
      ('public.credit_fet_for_order(uuid,text)'),
      ('public.credit_order_fet(uuid,bigint)'),
      ('public.venue_wallet_post_transaction(uuid,text,text,bigint,text,text,text,text,text,jsonb,uuid,uuid,text,uuid)'),
      ('public.settle_match_pool(uuid)'),
      ('public.user_has_qualifying_order(uuid,uuid,timestamp with time zone)'),
      ('public.create_pool(text,text,uuid,uuid,text,bigint,bigint,bigint,jsonb,boolean)'),
      ('public.create_match_pool(text,public.match_pool_scope,text,uuid,text,bigint,bigint,bigint,boolean)'),
      ('public.create_venue_official_match_pool(uuid,text,text,bigint,bigint,bigint,bigint,bigint)'),
      ('public.join_match_pool(uuid,uuid,bigint,text)'),
      ('public.venue_settle_match_pool(uuid)'),
      ('public.create_game_session(uuid,text,timestamp with time zone,bigint)'),
      ('public.create_game_team(uuid,text)'),
      ('public.join_game_team(uuid)'),
      ('public.start_game_session(uuid)'),
      ('public.submit_game_answer(uuid,uuid,uuid,text)'),
      ('public.submit_music_bingo_claim(uuid,jsonb)'),
      ('public.verify_music_bingo_claim(uuid,boolean,bigint,text)'),
      ('public.set_venue_screen_state(uuid,text,uuid,uuid,jsonb)'),
      ('public.set_match_pool_share_links()'),
      ('public.set_match_pool_social_card_url(uuid,text)'),
      ('public.wallet_post_transaction(uuid,text,text,bigint,text,text,text,text,text,jsonb,uuid,text,uuid,uuid,uuid,uuid,text,uuid)')
  ) AS required(signature)
  WHERE has_function_privilege('anon', required.signature, 'EXECUTE');

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Anonymous role can execute restricted functions: %', array_to_string(unsafe_functions, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(signature ORDER BY signature)
  INTO unsafe_functions
  FROM (
    VALUES
      ('public.find_auth_user_by_phone(text)'),
      ('public.resolve_auth_user_phone(uuid)'),
      ('public.credit_welcome_fet(uuid,text)'),
      ('public.reconcile_fet_wallet(uuid)')
  ) AS restricted(signature)
  WHERE has_function_privilege('anon', restricted.signature, 'EXECUTE');

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Anonymous role can execute auth/wallet helper functions: %', array_to_string(unsafe_functions, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(signature ORDER BY signature)
  INTO unsafe_functions
  FROM (
    VALUES
      ('public.find_auth_user_by_phone(text)'),
      ('public.resolve_auth_user_phone(uuid)'),
      ('public.credit_welcome_fet(uuid,text)'),
      ('public.reconcile_fet_wallet(uuid)')
  ) AS restricted(signature)
  WHERE has_function_privilege('authenticated', restricted.signature, 'EXECUTE');

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Authenticated role can execute backend-only auth/wallet helper functions: %', array_to_string(unsafe_functions, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_app_default_acls text[];
BEGIN
  SELECT array_agg(
    format(
      '%s grants %s on future %s to %s',
      d.defaclrole::regrole,
      acl.privilege_type,
      d.defaclobjtype,
      acl.grantee::regrole
    )
    ORDER BY d.defaclobjtype, acl.grantee::regrole::text, acl.privilege_type
  )
  INTO unsafe_app_default_acls
  FROM pg_default_acl AS d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) AS acl
  WHERE d.defaclnamespace = 'public'::regnamespace
    -- Supabase owns immutable platform defaults for supabase_admin. App
    -- migrations run as postgres, so fail only on defaults we can control.
    AND d.defaclrole <> 'supabase_admin'::regrole
    AND acl.grantee IN ('anon'::regrole, 'authenticated'::regrole);

  IF unsafe_app_default_acls IS NOT NULL THEN
    RAISE EXCEPTION 'App-owned default privileges grant future public objects to client roles: %', array_to_string(unsafe_app_default_acls, '; ');
  END IF;
END;
$$;

DO $$
DECLARE
  platform_default_acls text[];
BEGIN
  SELECT array_agg(
    format(
      '%s grants %s on future %s to %s',
      d.defaclrole::regrole,
      acl.privilege_type,
      d.defaclobjtype,
      acl.grantee::regrole
    )
    ORDER BY d.defaclobjtype, acl.grantee::regrole::text, acl.privilege_type
  )
  INTO platform_default_acls
  FROM pg_default_acl AS d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) AS acl
  WHERE d.defaclnamespace = 'public'::regnamespace
    AND d.defaclrole = 'supabase_admin'::regrole
    AND acl.grantee IN ('anon'::regrole, 'authenticated'::regrole);

  IF platform_default_acls IS NOT NULL THEN
    RAISE NOTICE 'Supabase-managed default privileges observed; continue enforcing explicit app grants/RLS on created objects: %', array_to_string(platform_default_acls, '; ');
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT has_function_privilege('anon', 'public.get_game_session_question(uuid,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous TV role must be able to execute the prompt/options-only live question RPC';
  END IF;

  IF pg_get_functiondef('public.get_game_session_question(uuid,integer)'::regprocedure) ILIKE '%correct_answer%' THEN
    RAISE EXCEPTION 'TV question RPC must not expose correct answers';
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(signature ORDER BY signature)
  INTO unsafe_functions
  FROM (
    VALUES
      ('public.wallet_post_transaction(uuid,text,text,bigint,text,text,text,text,text,jsonb,uuid,text,uuid,uuid,uuid,uuid,text,uuid)'),
      ('public.venue_wallet_post_transaction(uuid,text,text,bigint,text,text,text,text,text,jsonb,uuid,uuid,text,uuid)'),
      ('public.settle_match_pool(uuid)'),
      ('public.user_has_qualifying_order(uuid,uuid,timestamp with time zone)'),
      ('public.settle_finished_match_pools(integer)'),
      ('public.lock_pool_for_match_start(text)'),
      ('public.credit_fet_for_order(uuid,text)'),
      ('public.credit_order_fet(uuid,bigint)')
  ) AS required(signature)
  WHERE has_function_privilege('authenticated', required.signature, 'EXECUTE');

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Authenticated role can execute backend-only functions: %', array_to_string(unsafe_functions, ', ');
  END IF;
END;
$$;

\echo 'RLS and client grants verified'
