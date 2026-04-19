BEGIN;

CREATE TABLE IF NOT EXISTS public.app_runtime_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id text,
  reason text NOT NULL,
  error_message text NOT NULL,
  stack_trace text,
  platform text,
  app_version text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_app_runtime_errors_created_at
  ON public.app_runtime_errors (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_runtime_errors_reason
  ON public.app_runtime_errors (reason);

CREATE INDEX IF NOT EXISTS idx_app_runtime_errors_user_id
  ON public.app_runtime_errors (user_id)
  WHERE user_id IS NOT NULL;

ALTER TABLE public.app_runtime_errors ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.log_app_runtime_errors_batch(
  p_errors jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_error jsonb;
BEGIN
  IF p_errors IS NULL OR jsonb_array_length(p_errors) = 0 THEN
    RETURN 0;
  END IF;

  IF jsonb_array_length(p_errors) > 20 THEN
    RAISE EXCEPTION 'Batch size limit is 20 runtime errors';
  END IF;

  FOR v_error IN SELECT * FROM jsonb_array_elements(p_errors)
  LOOP
    INSERT INTO public.app_runtime_errors (
      user_id,
      session_id,
      reason,
      error_message,
      stack_trace,
      platform,
      app_version,
      created_at
    ) VALUES (
      v_user_id,
      left(nullif(trim(coalesce(v_error->>'session_id', '')), ''), 120),
      left(coalesce(nullif(trim(v_error->>'reason'), ''), 'app_exception'), 120),
      left(coalesce(nullif(trim(v_error->>'error_message'), ''), 'Unknown runtime error'), 2000),
      left(nullif(trim(coalesce(v_error->>'stack_trace', '')), ''), 8000),
      left(nullif(trim(coalesce(v_error->>'platform', '')), ''), 40),
      left(nullif(trim(coalesce(v_error->>'app_version', '')), ''), 40),
      coalesce(
        (v_error->>'captured_at')::timestamptz,
        timezone('utc', now())
      )
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.log_app_runtime_errors_batch(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_app_runtime_errors_batch(jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.log_app_runtime_errors_batch(jsonb) TO authenticated;

COMMIT;
