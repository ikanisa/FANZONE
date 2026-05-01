-- Venue operational console controls.
-- Adds audited manual payment status management, expanded FET reward controls,
-- and compact venue insights for the sports-bar staff console.

CREATE OR REPLACE FUNCTION public.get_venue_fet_reward_config(p_venue_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_features jsonb;
  v_default_percent numeric := greatest(public.app_config_numeric('order_reward_percent_default', 10), 0);
  v_default_trigger text := 'paid';
  v_trigger_value jsonb;
BEGIN
  SELECT value
  INTO v_trigger_value
  FROM public.app_config_remote
  WHERE key = 'order_reward_trigger_default'
  LIMIT 1;

  v_default_trigger := coalesce(nullif(trim(both '"' from coalesce(v_trigger_value::text, '')), ''), 'paid');

  SELECT coalesce(features_json, '{}'::jsonb)
  INTO v_features
  FROM public.venues
  WHERE id = p_venue_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  RETURN jsonb_build_object(
    'venue_id', p_venue_id,
    'reward_percent', coalesce(nullif(v_features ->> 'fet_reward_percent', '')::numeric, v_default_percent),
    'reward_trigger', CASE
      WHEN coalesce(v_features ->> 'fet_reward_trigger', v_default_trigger) IN ('paid', 'served')
        THEN coalesce(v_features ->> 'fet_reward_trigger', v_default_trigger)
      ELSE 'paid'
    END,
    'accepts_fet_spend', coalesce((v_features ->> 'accepts_fet_spend')::boolean, false),
    'redemption_fet_per_currency', nullif(v_features ->> 'fet_redemption_fet_per_currency', '')::numeric,
    'max_fet_spend_per_order', nullif(v_features ->> 'max_fet_spend_per_order', '')::bigint,
    'reward_campaign_active', coalesce((v_features ->> 'reward_campaign_active')::boolean, true),
    'platform_default_reward_percent', v_default_percent,
    'platform_default_reward_trigger', v_default_trigger
  );
END;
$$;

DROP FUNCTION IF EXISTS public.update_venue_fet_reward_config(
  uuid,
  numeric,
  text,
  boolean,
  numeric
);

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

  SELECT jsonb_build_object('venue_id', id, 'features_json', coalesce(features_json, '{}'::jsonb))
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
      updated_at = timezone('utc', now())
  WHERE id = p_venue_id
  RETURNING jsonb_build_object('venue_id', id, 'features_json', coalesce(features_json, '{}'::jsonb))
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

CREATE OR REPLACE FUNCTION public.venue_update_order_payment_status(
  p_order_id uuid,
  p_payment_status text,
  p_payment_method text DEFAULT NULL::text,
  p_actor_note text DEFAULT NULL::text
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
  v_next_status text := lower(trim(coalesce(p_payment_status, '')));
  v_method text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_next_status NOT IN ('unpaid', 'paid', 'partially_paid', 'refunded', 'disputed') THEN
    RAISE EXCEPTION 'Unsupported payment status';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT public.venue_user_has_role(v_order.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue operators can update this order payment';
  END IF;

  IF v_order.status = 'cancelled' AND v_next_status = 'paid' THEN
    RAISE EXCEPTION 'Cannot mark a cancelled order paid';
  END IF;

  v_method := coalesce(nullif(lower(trim(p_payment_method)), ''), v_order.payment_method::text);

  IF v_method NOT IN ('cash', 'momo', 'revolut') THEN
    RAISE EXCEPTION 'Unsupported payment method';
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
  SET payment_status = v_next_status::public.venue_payment_status,
      payment_method = v_method::public.payment_method,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id
  RETURNING to_jsonb(orders.*) INTO v_after;

  INSERT INTO public.payment_events (
    order_id,
    provider,
    status,
    request_payload,
    response_payload
  )
  VALUES (
    p_order_id,
    v_method::public.payment_method,
    v_next_status::public.venue_payment_status,
    jsonb_build_object(
      'marked_by', auth.uid(),
      'note', p_actor_note,
      'before_status', v_order.payment_status,
      'after_status', v_next_status,
      'amount', v_order.total_amount
    ),
    jsonb_build_object('source', 'venue_update_order_payment_status', 'provider_api_used', false)
  );

  PERFORM public.sports_bar_write_audit(
    'venue_update_order_payment_status',
    'order',
    p_order_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'payment_status', v_next_status,
    'payment_method', v_method
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_venue_operational_insights(p_venue_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_today timestamptz := date_trunc('day', timezone('utc', now()));
  v_today_orders bigint := 0;
  v_fet_issued bigint := 0;
  v_fet_redeemed bigint := 0;
  v_pending_payment_count bigint := 0;
  v_active_pools bigint := 0;
  v_most_active_match jsonb := NULL;
  v_top_menu_items jsonb := '[]'::jsonb;
BEGIN
  IF NOT (
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role'
    OR public.venue_user_has_role(p_venue_id)
    OR public.is_admin_manager(v_actor)
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT
    count(*) FILTER (WHERE status <> 'cancelled')::bigint,
    coalesce(sum(fet_earned) FILTER (WHERE status <> 'cancelled'), 0)::bigint,
    coalesce(sum(coalesce(payment_fet_amount, fet_spent)) FILTER (WHERE status <> 'cancelled'), 0)::bigint,
    count(*) FILTER (
      WHERE status <> 'cancelled'
        AND payment_status IN ('unpaid', 'pending', 'partially_paid', 'disputed')
    )::bigint
  INTO v_today_orders, v_fet_issued, v_fet_redeemed, v_pending_payment_count
  FROM public.orders
  WHERE venue_id = p_venue_id
    AND created_at >= v_today;

  SELECT count(*)::bigint
  INTO v_active_pools
  FROM public.match_pools
  WHERE venue_id = p_venue_id
    AND status IN ('open', 'locked', 'live');

  SELECT jsonb_build_object(
    'pool_id', p.id,
    'match_id', p.match_id,
    'title', p.title,
    'competition_name', m.competition_name,
    'match_label', trim(both ' ' from concat(coalesce(m.home_team, 'Home'), ' vs ', coalesce(m.away_team, 'Away'))),
    'status', p.status,
    'total_members', p.total_members,
    'total_staked_fet', p.total_staked_fet
  )
  INTO v_most_active_match
  FROM public.match_pools p
  LEFT JOIN public.app_matches m ON m.id = p.match_id
  WHERE p.venue_id = p_venue_id
    AND p.status IN ('open', 'locked', 'live')
  ORDER BY p.total_members DESC, p.total_staked_fet DESC, p.created_at DESC
  LIMIT 1;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'name', item_name,
      'quantity', total_quantity,
      'revenue', total_revenue
    )
    ORDER BY total_quantity DESC, total_revenue DESC
  ), '[]'::jsonb)
  INTO v_top_menu_items
  FROM (
    SELECT
      oi.item_name_snapshot AS item_name,
      sum(oi.quantity)::bigint AS total_quantity,
      coalesce(sum(oi.line_total), 0)::numeric(12,2) AS total_revenue
    FROM public.order_items oi
    JOIN public.orders o ON o.id = oi.order_id
    WHERE o.venue_id = p_venue_id
      AND o.created_at >= v_today
      AND o.status <> 'cancelled'
    GROUP BY oi.item_name_snapshot
    ORDER BY sum(oi.quantity) DESC, coalesce(sum(oi.line_total), 0) DESC
    LIMIT 5
  ) ranked_items;

  RETURN jsonb_build_object(
    'today_orders', coalesce(v_today_orders, 0),
    'fet_issued', coalesce(v_fet_issued, 0),
    'fet_redeemed', coalesce(v_fet_redeemed, 0),
    'active_pools', coalesce(v_active_pools, 0),
    'most_active_match', v_most_active_match,
    'top_menu_items', coalesce(v_top_menu_items, '[]'::jsonb),
    'pending_payment_count', coalesce(v_pending_payment_count, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_venue_fet_reward_config(
  uuid,
  numeric,
  text,
  boolean,
  numeric,
  bigint,
  boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_venue_fet_reward_config(
  uuid,
  numeric,
  text,
  boolean,
  numeric,
  bigint,
  boolean
) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.venue_update_order_payment_status(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_update_order_payment_status(uuid, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_venue_operational_insights(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_venue_operational_insights(uuid) TO authenticated, service_role;
