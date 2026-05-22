-- Hospitality Core Phase 2: canonical order lifecycle and audit trail.

ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'draft';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'submitted';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'accepted';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'ready';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'refunded';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'disputed';

CREATE TABLE IF NOT EXISTS public.order_state_events (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  previous_status text,
  next_status text NOT NULL,
  reason text,
  source text NOT NULL DEFAULT 'venue_transition_order_status',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_state_events_previous_status_check
    CHECK (previous_status IS NULL OR previous_status <> ''),
  CONSTRAINT order_state_events_next_status_check
    CHECK (next_status <> ''),
  CONSTRAINT order_state_events_metadata_object_check
    CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS order_state_events_order_created_idx
ON public.order_state_events (order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS order_state_events_venue_created_idx
ON public.order_state_events (venue_id, created_at DESC);

ALTER TABLE public.order_state_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS order_state_events_select_scoped ON public.order_state_events;
CREATE POLICY order_state_events_select_scoped
ON public.order_state_events
FOR SELECT
TO authenticated
USING (
  public.is_active_admin_operator(auth.uid())
  OR public.venue_user_has_role(venue_id)
  OR EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_state_events.order_id
      AND o.user_id = auth.uid()
  )
);

GRANT SELECT ON public.order_state_events TO authenticated;
GRANT ALL ON public.order_state_events TO service_role;

CREATE OR REPLACE FUNCTION public.venue_transition_order_status(
  p_order_id uuid,
  p_next_status text,
  p_reason text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
  v_previous_status text;
  v_next_status text := lower(trim(coalesce(p_next_status, '')));
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_valid boolean := false;
  v_event_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF jsonb_typeof(v_metadata) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Transition metadata must be a JSON object';
  END IF;

  IF v_next_status NOT IN (
    'draft',
    'submitted',
    'accepted',
    'preparing',
    'ready',
    'served',
    'completed',
    'cancelled',
    'refunded',
    'disputed'
  ) THEN
    RAISE EXCEPTION 'Unsupported order status: %', v_next_status;
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT (
    public.is_active_admin_operator(auth.uid())
    OR public.venue_user_has_role(
      v_order.venue_id,
      ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]
    )
  ) THEN
    RAISE EXCEPTION 'Only venue operators can transition this order';
  END IF;

  v_previous_status := v_order.status::text;

  v_valid := CASE v_previous_status
    WHEN 'draft' THEN v_next_status IN ('submitted')
    WHEN 'placed' THEN v_next_status IN ('accepted', 'cancelled', 'disputed')
    WHEN 'received' THEN v_next_status IN ('accepted', 'cancelled', 'disputed')
    WHEN 'submitted' THEN v_next_status IN ('accepted', 'cancelled', 'disputed')
    WHEN 'accepted' THEN v_next_status IN ('preparing', 'ready', 'cancelled', 'disputed')
    WHEN 'preparing' THEN v_next_status IN ('ready', 'served', 'cancelled', 'disputed')
    WHEN 'ready' THEN v_next_status IN ('served', 'cancelled', 'disputed')
    WHEN 'served' THEN v_next_status IN ('completed', 'disputed')
    WHEN 'disputed' THEN v_next_status IN ('refunded', 'cancelled', 'completed')
    ELSE false
  END;

  IF NOT v_valid THEN
    RAISE EXCEPTION 'Invalid order status transition: % -> %',
      v_previous_status,
      v_next_status;
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
  SET status = v_next_status::public.order_status,
      accepted_at = CASE
        WHEN v_next_status = 'accepted' AND accepted_at IS NULL
          THEN timezone('utc', now())
        ELSE accepted_at
      END,
      served_at = CASE
        WHEN v_next_status = 'served' AND served_at IS NULL
          THEN timezone('utc', now())
        ELSE served_at
      END,
      status_changed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = p_order_id
  RETURNING to_jsonb(orders.*) INTO v_after;

  INSERT INTO public.order_state_events (
    order_id,
    venue_id,
    actor_user_id,
    previous_status,
    next_status,
    reason,
    source,
    metadata
  )
  VALUES (
    p_order_id,
    v_order.venue_id,
    auth.uid(),
    v_previous_status,
    v_next_status,
    v_reason,
    coalesce(v_metadata ->> 'source', 'venue_transition_order_status'),
    v_metadata - 'source'
  )
  RETURNING id INTO v_event_id;

  PERFORM public.sports_bar_write_audit(
    'venue_transition_order_status',
    'order',
    p_order_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'venue_id', v_order.venue_id,
    'previous_status', v_previous_status,
    'next_status', v_next_status,
    'event_id', v_event_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.venue_transition_order_status(uuid, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_transition_order_status(uuid, text, text, jsonb)
TO authenticated, service_role;

COMMENT ON TABLE public.order_state_events
IS 'Append-only audited order lifecycle events. Customers read their own events; venue operators and platform admins read venue events.';

COMMENT ON FUNCTION public.venue_transition_order_status(uuid, text, text, jsonb)
IS 'Canonical venue-scoped order status transition RPC. Preserves legacy placed/received reads while enforcing target hospitality lifecycle transitions.';
