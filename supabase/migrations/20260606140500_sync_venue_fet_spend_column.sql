-- Keep the venue rewards settings RPC aligned with the canonical venue column
-- checked by spend_fet_on_order.

CREATE OR REPLACE FUNCTION public.update_venue_fet_reward_config(
  p_venue_id uuid,
  p_reward_percent numeric DEFAULT NULL::numeric,
  p_reward_trigger text DEFAULT NULL::text,
  p_accepts_fet_spend boolean DEFAULT NULL::boolean,
  p_redemption_fet_per_currency numeric DEFAULT NULL::numeric,
  p_max_fet_spend_per_order bigint DEFAULT NULL::bigint,
  p_reward_campaign_active boolean DEFAULT NULL::boolean
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_before jsonb;
  v_after jsonb;
  v_patch jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT (
    public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
    OR public.is_admin_manager(v_actor)
  ) THEN
    RAISE EXCEPTION 'Only venue owners, managers, or admins can update FET rewards';
  END IF;

  IF p_reward_percent IS NOT NULL AND (p_reward_percent < 0 OR p_reward_percent > 100) THEN
    RAISE EXCEPTION 'Reward percentage must be between 0 and 100';
  END IF;

  IF p_reward_trigger IS NOT NULL AND p_reward_trigger NOT IN ('paid', 'served') THEN
    RAISE EXCEPTION 'Reward trigger must be paid or served';
  END IF;

  IF p_redemption_fet_per_currency IS NOT NULL AND p_redemption_fet_per_currency <= 0 THEN
    RAISE EXCEPTION 'Redemption rate must be greater than zero';
  END IF;

  IF p_max_fet_spend_per_order IS NOT NULL AND p_max_fet_spend_per_order < 0 THEN
    RAISE EXCEPTION 'Maximum FET spend per order cannot be negative';
  END IF;

  SELECT jsonb_build_object(
    'venue_id', id,
    'accepts_fet_spend', accepts_fet_spend,
    'features_json', coalesce(features_json, '{}'::jsonb)
  )
  INTO v_before
  FROM public.venues
  WHERE id = p_venue_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  v_patch := jsonb_strip_nulls(jsonb_build_object(
    'fet_reward_percent', p_reward_percent,
    'fet_reward_trigger', p_reward_trigger,
    'accepts_fet_spend', p_accepts_fet_spend,
    'fet_redemption_fet_per_currency', p_redemption_fet_per_currency,
    'max_fet_spend_per_order', p_max_fet_spend_per_order,
    'reward_campaign_active', p_reward_campaign_active
  ));

  UPDATE public.venues
  SET features_json = coalesce(features_json, '{}'::jsonb) || v_patch,
      accepts_fet_spend = coalesce(p_accepts_fet_spend, accepts_fet_spend),
      updated_at = timezone('utc', now())
  WHERE id = p_venue_id
  RETURNING jsonb_build_object(
    'venue_id', id,
    'accepts_fet_spend', accepts_fet_spend,
    'features_json', coalesce(features_json, '{}'::jsonb)
  )
  INTO v_after;

  PERFORM public.sports_bar_write_audit(
    'update_venue_fet_reward_config',
    'venue',
    p_venue_id::text,
    v_before,
    v_after
  );

  RETURN public.get_venue_fet_reward_config(p_venue_id);
END;
$$;
