-- Harden mobile/runtime observability writes without changing the client RPCs.
-- Runtime crash telemetry remains available to anonymous sessions so pre-login
-- failures are captured. Product analytics remains authenticated-only.

ALTER TABLE public.app_runtime_errors
  ADD COLUMN IF NOT EXISTS event_type text NOT NULL DEFAULT 'exception',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_app_runtime_errors_event_type
  ON public.app_runtime_errors USING btree (event_type);

CREATE OR REPLACE FUNCTION public.observability_redact_text(
  p_value text,
  p_max_length integer DEFAULT 2000
) RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $$
DECLARE
  v_value text := coalesce(p_value, '');
  v_limit integer := greatest(coalesce(p_max_length, 2000), 0);
BEGIN
  v_value := regexp_replace(
    v_value,
    '(postgres(?:ql)?://)[^[:space:]''")]+',
    '\1[redacted]',
    'gi'
  );
  v_value := regexp_replace(
    v_value,
    '(Bearer[[:space:]]+)[A-Za-z0-9._~+/\-]+=*',
    '\1[redacted]',
    'gi'
  );
  v_value := regexp_replace(
    v_value,
    'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
    '[redacted-jwt]',
    'g'
  );
  v_value := regexp_replace(
    v_value,
    'sbp_[A-Za-z0-9_-]+',
    '[redacted-supabase-token]',
    'g'
  );
  v_value := regexp_replace(
    v_value,
    '(service_role|anon|api[_-]?key|access[_-]?token|refresh[_-]?token|password)=([^&[:space:]''")]+)',
    '\1=[redacted]',
    'gi'
  );

  v_value := left(trim(v_value), v_limit);
  RETURN nullif(v_value, '');
END;
$$;

CREATE OR REPLACE FUNCTION public.observability_safe_timestamptz(
  p_value text
) RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
BEGIN
  IF p_value IS NULL OR trim(p_value) = '' THEN
    RETURN timezone('utc', now());
  END IF;

  RETURN p_value::timestamptz;
EXCEPTION
  WHEN others THEN
    RETURN timezone('utc', now());
END;
$$;

CREATE OR REPLACE FUNCTION public.log_app_runtime_errors_batch(
  p_errors jsonb
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_error jsonb;
  v_metadata jsonb;
BEGIN
  IF p_errors IS NULL THEN
    RETURN 0;
  END IF;

  IF jsonb_typeof(p_errors) <> 'array' THEN
    RAISE EXCEPTION 'Runtime telemetry payload must be a JSON array';
  END IF;

  IF jsonb_array_length(p_errors) = 0 THEN
    RETURN 0;
  END IF;

  IF jsonb_array_length(p_errors) > 20 THEN
    RAISE EXCEPTION 'Batch size limit is 20 runtime errors';
  END IF;

  FOR v_error IN SELECT * FROM jsonb_array_elements(p_errors)
  LOOP
    v_metadata := CASE
      WHEN jsonb_typeof(v_error->'metadata') = 'object' THEN v_error->'metadata'
      ELSE '{}'::jsonb
    END;

    INSERT INTO public.app_runtime_errors (
      user_id,
      session_id,
      event_type,
      reason,
      error_message,
      stack_trace,
      platform,
      app_version,
      metadata,
      created_at
    ) VALUES (
      v_user_id,
      public.observability_redact_text(v_error->>'session_id', 120),
      left(
        coalesce(
          nullif(trim(v_error->>'type'), ''),
          'exception'
        ),
        40
      ),
      coalesce(
        public.observability_redact_text(v_error->>'reason', 120),
        'app_exception'
      ),
      coalesce(
        public.observability_redact_text(
          coalesce(v_error->>'error_message', v_error->>'message'),
          2000
        ),
        'Unknown runtime error'
      ),
      public.observability_redact_text(v_error->>'stack_trace', 8000),
      public.observability_redact_text(v_error->>'platform', 40),
      public.observability_redact_text(v_error->>'app_version', 40),
      v_metadata,
      public.observability_safe_timestamptz(v_error->>'captured_at')
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_product_event(
  p_event_name text,
  p_properties jsonb DEFAULT '{}'::jsonb,
  p_session_id text DEFAULT NULL::text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event_id uuid;
  v_event_name text := left(nullif(trim(coalesce(p_event_name, '')), ''), 80);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required for product analytics';
  END IF;

  IF v_event_name IS NULL THEN
    RAISE EXCEPTION 'event_name is required';
  END IF;

  INSERT INTO public.product_events (
    user_id,
    event_name,
    properties,
    session_id
  ) VALUES (
    v_user_id,
    v_event_name,
    CASE
      WHEN jsonb_typeof(p_properties) = 'object' THEN p_properties
      ELSE '{}'::jsonb
    END,
    public.observability_redact_text(p_session_id, 120)
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_product_events_batch(
  p_events jsonb
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_event jsonb;
  v_event_name text;
  v_properties jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required for product analytics';
  END IF;

  IF p_events IS NULL THEN
    RETURN 0;
  END IF;

  IF jsonb_typeof(p_events) <> 'array' THEN
    RAISE EXCEPTION 'Product analytics payload must be a JSON array';
  END IF;

  IF jsonb_array_length(p_events) = 0 THEN
    RETURN 0;
  END IF;

  IF jsonb_array_length(p_events) > 50 THEN
    RAISE EXCEPTION 'Batch size limit is 50 events';
  END IF;

  FOR v_event IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    v_event_name := left(
      nullif(trim(coalesce(v_event->>'event_name', '')), ''),
      80
    );

    IF v_event_name IS NULL THEN
      RAISE EXCEPTION 'event_name is required';
    END IF;

    v_properties := CASE
      WHEN jsonb_typeof(v_event->'properties') = 'object'
        THEN v_event->'properties'
      ELSE '{}'::jsonb
    END;

    INSERT INTO public.product_events (
      user_id,
      event_name,
      properties,
      session_id,
      created_at
    ) VALUES (
      v_user_id,
      v_event_name,
      v_properties,
      public.observability_redact_text(v_event->>'session_id', 120),
      public.observability_safe_timestamptz(v_event->>'created_at')
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON TABLE public.app_runtime_errors FROM anon, authenticated;
REVOKE ALL ON TABLE public.product_events FROM anon, authenticated;

REVOKE ALL ON FUNCTION public.observability_redact_text(text, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.observability_safe_timestamptz(text)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.log_app_runtime_errors_batch(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_app_runtime_errors_batch(jsonb)
  TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.log_product_event(text, jsonb, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_product_events_batch(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_product_event(text, jsonb, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.log_product_events_batch(jsonb)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.log_app_runtime_errors_batch(jsonb)
  IS 'Writes redacted runtime errors/events through a bounded SECURITY DEFINER RPC. Available to anon for pre-login crash telemetry.';
COMMENT ON FUNCTION public.log_product_events_batch(jsonb)
  IS 'Writes bounded authenticated product analytics events. Anonymous execution is intentionally revoked.';
