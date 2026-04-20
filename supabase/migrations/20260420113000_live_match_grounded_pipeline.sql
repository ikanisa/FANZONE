BEGIN;

-- ============================================================
-- Live match pipeline rebuild
-- - Separate volatile live state from final result fields.
-- - Add grounded source registry + review/audit tables.
-- - Poll only matches that should be live based on fixture calendar/state.
-- - Keep the current Flutter app working through a DB projection view.
-- ============================================================

-- ------------------------------------------------------------------
-- 1. Runtime settings and trusted source registry
-- ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.match_sync_runtime_settings (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  live_poll_interval_seconds integer NOT NULL DEFAULT 60
    CHECK (live_poll_interval_seconds BETWEEN 15 AND 3600),
  live_window_after_kickoff_minutes integer NOT NULL DEFAULT 210
    CHECK (live_window_after_kickoff_minutes BETWEEN 30 AND 720),
  max_event_requests_per_cycle integer NOT NULL DEFAULT 24
    CHECK (max_event_requests_per_cycle BETWEEN 1 AND 200),
  low_confidence_backoff_seconds integer NOT NULL DEFAULT 180
    CHECK (low_confidence_backoff_seconds BETWEEN 30 AND 7200),
  failed_backoff_seconds integer NOT NULL DEFAULT 300
    CHECK (failed_backoff_seconds BETWEEN 30 AND 14400),
  pending_request_timeout_seconds integer NOT NULL DEFAULT 180
    CHECK (pending_request_timeout_seconds BETWEEN 30 AND 3600),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

INSERT INTO public.match_sync_runtime_settings (singleton)
VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

ALTER TABLE public.match_sync_runtime_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.match_sync_runtime_settings FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_sync_runtime_settings TO service_role;

CREATE TABLE IF NOT EXISTS public.trusted_match_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_pattern text NOT NULL UNIQUE,
  source_name text NOT NULL,
  source_type text NOT NULL CHECK (source_type IN (
    'official_match_centre',
    'official_federation',
    'official_competition',
    'trusted_reference',
    'unknown'
  )),
  trust_score numeric(5,4) NOT NULL
    CHECK (trust_score >= 0 AND trust_score <= 1),
  active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_trusted_match_sources_active
  ON public.trusted_match_sources (active, trust_score DESC);

INSERT INTO public.trusted_match_sources (
  domain_pattern,
  source_name,
  source_type,
  trust_score,
  notes
)
VALUES
  ('mfa.com.mt', 'Malta Football Association', 'official_federation', 1.0000, 'Primary federation source for Malta fixtures/live pages'),
  ('new.mfa.com.mt', 'Malta Football Association', 'official_federation', 1.0000, 'Rebranded Malta FA website'),
  ('live.mfa.com.mt', 'Malta Football Association Live', 'official_match_centre', 1.0000, 'Live match centre on Malta FA infrastructure'),
  ('uefa.com', 'UEFA', 'official_competition', 0.9800, 'Official UEFA competition coverage'),
  ('fifa.com', 'FIFA', 'official_competition', 0.9800, 'Official FIFA competition coverage'),
  ('soccerway.com', 'Soccerway', 'trusted_reference', 0.8200, 'Structured match centre fallback'),
  ('flashscore.com', 'Flashscore', 'trusted_reference', 0.8200, 'Trusted public live-score reference'),
  ('worldfootball.net', 'worldfootball.net', 'trusted_reference', 0.7800, 'Trusted public historical/live reference'),
  ('fotmob.com', 'FotMob', 'trusted_reference', 0.8000, 'Trusted public live-score reference'),
  ('besoccer.com', 'BeSoccer', 'trusted_reference', 0.7600, 'Trusted public live-score reference')
ON CONFLICT (domain_pattern) DO UPDATE
SET
  source_name = EXCLUDED.source_name,
  source_type = EXCLUDED.source_type,
  trust_score = EXCLUDED.trust_score,
  notes = EXCLUDED.notes,
  updated_at = timezone('utc', now());

ALTER TABLE public.trusted_match_sources ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'trusted_match_sources'
      AND policyname = 'Public read trusted match sources'
  ) THEN
    CREATE POLICY "Public read trusted match sources"
      ON public.trusted_match_sources
      FOR SELECT
      TO anon, authenticated
      USING (active = true);
  END IF;
