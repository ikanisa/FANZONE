-- Replace blocking pg_net collection with an async queue + reconcile cycle.
-- This keeps pg_cron fast, prevents stuck transactions, and preserves
-- per-match observability/state in public.match_sync_request_log.

CREATE OR REPLACE FUNCTION public.reconcile_match_sync_responses(
  p_fetch_type text DEFAULT NULL,
  p_limit integer DEFAULT 200
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_limit integer := greatest(coalesce(p_limit, 200), 1);
  v_pending_window interval;
  v_processed integer := 0;
  v_succeeded integer := 0;
  v_failed integer := 0;
  v_timed_out integer := 0;
  v_response_body jsonb;
  v_http_status integer;
  v_success boolean;
  v_error_text text;
  v_response_status text;
  v_event_status text;
  rec record;
BEGIN
  IF p_fetch_type IS NOT NULL AND p_fetch_type NOT IN ('events', 'odds') THEN
    RAISE EXCEPTION 'Unsupported fetch type: %', p_fetch_type;
  END IF;

  FOR rec IN
    SELECT
      log.id AS log_id,
      log.match_id,
      log.fetch_type,
      log.request_id,
      log.requested_at,
      resp.status_code,
      resp.content,
      resp.error_msg,
      resp.timed_out
    FROM public.match_sync_request_log AS log
    LEFT JOIN net._http_response AS resp ON resp.id = log.request_id
    WHERE log.completed_at IS NULL
      AND (p_fetch_type IS NULL OR log.fetch_type = p_fetch_type)
    ORDER BY log.requested_at ASC
    LIMIT v_limit
  LOOP
    IF rec.status_code IS NULL AND rec.error_msg IS NULL AND NOT coalesce(rec.timed_out, false) THEN
      v_pending_window := CASE
        WHEN rec.fetch_type = 'events' THEN interval '8 minutes'
        ELSE interval '45 minutes'
      END;

      IF rec.requested_at > v_now - v_pending_window THEN
        CONTINUE;
      END IF;

      v_http_status := 504;
      v_response_body := NULL;
      v_success := false;
      v_error_text := 'Timed out waiting for pg_net response.';
      v_timed_out := v_timed_out + 1;
    ELSE
      v_http_status := rec.status_code;

      BEGIN
        v_response_body := CASE
          WHEN nullif(trim(coalesce(rec.content, '')), '') IS NULL THEN NULL
          ELSE rec.content::jsonb
        END;
      EXCEPTION WHEN others THEN
        v_response_body := jsonb_build_object('raw', coalesce(rec.content, ''));
      END;

      v_success := coalesce(v_http_status BETWEEN 200 AND 299, false)
        AND lower(coalesce(v_response_body->>'success', 'false')) = 'true';

      v_error_text := CASE
        WHEN v_success THEN NULL
        ELSE coalesce(
          v_response_body->>'error',
          rec.error_msg,
          CASE
            WHEN coalesce(rec.timed_out, false) THEN 'Timed out waiting for HTTP response.'
            ELSE NULL
          END,
          'Unknown match sync error'
        )
      END;
    END IF;

    UPDATE public.match_sync_request_log
    SET
      response_status = v_http_status,
      success = v_success,
      response_body = v_response_body,
      error_text = v_error_text,
      completed_at = v_now
    WHERE id = rec.log_id;

    IF rec.fetch_type = 'events' THEN
      v_event_status := public.normalize_match_status_value(
        coalesce(v_response_body #>> '{currentState,match_status}', NULL)
      );

      INSERT INTO public.match_sync_state (
        match_id,
        last_events_refresh_at,
        last_events_status,
        last_events_http_status,
        last_events_error,
        consecutive_event_failures,
        updated_at
      )
      VALUES (
        rec.match_id,
        rec.requested_at,
        CASE
          WHEN v_success THEN v_event_status
          ELSE 'error'
        END,
        v_http_status,
        CASE WHEN v_success THEN NULL ELSE v_error_text END,
        CASE WHEN v_success THEN 0 ELSE 1 END,
        v_now
      )
      ON CONFLICT (match_id) DO UPDATE
      SET
        last_events_refresh_at = greatest(
          coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz),
          excluded.last_events_refresh_at
        ),
        last_events_status = CASE
          WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
            THEN coalesce(excluded.last_events_status, public.match_sync_state.last_events_status)
          ELSE public.match_sync_state.last_events_status
        END,
        last_events_http_status = CASE
          WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
            THEN excluded.last_events_http_status
          ELSE public.match_sync_state.last_events_http_status
        END,
        last_events_error = CASE
          WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
            THEN excluded.last_events_error
          ELSE public.match_sync_state.last_events_error
        END,
        consecutive_event_failures = CASE
          WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz) THEN
            CASE
              WHEN excluded.last_events_error IS NULL THEN 0
              ELSE public.match_sync_state.consecutive_event_failures + 1
            END
          ELSE public.match_sync_state.consecutive_event_failures
        END,
        updated_at = excluded.updated_at;
    ELSE
      INSERT INTO public.match_sync_state (
        match_id,
        last_odds_refresh_at,
        last_odds_status,
        last_odds_http_status,
        last_odds_error,
        consecutive_odds_failures,
        updated_at
      )
      VALUES (
        rec.match_id,
        rec.requested_at,
        CASE WHEN v_success THEN 'ok' ELSE 'error' END,
        v_http_status,
        CASE WHEN v_success THEN NULL ELSE v_error_text END,
        CASE WHEN v_success THEN 0 ELSE 1 END,
        v_now
      )
      ON CONFLICT (match_id) DO UPDATE
      SET
        last_odds_refresh_at = greatest(
          coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz),
          excluded.last_odds_refresh_at
        ),
        last_odds_status = CASE
          WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
            THEN coalesce(excluded.last_odds_status, public.match_sync_state.last_odds_status)
          ELSE public.match_sync_state.last_odds_status
        END,
        last_odds_http_status = CASE
          WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
            THEN excluded.last_odds_http_status
          ELSE public.match_sync_state.last_odds_http_status
        END,
        last_odds_error = CASE
          WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
            THEN excluded.last_odds_error
          ELSE public.match_sync_state.last_odds_error
        END,
        consecutive_odds_failures = CASE
          WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz) THEN
            CASE
              WHEN excluded.last_odds_error IS NULL THEN 0
              ELSE public.match_sync_state.consecutive_odds_failures + 1
            END
          ELSE public.match_sync_state.consecutive_odds_failures
        END,
        updated_at = excluded.updated_at;
    END IF;

    v_processed := v_processed + 1;

    IF v_success THEN
      v_succeeded := v_succeeded + 1;
    ELSE
      v_failed := v_failed + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'succeeded', v_succeeded,
    'failed', v_failed,
    'timed_out', v_timed_out,
    'reconciled_at', v_now
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.enqueue_match_sync_jobs(
  p_fetch_type text DEFAULT 'events',
  p_limit integer DEFAULT 12
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_limit integer := greatest(coalesce(p_limit, 12), 1);
  v_project_url text;
  v_anon_key text;
  v_admin_secret text;
  v_timeout_milliseconds integer;
  v_request_id bigint;
  v_dispatched integer := 0;
  v_enqueue_failures integer := 0;
  v_request_payload jsonb;
  v_error_text text;
  rec record;
BEGIN
  IF p_fetch_type NOT IN ('events', 'odds') THEN
    RAISE EXCEPTION 'Unsupported fetch type: %', p_fetch_type;
  END IF;

  v_timeout_milliseconds := CASE
    WHEN p_fetch_type = 'events' THEN 45000
    ELSE 30000
  END;

  SELECT
    coalesce(
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_project_url'),
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'openfootball_sync_project_url')
    ),
    coalesce(
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_anon_key'),
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'openfootball_sync_anon_key')
    ),
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_admin_secret')
  INTO v_project_url, v_anon_key, v_admin_secret;

  IF v_project_url IS NULL OR v_anon_key IS NULL OR v_admin_secret IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets for match sync dispatcher.';
  END IF;

  FOR rec IN
    WITH candidates AS (
      SELECT
        m.id,
        m.home_team,
        m.away_team,
        public.normalize_match_status_value(m.status) AS normalized_status,
        (m.date::timestamp + coalesce(m.kickoff_time, time '00:00')) AS kickoff_at,
        s.last_events_refresh_at,
        s.last_odds_refresh_at,
        coalesce(s.consecutive_event_failures, 0) AS consecutive_event_failures,
        coalesce(s.consecutive_odds_failures, 0) AS consecutive_odds_failures
      FROM public.matches AS m
      LEFT JOIN public.match_sync_state AS s ON s.match_id = m.id
      WHERE m.date BETWEEN current_date AND current_date + 1
        AND NOT EXISTS (
          SELECT 1
          FROM public.match_sync_request_log AS log
          WHERE log.match_id = m.id
            AND log.fetch_type = p_fetch_type
            AND log.completed_at IS NULL
            AND log.requested_at >= v_now - CASE
              WHEN p_fetch_type = 'events' THEN interval '8 minutes'
              ELSE interval '45 minutes'
            END
        )
        AND (
          CASE
            WHEN p_fetch_type = 'events' THEN
              (
                public.normalize_match_status_value(m.status) = 'live'
                AND coalesce(s.last_events_refresh_at, 'epoch'::timestamptz) <=
                  v_now - CASE
                    WHEN coalesce(s.consecutive_event_failures, 0) >= 3 THEN interval '10 minutes'
                    ELSE interval '2 minutes'
                  END
              )
              OR
              (
                public.normalize_match_status_value(m.status) = 'upcoming'
                AND (m.date::timestamp + coalesce(m.kickoff_time, time '00:00')) <= v_now + interval '4 hours'
                AND coalesce(s.last_events_refresh_at, 'epoch'::timestamptz) <=
                  v_now - CASE
                    WHEN coalesce(s.consecutive_event_failures, 0) >= 3 THEN interval '30 minutes'
                    ELSE interval '10 minutes'
                  END
              )
            WHEN p_fetch_type = 'odds' THEN
              public.normalize_match_status_value(m.status) IN ('upcoming', 'live')
              AND (m.date::timestamp + coalesce(m.kickoff_time, time '00:00')) BETWEEN
                v_now - interval '2 hours' AND v_now + interval '36 hours'
              AND coalesce(s.last_odds_refresh_at, 'epoch'::timestamptz) <=
                v_now - CASE
                  WHEN public.normalize_match_status_value(m.status) = 'live' THEN interval '10 minutes'
                  WHEN coalesce(s.consecutive_odds_failures, 0) >= 3 THEN interval '60 minutes'
                  ELSE interval '30 minutes'
                END
            ELSE false
          END
        )
      ORDER BY
        CASE WHEN public.normalize_match_status_value(m.status) = 'live' THEN 0 ELSE 1 END,
        kickoff_at ASC
      LIMIT v_limit
    )
    SELECT * FROM candidates
  LOOP
    v_request_payload := jsonb_build_object(
      'teamA', rec.home_team,
      'teamB', rec.away_team,
      'matchId', rec.id,
      'fetchType', p_fetch_type
    );

    BEGIN
      v_request_id := net.http_post(
        url := v_project_url || '/functions/v1/gemini-sports-data',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_anon_key,
          'apikey', v_anon_key,
          'x-match-sync-secret', v_admin_secret
        ),
        body := v_request_payload,
        timeout_milliseconds := v_timeout_milliseconds
      );

      INSERT INTO public.match_sync_request_log (
        match_id,
        fetch_type,
        request_id,
        request_payload,
        requested_at
      )
      VALUES (
        rec.id,
        p_fetch_type,
        v_request_id,
        v_request_payload,
        v_now
      );

      IF p_fetch_type = 'events' THEN
        INSERT INTO public.match_sync_state (
          match_id,
          last_events_refresh_at,
          last_events_status,
          last_events_http_status,
          last_events_error,
          updated_at
        )
        VALUES (
          rec.id,
          v_now,
          'queued',
          NULL,
          NULL,
          v_now
        )
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_events_refresh_at = greatest(
            coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz),
            excluded.last_events_refresh_at
          ),
          last_events_status = CASE
            WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
              THEN excluded.last_events_status
            ELSE public.match_sync_state.last_events_status
          END,
          last_events_http_status = CASE
            WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
              THEN NULL
            ELSE public.match_sync_state.last_events_http_status
          END,
          last_events_error = CASE
            WHEN excluded.last_events_refresh_at >= coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz)
              THEN NULL
            ELSE public.match_sync_state.last_events_error
          END,
          updated_at = excluded.updated_at;
      ELSE
        INSERT INTO public.match_sync_state (
          match_id,
          last_odds_refresh_at,
          last_odds_status,
          last_odds_http_status,
          last_odds_error,
          updated_at
        )
        VALUES (
          rec.id,
          v_now,
          'queued',
          NULL,
          NULL,
          v_now
        )
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_odds_refresh_at = greatest(
            coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz),
            excluded.last_odds_refresh_at
          ),
          last_odds_status = CASE
            WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
              THEN excluded.last_odds_status
            ELSE public.match_sync_state.last_odds_status
          END,
          last_odds_http_status = CASE
            WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
              THEN NULL
            ELSE public.match_sync_state.last_odds_http_status
          END,
          last_odds_error = CASE
            WHEN excluded.last_odds_refresh_at >= coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz)
              THEN NULL
            ELSE public.match_sync_state.last_odds_error
          END,
          updated_at = excluded.updated_at;
      END IF;

      v_dispatched := v_dispatched + 1;
    EXCEPTION WHEN others THEN
      v_error_text := SQLERRM;

      INSERT INTO public.match_sync_request_log (
        match_id,
        fetch_type,
        request_id,
        request_payload,
        response_status,
        success,
        error_text,
        requested_at,
        completed_at
      )
      VALUES (
        rec.id,
        p_fetch_type,
        NULL,
        v_request_payload,
        NULL,
        false,
        v_error_text,
        v_now,
        v_now
      );

      IF p_fetch_type = 'events' THEN
        INSERT INTO public.match_sync_state (
          match_id,
          last_events_refresh_at,
          last_events_http_status,
          last_events_error,
          consecutive_event_failures,
          updated_at
        )
        VALUES (
          rec.id,
          v_now,
          NULL,
          v_error_text,
          1,
          v_now
        )
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_events_refresh_at = excluded.last_events_refresh_at,
          last_events_http_status = excluded.last_events_http_status,
          last_events_error = excluded.last_events_error,
          consecutive_event_failures = public.match_sync_state.consecutive_event_failures + 1,
          updated_at = excluded.updated_at;
      ELSE
        INSERT INTO public.match_sync_state (
          match_id,
          last_odds_refresh_at,
          last_odds_http_status,
          last_odds_error,
          consecutive_odds_failures,
          updated_at
        )
        VALUES (
          rec.id,
          v_now,
          NULL,
          v_error_text,
          1,
          v_now
        )
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_odds_refresh_at = excluded.last_odds_refresh_at,
          last_odds_http_status = excluded.last_odds_http_status,
          last_odds_error = excluded.last_odds_error,
          consecutive_odds_failures = public.match_sync_state.consecutive_odds_failures + 1,
          updated_at = excluded.updated_at;
      END IF;

      v_enqueue_failures := v_enqueue_failures + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'fetch_type', p_fetch_type,
    'queued', v_dispatched,
    'queue_failures', v_enqueue_failures,
    'enqueued_at', v_now
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.run_match_sync_cycle(
  p_fetch_type text DEFAULT 'events',
  p_limit integer DEFAULT 12
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_reconcile jsonb;
  v_enqueue jsonb;
BEGIN
  v_reconcile := public.reconcile_match_sync_responses(NULL, greatest(coalesce(p_limit, 12), 1) * 20);
  v_enqueue := public.enqueue_match_sync_jobs(p_fetch_type, p_limit);

  RETURN jsonb_build_object(
    'fetch_type', p_fetch_type,
    'reconcile', v_reconcile,
    'enqueue', v_enqueue,
    'ran_at', timezone('utc', now())
  );
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-sync-events') THEN
    PERFORM cron.unschedule('match-sync-events');
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-sync-odds') THEN
    PERFORM cron.unschedule('match-sync-odds');
  END IF;

  PERFORM cron.schedule(
    'match-sync-events',
    '*/2 * * * *',
    $cron$select public.run_match_sync_cycle('events', 6);$cron$
  );

  PERFORM cron.schedule(
    'match-sync-odds',
    '*/15 * * * *',
    $cron$select public.run_match_sync_cycle('odds', 8);$cron$
  );
END
$$;

UPDATE public.match_sync_state
SET
  last_events_status = 'error',
  updated_at = timezone('utc', now())
WHERE last_events_status = 'queued'
  AND last_events_error IS NOT NULL;

UPDATE public.match_sync_state
SET
  last_odds_status = 'error',
  updated_at = timezone('utc', now())
WHERE last_odds_status = 'queued'
  AND last_odds_error IS NOT NULL;
