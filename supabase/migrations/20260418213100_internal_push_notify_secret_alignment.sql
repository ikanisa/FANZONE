BEGIN;

CREATE OR REPLACE FUNCTION public.send_push_to_user(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_push_notify_secret text;
  v_payload jsonb;
BEGIN
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);
  v_push_notify_secret := nullif(current_setting('app.settings.push_notify_secret', true), '');

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'Push notification config not set — skipping';
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'user_id', p_user_id,
    'type', p_type,
    'title', p_title,
    'body', p_body,
    'data', p_data
  );

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/push-notify',
    headers := jsonb_strip_nulls(
      jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json',
        'x-push-notify-secret', v_push_notify_secret
      )
    ),
    body := v_payload
  );
END;
$$;

COMMIT;