END $$;

GRANT SELECT ON public.trusted_match_sources TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trusted_match_sources TO service_role;

-- ------------------------------------------------------------------
-- 2. Canonical live state + audit/review tables
-- ------------------------------------------------------------------

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS live_home_score integer CHECK (live_home_score IS NULL OR live_home_score >= 0),
  ADD COLUMN IF NOT EXISTS live_away_score integer CHECK (live_away_score IS NULL OR live_away_score >= 0),
  ADD COLUMN IF NOT EXISTS live_minute integer CHECK (live_minute IS NULL OR (live_minute >= 0 AND live_minute <= 200)),
  ADD COLUMN IF NOT EXISTS live_phase text,
  ADD COLUMN IF NOT EXISTS last_live_checked_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_live_sync_confidence numeric(5,4)
    CHECK (last_live_sync_confidence IS NULL OR (last_live_sync_confidence >= 0 AND last_live_sync_confidence <= 1)),
  ADD COLUMN IF NOT EXISTS last_live_review_required boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.match_live_state (
  match_id text PRIMARY KEY REFERENCES public.matches(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'upcoming',
  minute integer CHECK (minute IS NULL OR (minute >= 0 AND minute <= 200)),
  phase text NOT NULL DEFAULT 'unknown' CHECK (phase IN (
    'pre_match',
    'first_half',
    'half_time',
    'second_half',
    'extra_time',
    'penalties',
    'finished',
    'postponed',
    'cancelled',
    'suspended',
    'unknown'
  )),
  home_score integer NOT NULL DEFAULT 0 CHECK (home_score >= 0),
  away_score integer NOT NULL DEFAULT 0 CHECK (away_score >= 0),
  confidence_score numeric(5,4)
    CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)),
  confidence_status text NOT NULL DEFAULT 'pending' CHECK (confidence_status IN (
    'pending',
    'confirmed',
    'low_confidence',
    'manual_review',
    'failed'
  )),
  review_required boolean NOT NULL DEFAULT false,
  review_reason text,
  provider text NOT NULL DEFAULT 'google_gemini_grounded',
  last_checked_at timestamptz,
  last_success_at timestamptz,
  next_check_at timestamptz,
  last_event_count integer NOT NULL DEFAULT 0 CHECK (last_event_count >= 0),
  last_error text,
  consecutive_failures integer NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
  grounding_sources jsonb NOT NULL DEFAULT '[]'::jsonb,
  source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_match_live_state_status_next_check
  ON public.match_live_state (status, next_check_at);

CREATE INDEX IF NOT EXISTS idx_match_live_state_review_required
  ON public.match_live_state (review_required, updated_at DESC)
  WHERE review_required = true;

ALTER TABLE public.match_live_state ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_live_state'
      AND policyname = 'Public read match live state'
  ) THEN
    CREATE POLICY "Public read match live state"
      ON public.match_live_state
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END $$;

GRANT SELECT ON public.match_live_state TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_live_state TO service_role;

