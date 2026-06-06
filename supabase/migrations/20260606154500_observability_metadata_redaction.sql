-- Redact nested telemetry metadata/properties before storing observability rows.
-- This keeps dashboard context useful while preventing token-like values from
-- being persisted inside JSON payloads.

CREATE OR REPLACE FUNCTION public.observability_redact_jsonb(
  p_value jsonb,
  p_max_depth integer DEFAULT 4
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $$
DECLARE
  v_type text;
  v_result jsonb;
  v_key text;
  v_child jsonb;
  v_redacted_text text;
BEGIN
  IF p_value IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;

  IF p_max_depth <= 0 THEN
    RETURN to_jsonb('[redacted-depth]'::text);
  END IF;

  v_type := jsonb_typeof(p_value);

  IF v_type = 'object' THEN
    v_result := '{}'::jsonb;
    FOR v_key, v_child IN SELECT key, value FROM jsonb_each(p_value)
    LOOP
      IF v_key ~* '(authorization|bearer|password|secret|token|api[_-]?key|service[_-]?role|access[_-]?token|refresh[_-]?token)' THEN
        v_result := v_result || jsonb_build_object(left(v_key, 80), '[redacted]');
      ELSE
        v_result := v_result || jsonb_build_object(
          left(v_key, 80),
          public.observability_redact_jsonb(v_child, p_max_depth - 1)
        );
      END IF;
    END LOOP;
    RETURN v_result;
  END IF;

  IF v_type = 'array' THEN
    SELECT coalesce(
      jsonb_agg(
        public.observability_redact_jsonb(value, p_max_depth - 1)
        ORDER BY ordinality
      ),
      '[]'::jsonb
    )
    INTO v_result
    FROM jsonb_array_elements(p_value) WITH ORDINALITY;

    RETURN v_result;
  END IF;

  IF v_type = 'string' THEN
    v_redacted_text := public.observability_redact_text(p_value #>> '{}', 500);
    RETURN to_jsonb(coalesce(v_redacted_text, ''));
  END IF;

  IF v_type IN ('number', 'boolean') THEN
    RETURN p_value;
  END IF;

  RETURN 'null'::jsonb;
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
      WHEN jsonb_typeof(v_error->'metadata') = 'object'
        THEN public.observability_redact_jsonb(v_error->'metadata')
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
      WHEN jsonb_typeof(p_properties) = 'object'
        THEN public.observability_redact_jsonb(p_properties)
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
        THEN public.observability_redact_jsonb(v_event->'properties')
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

REVOKE ALL ON FUNCTION public.observability_redact_jsonb(jsonb, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.observability_redact_jsonb(jsonb, integer)
  TO service_role;

COMMENT ON FUNCTION public.observability_redact_jsonb(jsonb, integer)
  IS 'Redacts token-like keys and values in telemetry metadata before storage.';
