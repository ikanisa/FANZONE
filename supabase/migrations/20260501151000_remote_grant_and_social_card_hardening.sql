-- Final remote grant hardening for projects that previously exposed broad
-- client table privileges, plus social-card RPC compatibility for the Edge
-- Function that writes generated card URLs.

ALTER TABLE public.app_config_remote
  ADD COLUMN IF NOT EXISTS description text;

DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'public.fet_wallets',
    'public.fet_wallet_transactions',
    'public.match_pool_settlements',
    'public.pool_operation_audit_logs',
    'public.payment_events',
    'public.orders'
  ] LOOP
    IF to_regclass(v_table) IS NOT NULL THEN
      EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE %s FROM anon', v_table);
      EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE %s FROM PUBLIC', v_table);
      EXECUTE format(
        'REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE %s FROM authenticated',
        v_table
      );
    END IF;
  END LOOP;

  FOREACH v_table IN ARRAY ARRAY[
    'public.platform_features',
    'public.platform_feature_rules',
    'public.platform_feature_channels',
    'public.platform_content_blocks',
    'public.curated_matches',
    'public.match_pool_settlements',
    'public.pool_operation_audit_logs'
  ] LOOP
    IF to_regclass(v_table) IS NOT NULL THEN
      EXECUTE format(
        'REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE %s FROM authenticated',
        v_table
      );
    END IF;
  END LOOP;
END;
$$;

GRANT SELECT ON TABLE public.fet_wallets TO authenticated, service_role;
GRANT SELECT ON TABLE public.fet_wallet_transactions TO authenticated, service_role;
GRANT SELECT ON TABLE public.orders TO authenticated, service_role;
GRANT SELECT ON TABLE public.match_pool_settlements TO authenticated, service_role;
GRANT SELECT ON TABLE public.payment_events TO authenticated, service_role;
GRANT SELECT ON TABLE public.pool_operation_audit_logs TO authenticated, service_role;

DROP FUNCTION IF EXISTS public.set_match_pool_social_card_url(uuid, text, jsonb);
DROP FUNCTION IF EXISTS public.set_match_pool_social_card_url(uuid, text);

CREATE FUNCTION public.set_match_pool_social_card_url(
  p_pool_id uuid,
  p_social_card_url text,
  p_metadata jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_url text := nullif(trim(coalesce(p_social_card_url, '')), '');
  v_is_service_role boolean :=
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role';
BEGIN
  SELECT *
  INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_url IS NULL OR (v_url !~ '^https://.+$' AND v_url !~ '^/.+') THEN
    RAISE EXCEPTION 'Social card URL must be an HTTPS URL or a site-relative path';
  END IF;

  IF NOT (
    v_is_service_role
    OR public.is_admin_manager(v_user_id)
    OR (
      v_pool.venue_id IS NOT NULL
      AND public.venue_user_has_role(v_pool.venue_id)
    )
  ) THEN
    RAISE EXCEPTION 'Only admins or venue operators can set social card URLs';
  END IF;

  UPDATE public.match_pools
  SET social_card_url = v_url,
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'social_card',
        coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
          'updated_by', v_user_id,
          'updated_at', timezone('utc', now())
        )
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  PERFORM public.sports_bar_write_audit(
    'set_match_pool_social_card_url',
    'pool',
    p_pool_id::text,
    to_jsonb(v_pool),
    jsonb_build_object('social_card_url', v_url, 'metadata', coalesce(p_metadata, '{}'::jsonb)),
    v_user_id
  );

  RETURN jsonb_build_object(
    'status', 'updated',
    'pool_id', p_pool_id,
    'social_card_url', v_url
  );
END;
$$;

CREATE FUNCTION public.set_match_pool_social_card_url(
  p_pool_id uuid,
  p_social_card_url text
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.set_match_pool_social_card_url(p_pool_id, p_social_card_url, '{}'::jsonb);
$$;

REVOKE ALL ON FUNCTION public.set_match_pool_social_card_url(uuid, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_match_pool_social_card_url(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_match_pool_social_card_url(uuid, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_match_pool_social_card_url(uuid, text) TO authenticated, service_role;
