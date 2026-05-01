-- Remove anonymous execution from settlement/admin/social-card functions that
-- existed in earlier remote projects with overly broad EXECUTE grants.

DO $$
DECLARE
  v_signature text;
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.settle_match_pool(uuid)',
    'public.settle_finished_match_pools(integer)',
    'public.admin_run_pool_settlement(integer)',
    'public.set_match_pool_share_links()',
    'public.set_match_pool_social_card_url(uuid,text)',
    'public.set_match_pool_social_card_url(uuid,text,jsonb)'
  ] LOOP
    IF to_regprocedure(v_signature) IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_signature);
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', v_signature);
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_run_pool_settlement(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_match_pool_share_links() TO service_role;
GRANT EXECUTE ON FUNCTION public.set_match_pool_social_card_url(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_match_pool_social_card_url(uuid, text, jsonb) TO authenticated, service_role;