CREATE TABLE IF NOT EXISTS public.match_live_update_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id text NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  response_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  grounding_sources jsonb NOT NULL DEFAULT '[]'::jsonb,
  search_queries text[] NOT NULL DEFAULT '{}'::text[],
  status text NOT NULL DEFAULT 'running' CHECK (status IN (
    'running',
    'completed',
    'low_confidence',
    'manual_review',
    'failed'
  )),
  confidence_score numeric(5,4)
    CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)),
  detected_status text,
  detected_phase text,
  detected_minute integer CHECK (detected_minute IS NULL OR (detected_minute >= 0 AND detected_minute <= 200)),
  inserted_live_event_count integer NOT NULL DEFAULT 0 CHECK (inserted_live_event_count >= 0),
  inserted_match_event_count integer NOT NULL DEFAULT 0 CHECK (inserted_match_event_count >= 0),
  updated_match boolean NOT NULL DEFAULT false,
  review_reason text,
  error_message text,
  model_name text,
  started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  finished_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_match_live_update_runs_match_started
  ON public.match_live_update_runs (match_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_match_live_update_runs_status_started
  ON public.match_live_update_runs (status, started_at DESC);

ALTER TABLE public.match_live_update_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.match_live_update_runs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_live_update_runs TO service_role;

CREATE OR REPLACE VIEW public.match_live_review_queue AS
SELECT
  runs.id AS run_id,
  runs.match_id,
  matches.home_team,
  matches.away_team,
  matches.competition_id,
  runs.status,
  runs.confidence_score,
  runs.detected_status,
  runs.detected_phase,
  runs.detected_minute,
  runs.review_reason,
  runs.error_message,
  runs.grounding_sources,
  runs.started_at,
  runs.finished_at
FROM public.match_live_update_runs AS runs
JOIN public.matches ON matches.id = runs.match_id
WHERE runs.status IN ('low_confidence', 'manual_review', 'failed')
ORDER BY runs.started_at DESC;

REVOKE ALL ON public.match_live_review_queue FROM anon, authenticated;
GRANT SELECT ON public.match_live_review_queue TO service_role;

-- ------------------------------------------------------------------
-- 3. Event history hardening
-- ------------------------------------------------------------------

ALTER TABLE public.match_events
  ADD COLUMN IF NOT EXISTS team_name text,
  ADD COLUMN IF NOT EXISTS source_provider text NOT NULL DEFAULT 'google_gemini_grounded',
  ADD COLUMN IF NOT EXISTS source_confidence numeric(5,4)
    CHECK (source_confidence IS NULL OR (source_confidence >= 0 AND source_confidence <= 1)),
  ADD COLUMN IF NOT EXISTS source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc', now());

ALTER TABLE public.match_events
  ADD COLUMN IF NOT EXISTS event_signature text
  GENERATED ALWAYS AS (
    md5(
      coalesce(minute::text, '') || '|' ||
      coalesce(event_type, '') || '|' ||
      coalesce(team_id, '') || '|' ||
      lower(coalesce(team_name, '')) || '|' ||
      lower(coalesce(player_name, '')) || '|' ||
      lower(coalesce(assist_player_name, '')) || '|' ||
      lower(coalesce(description, ''))
    )
  ) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS match_events_match_signature_idx
  ON public.match_events (match_id, event_signature);

ALTER TABLE public.live_match_events
  ADD COLUMN IF NOT EXISTS match_event_id uuid REFERENCES public.match_events(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS provider text NOT NULL DEFAULT 'google_gemini_grounded',
  ADD COLUMN IF NOT EXISTS confidence_score numeric(5,4)
    CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)),
  ADD COLUMN IF NOT EXISTS source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc', now());

CREATE INDEX IF NOT EXISTS idx_live_match_events_match_event_id
  ON public.live_match_events (match_event_id)
  WHERE match_event_id IS NOT NULL;

-- ------------------------------------------------------------------
-- 4. App projection view and Realtime publication
-- ------------------------------------------------------------------

CREATE OR REPLACE VIEW public.matches_live_view AS
SELECT
  m.id,
  m.competition_id,
  m.season,
  m.round,
  m.match_group,
  m.date,
  m.kickoff_time,
  m.home_team_id,
  m.away_team_id,
  m.home_team,
  m.away_team,
  CASE
    WHEN public.normalize_match_status_value(m.status) = 'live'
      THEN coalesce(m.live_home_score, m.ft_home)
    ELSE m.ft_home
  END AS ft_home,
  CASE
    WHEN public.normalize_match_status_value(m.status) = 'live'
      THEN coalesce(m.live_away_score, m.ft_away)
    ELSE m.ft_away
  END AS ft_away,
  m.ht_home,
  m.ht_away,
  m.et_home,
  m.et_away,
  m.status,
  m.venue,
  m.data_source,
  m.source_url,
  m.home_logo_url,
  m.away_logo_url
FROM public.matches AS m;

GRANT SELECT ON public.matches_live_view TO anon, authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'matches'
  ) THEN
    NULL;
  ELSE
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.matches';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'match_live_state'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.match_live_state';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'match_events'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.match_events';
  END IF;
END $$;

