-- Additive daily-close support for manual/off-platform payments.
-- This is a read-only venue-scoped reconciliation RPC. It does not call
-- providers, mark orders paid, or replace the audited payment confirmation RPC.

CREATE INDEX IF NOT EXISTS payment_events_created_at_idx
  ON public.payment_events (created_at DESC);

CREATE OR REPLACE FUNCTION public.venue_manual_payment_reconciliation(
  p_venue_id uuid,
  p_business_date date DEFAULT timezone('utc'::text, now())::date
) RETURNS TABLE (
  venue_id uuid,
  business_date date,
  payment_method text,
  payment_status text,
  event_count bigint,
  amount_received numeric,
  order_total_amount numeric,
  provider_api_used boolean,
  external_reference_count bigint,
  first_event_at timestamp with time zone,
  last_event_at timestamp with time zone
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_start_at timestamp with time zone;
  v_end_at timestamp with time zone;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Venue id is required';
  END IF;

  IF p_business_date IS NULL THEN
    RAISE EXCEPTION 'Business date is required';
  END IF;

  IF NOT (
    public.is_active_admin_operator(auth.uid())
    OR public.venue_user_has_role(
      p_venue_id,
      ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]
    )
  ) THEN
    RAISE EXCEPTION 'Only venue operators can read payment reconciliation';
  END IF;

  v_start_at := p_business_date::timestamp AT TIME ZONE 'UTC';
  v_end_at := v_start_at + interval '1 day';

  RETURN QUERY
  WITH scoped_events AS (
    SELECT
      pe.provider::text AS payment_method,
      pe.status::text AS payment_status,
      pe.external_reference,
      pe.created_at,
      CASE
        WHEN pe.request_payload ->> 'amount_received' ~ '^-?[0-9]+(\.[0-9]+)?$'
          THEN (pe.request_payload ->> 'amount_received')::numeric
        ELSE 0::numeric
      END AS amount_received,
      CASE
        WHEN pe.request_payload ->> 'order_total_amount' ~ '^-?[0-9]+(\.[0-9]+)?$'
          THEN (pe.request_payload ->> 'order_total_amount')::numeric
        ELSE coalesce(o.total_amount, 0)::numeric
      END AS order_total_amount,
      coalesce(pe.response_payload ->> 'provider_api_used', 'false') = 'true' AS provider_api_used
    FROM public.payment_events pe
    JOIN public.orders o ON o.id = pe.order_id
    WHERE o.venue_id = p_venue_id
      AND pe.created_at >= v_start_at
      AND pe.created_at < v_end_at
  )
  SELECT
    p_venue_id AS venue_id,
    p_business_date AS business_date,
    scoped_events.payment_method,
    scoped_events.payment_status,
    count(*)::bigint AS event_count,
    coalesce(sum(scoped_events.amount_received), 0)::numeric AS amount_received,
    coalesce(sum(scoped_events.order_total_amount), 0)::numeric AS order_total_amount,
    scoped_events.provider_api_used,
    count(scoped_events.external_reference)::bigint AS external_reference_count,
    min(scoped_events.created_at) AS first_event_at,
    max(scoped_events.created_at) AS last_event_at
  FROM scoped_events
  GROUP BY
    scoped_events.payment_method,
    scoped_events.payment_status,
    scoped_events.provider_api_used
  ORDER BY
    scoped_events.payment_method,
    scoped_events.payment_status,
    scoped_events.provider_api_used;
END;
$$;

REVOKE ALL ON FUNCTION public.venue_manual_payment_reconciliation(uuid, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_manual_payment_reconciliation(uuid, date) TO authenticated, service_role;

COMMENT ON FUNCTION public.venue_manual_payment_reconciliation(uuid, date)
IS 'Read-only venue-scoped daily reconciliation summary for manual/off-platform payment events. Uses payment_events audit evidence and reports provider_api_used without executing provider APIs.';
