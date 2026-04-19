BEGIN;

DO $$
DECLARE
  v_auto_settle_job_id bigint;
  v_dispatch_alerts_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    SELECT jobid
    INTO v_auto_settle_job_id
    FROM cron.job
    WHERE jobname = 'fanzone-auto-settle'
    ORDER BY jobid DESC
    LIMIT 1;

    IF v_auto_settle_job_id IS NOT NULL THEN
      PERFORM cron.unschedule(v_auto_settle_job_id);
    END IF;

    PERFORM cron.schedule(
      'fanzone-auto-settle',
      '*/15 * * * *',
      $job$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/auto-settle',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := '{}'::jsonb
      );
      $job$
    );

    SELECT jobid
    INTO v_dispatch_alerts_job_id
    FROM cron.job
    WHERE jobname = 'fanzone-dispatch-match-alerts'
    ORDER BY jobid DESC
    LIMIT 1;

    IF v_dispatch_alerts_job_id IS NOT NULL THEN
      PERFORM cron.unschedule(v_dispatch_alerts_job_id);
    END IF;

    PERFORM cron.schedule(
      'fanzone-dispatch-match-alerts',
      '*/5 * * * *',
      $job$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/dispatch-match-alerts',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := '{}'::jsonb
      );
      $job$
    );
  END IF;
END $$;

COMMIT;