-- ------------------------------------------------------------------
-- 5. Status normalization and kickoff helpers
-- ------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.normalize_match_status_value(input_status text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  normalized text := lower(regexp_replace(coalesce(input_status, ''), '[\s-]+', '_', 'g'));
BEGIN
  CASE normalized
    WHEN 'live', 'in_play', 'inprogress', 'in_progress', 'playing',
         'first_half', 'second_half', 'half_time', 'halftime',
         'extra_time', 'et', 'penalties', 'penalty_shootout',
         'break', 'paused', 'delay', 'delayed', 'suspended' THEN
      RETURN 'live';
    WHEN 'finished', 'complete', 'completed', 'full_time', 'ft' THEN
      RETURN 'finished';
    WHEN 'scheduled', 'not_started', 'notstarted', 'pending', 'upcoming' THEN
      RETURN 'upcoming';
    WHEN 'postponed' THEN
      RETURN 'postponed';
    WHEN 'cancelled', 'canceled', 'abandoned' THEN
      RETURN 'cancelled';
    ELSE
      RETURN NULLIF(normalized, '');
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION public.match_kickoff_at_utc(
  p_match_date timestamptz,
  p_kickoff_time text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_time time;
BEGIN
  IF p_kickoff_time IS NULL OR btrim(p_kickoff_time) = '' THEN
    RETURN p_match_date;
  END IF;

  BEGIN
    v_time := btrim(p_kickoff_time)::time;
  EXCEPTION WHEN others THEN
    RETURN p_match_date;
  END;

  RETURN (((p_match_date AT TIME ZONE 'UTC')::date + v_time) AT TIME ZONE 'UTC');
END;
$$;

CREATE INDEX IF NOT EXISTS idx_match_sync_request_log_pending
  ON public.match_sync_request_log (fetch_type, requested_at DESC)
  WHERE completed_at IS NULL;

-- ------------------------------------------------------------------
-- 6. Live-only candidate enqueue + logged cron cycle
-- ------------------------------------------------------------------

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
  v_pending_timeout_seconds integer := 180;
  v_processed integer := 0;
  v_succeeded integer := 0;
  v_failed integer := 0;
  v_timed_out integer := 0;
  v_response_body jsonb;
  v_http_status integer;
  v_success boolean;
  v_error_text text;
  v_event_status text;
  rec record;
BEGIN
  IF p_fetch_type IS NOT NULL AND p_fetch_type NOT IN ('events', 'odds') THEN
    RAISE EXCEPTION 'Unsupported fetch type: %', p_fetch_type;
  END IF;

  SELECT pending_request_timeout_seconds
  INTO v_pending_timeout_seconds
  FROM public.match_sync_runtime_settings
  LIMIT 1;

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
        WHEN rec.fetch_type = 'events' THEN make_interval(secs => greatest(coalesce(v_pending_timeout_seconds, 180), 30))
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
          WHEN v_success THEN coalesce(v_event_status, 'ok')
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
  p_limit integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_project_url text;
  v_anon_key text;
  v_admin_secret text;
  v_timeout_milliseconds integer;
  v_request_id bigint;
  v_dispatched integer := 0;
  v_enqueue_failures integer := 0;
  v_request_payload jsonb;
  v_error_text text;
  v_live_poll_interval_seconds integer := 60;
  v_live_window_after_kickoff_minutes integer := 210;
  v_max_event_requests_per_cycle integer := 24;
  v_limit integer;
  rec record;
BEGIN
  IF p_fetch_type NOT IN ('events', 'odds') THEN
    RAISE EXCEPTION 'Unsupported fetch type: %', p_fetch_type;
  END IF;

  SELECT
    live_poll_interval_seconds,
    live_window_after_kickoff_minutes,
    max_event_requests_per_cycle
  INTO
    v_live_poll_interval_seconds,
    v_live_window_after_kickoff_minutes,
    v_max_event_requests_per_cycle
  FROM public.match_sync_runtime_settings
  LIMIT 1;

  v_limit := greatest(
    coalesce(
      p_limit,
      CASE
        WHEN p_fetch_type = 'events' THEN v_max_event_requests_per_cycle
        ELSE 8
      END
    ),
    1
  );

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
        c.name AS competition_name,
        m.source_url,
        public.normalize_match_status_value(m.status) AS normalized_status,
        public.match_kickoff_at_utc(m.date, m.kickoff_time) AS kickoff_at,
        live.status AS live_status,
        live.next_check_at,
        live.consecutive_failures
      FROM public.matches AS m
      LEFT JOIN public.competitions AS c ON c.id = m.competition_id
      LEFT JOIN public.match_live_state AS live ON live.match_id = m.id
      LEFT JOIN public.match_sync_state AS sync ON sync.match_id = m.id
      WHERE NOT EXISTS (
          SELECT 1
          FROM public.match_sync_request_log AS log
          WHERE log.match_id = m.id
            AND log.fetch_type = p_fetch_type
            AND log.completed_at IS NULL
            AND log.requested_at >= v_now - CASE
              WHEN p_fetch_type = 'events'
                THEN make_interval(secs => greatest(v_live_poll_interval_seconds * 2, 120))
              ELSE interval '45 minutes'
            END
        )
        AND (
          CASE
            WHEN p_fetch_type = 'events' THEN
              (
                coalesce(live.next_check_at, 'epoch'::timestamptz) <= v_now
                AND public.normalize_match_status_value(m.status) NOT IN ('finished', 'cancelled', 'postponed')
                AND (
                  public.normalize_match_status_value(coalesce(live.status, m.status)) = 'live'
                  OR public.normalize_match_status_value(m.status) = 'live'
                  OR public.match_kickoff_at_utc(m.date, m.kickoff_time)
                    BETWEEN v_now - make_interval(mins => greatest(v_live_window_after_kickoff_minutes, 30))
                    AND v_now
                )
              )
            WHEN p_fetch_type = 'odds' THEN
              public.normalize_match_status_value(m.status) IN ('upcoming', 'live')
              AND public.match_kickoff_at_utc(m.date, m.kickoff_time) BETWEEN
                v_now - interval '2 hours' AND v_now + interval '36 hours'
              AND coalesce(sync.last_odds_refresh_at, 'epoch'::timestamptz) <=
                v_now - CASE
                  WHEN public.normalize_match_status_value(m.status) = 'live' THEN interval '10 minutes'
                  WHEN coalesce(sync.consecutive_odds_failures, 0) >= 3 THEN interval '60 minutes'
                  ELSE interval '30 minutes'
                END
            ELSE false
          END
        )
      ORDER BY
        CASE
          WHEN public.normalize_match_status_value(coalesce(live.status, m.status)) = 'live' THEN 0
          ELSE 1
        END,
        kickoff_at ASC,
        m.id ASC
      LIMIT v_limit
    )
    SELECT * FROM candidates
  LOOP
    v_request_payload := jsonb_build_object(
      'teamA', rec.home_team,
      'teamB', rec.away_team,
      'matchId', rec.id,
      'fetchType', p_fetch_type,
      'competitionName', rec.competition_name,
      'sourceUrl', rec.source_url,
      'kickoffAt', rec.kickoff_at
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
          last_events_status = 'queued',
          last_events_http_status = NULL,
          last_events_error = NULL,
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
          last_odds_status = 'queued',
          last_odds_http_status = NULL,
          last_odds_error = NULL,
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
  p_limit integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_reconcile jsonb;
  v_enqueue jsonb;
  v_job_id uuid;
  v_job_name text := CASE
    WHEN p_fetch_type = 'events' THEN 'match-sync-events'
    ELSE 'match-sync-odds'
  END;
  v_result jsonb;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status)
  VALUES (v_job_name, 'running')
  RETURNING id INTO v_job_id;

  BEGIN
    v_reconcile := public.reconcile_match_sync_responses(
      NULL,
      greatest(coalesce(p_limit, 12), 1) * 20
    );
    v_enqueue := public.enqueue_match_sync_jobs(p_fetch_type, p_limit);

    v_result := jsonb_build_object(
      'fetch_type', p_fetch_type,
      'reconcile', v_reconcile,
      'enqueue', v_enqueue,
      'ran_at', timezone('utc', now())
    );

    UPDATE public.cron_job_log
    SET
      status = 'completed',
      completed_at = now(),
      duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000,
      result = v_result
    WHERE id = v_job_id;

    RETURN v_result;
  EXCEPTION WHEN others THEN
    UPDATE public.cron_job_log
    SET
      status = 'failed',
      completed_at = now(),
      duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000,
      error_message = SQLERRM
    WHERE id = v_job_id;
    RAISE;
  END;
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
    '* * * * *',
    $cron$select public.run_match_sync_cycle('events');$cron$
  );

  PERFORM cron.schedule(
    'match-sync-odds',
    '*/15 * * * *',
    $cron$select public.run_match_sync_cycle('odds', 8);$cron$
  );
END $$;

COMMIT;
