-- ============================================================
-- 20260419150000_product_analytics_events.sql
-- Lightweight product analytics: event logging + admin querying
--
-- Strategy: Supabase-native event logging for launch speed.
-- Users insert their own events; admin reads via RPCs.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1) Product events table
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.product_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_name  text NOT NULL,
  properties  jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_id  text,
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_product_events_event_name
  ON public.product_events (event_name);
CREATE INDEX IF NOT EXISTS idx_product_events_created_at
  ON public.product_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_events_user_id
  ON public.product_events (user_id)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_product_events_session
  ON public.product_events (session_id)
  WHERE session_id IS NOT NULL;

-- RLS: users insert their own events only
ALTER TABLE public.product_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own events"
  ON public.product_events
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- No SELECT for regular users (privacy)
-- Admin reads via service-role RPCs below

-- -----------------------------------------------------------------
-- 2) Client-side event logging RPC
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_product_event(
  p_event_name  text,
  p_properties  jsonb DEFAULT '{}'::jsonb,
  p_session_id  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event_id uuid;
BEGIN
  IF p_event_name IS NULL OR trim(p_event_name) = '' THEN
    RAISE EXCEPTION 'event_name is required';
  END IF;

  INSERT INTO public.product_events (
    user_id,
    event_name,
    properties,
    session_id
  ) VALUES (
    v_user_id,
    trim(p_event_name),
    coalesce(p_properties, '{}'::jsonb),
    nullif(trim(coalesce(p_session_id, '')), '')
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

-- -----------------------------------------------------------------
-- 3) Batch event logging RPC (for client-side batching)
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_product_events_batch(
  p_events jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_event jsonb;
BEGIN
  IF p_events IS NULL OR jsonb_array_length(p_events) = 0 THEN
    RETURN 0;
  END IF;

  -- Cap at 50 events per batch to prevent abuse
  IF jsonb_array_length(p_events) > 50 THEN
    RAISE EXCEPTION 'Batch size limit is 50 events';
  END IF;

  FOR v_event IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    INSERT INTO public.product_events (
      user_id,
      event_name,
      properties,
      session_id,
      created_at
    ) VALUES (
      v_user_id,
      trim(v_event->>'event_name'),
      coalesce(v_event->'properties', '{}'::jsonb),
      nullif(trim(coalesce(v_event->>'session_id', '')), ''),
      coalesce(
        (v_event->>'created_at')::timestamptz,
        timezone('utc', now())
      )
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- -----------------------------------------------------------------
-- 4) Admin query RPCs
-- -----------------------------------------------------------------

-- Event counts by name (for dashboard)
CREATE OR REPLACE FUNCTION public.admin_query_event_counts(
  p_since  timestamptz DEFAULT (now() - interval '7 days'),
  p_until  timestamptz DEFAULT now()
)
RETURNS TABLE(event_name text, event_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT pe.event_name, count(*)::bigint AS event_count
    FROM public.product_events pe
    WHERE pe.created_at >= p_since
      AND pe.created_at <= p_until
    GROUP BY pe.event_name
    ORDER BY event_count DESC;
END;
$$;

-- Daily active users
CREATE OR REPLACE FUNCTION public.admin_query_daily_active_users(
  p_since  timestamptz DEFAULT (now() - interval '30 days'),
  p_until  timestamptz DEFAULT now()
)
RETURNS TABLE(day date, unique_users bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT
      pe.created_at::date AS day,
      count(DISTINCT pe.user_id)::bigint AS unique_users
    FROM public.product_events pe
    WHERE pe.created_at >= p_since
      AND pe.created_at <= p_until
      AND pe.user_id IS NOT NULL
    GROUP BY pe.created_at::date
    ORDER BY day DESC;
END;
$$;

-- Screen view breakdown
CREATE OR REPLACE FUNCTION public.admin_query_screen_views(
  p_since  timestamptz DEFAULT (now() - interval '7 days'),
  p_until  timestamptz DEFAULT now()
)
RETURNS TABLE(screen_name text, view_count bigint, unique_viewers bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT
      pe.properties->>'screen' AS screen_name,
      count(*)::bigint AS view_count,
      count(DISTINCT pe.user_id)::bigint AS unique_viewers
    FROM public.product_events pe
    WHERE pe.event_name = 'screen_view'
      AND pe.created_at >= p_since
      AND pe.created_at <= p_until
    GROUP BY pe.properties->>'screen'
    ORDER BY view_count DESC;
END;
$$;

-- -----------------------------------------------------------------
-- 5) Grants
-- -----------------------------------------------------------------

REVOKE ALL ON FUNCTION public.log_product_event(text, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_product_event(text, jsonb, text) TO authenticated;

REVOKE ALL ON FUNCTION public.log_product_events_batch(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_product_events_batch(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_query_event_counts(timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_query_event_counts(timestamptz, timestamptz) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_query_daily_active_users(timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_query_daily_active_users(timestamptz, timestamptz) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_query_screen_views(timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_query_screen_views(timestamptz, timestamptz) TO authenticated;

-- -----------------------------------------------------------------
-- 6) Retention: auto-prune events older than 90 days (optional cron)
-- -----------------------------------------------------------------

-- To enable: schedule via pg_cron
-- SELECT cron.schedule('prune-old-events', '0 3 * * *',
--   $$DELETE FROM public.product_events WHERE created_at < now() - interval '90 days'$$
-- );

COMMIT;
