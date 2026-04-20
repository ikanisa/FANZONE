BEGIN;

-- ============================================================
-- 20260421040000_live_pipeline_final_hardening.sql
--
-- Final hardening pass for the live match update pipeline.
--
--   1. Clean orphaned live_match_events rows (NULL event_signature)
--   2. updated_at auto-triggers on matches and match_live_state
--   3. Drop deprecated dispatch_match_sync_jobs() function
--   4. CHECK constraint on matches.status
--   5. Verify Realtime publication completeness
-- ============================================================

-- ==================================================================
-- 1. Clean orphaned live_match_events rows
--    Rows inserted before the generated event_signature column was
--    added may have NULL signatures and bypass the dedup index.
-- ==================================================================

DELETE FROM public.live_match_events
WHERE event_signature IS NULL;

-- ==================================================================
-- 2a. updated_at auto-trigger on matches
--     Ensures updated_at stays fresh even for direct SQL updates
--     that forget to set it explicitly.
-- ==================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_matches_set_updated_at ON public.matches;

CREATE TRIGGER trg_matches_set_updated_at
  BEFORE UPDATE ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ==================================================================
-- 2b. updated_at auto-trigger on match_live_state
-- ==================================================================

DROP TRIGGER IF EXISTS trg_match_live_state_set_updated_at ON public.match_live_state;

CREATE TRIGGER trg_match_live_state_set_updated_at
  BEFORE UPDATE ON public.match_live_state
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ==================================================================
-- 2c. updated_at auto-trigger on match_sync_state
-- ==================================================================

DROP TRIGGER IF EXISTS trg_match_sync_state_set_updated_at ON public.match_sync_state;

CREATE TRIGGER trg_match_sync_state_set_updated_at
  BEFORE UPDATE ON public.match_sync_state
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ==================================================================
-- 2d. updated_at auto-trigger on trusted_match_sources
-- ==================================================================

DROP TRIGGER IF EXISTS trg_trusted_match_sources_set_updated_at ON public.trusted_match_sources;

CREATE TRIGGER trg_trusted_match_sources_set_updated_at
  BEFORE UPDATE ON public.trusted_match_sources
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ==================================================================
-- 3. Drop deprecated dispatch_match_sync_jobs()
--    Superseded by the async enqueue_match_sync_jobs() +
--    reconcile_match_sync_responses() pattern.
-- ==================================================================

DROP FUNCTION IF EXISTS public.dispatch_match_sync_jobs(text, integer);

-- ==================================================================
-- 4. CHECK constraint on matches.status
--    The normalize_match_status_before_write trigger already
--    normalizes on insert/update, but a CHECK prevents garbage
--    from bypassing the trigger via direct copy/restore.
-- ==================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'public'
      AND table_name = 'matches'
      AND constraint_name = 'matches_status_check'
  ) THEN
    -- First normalize any existing non-standard values
    UPDATE public.matches
    SET status = coalesce(
      public.normalize_match_status_value(status),
      'upcoming'
    )
    WHERE status IS NOT NULL
      AND status NOT IN ('live', 'finished', 'upcoming', 'postponed', 'cancelled');

    -- Now add the constraint
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_status_check
      CHECK (status IS NULL OR status IN (
        'live', 'finished', 'upcoming', 'postponed', 'cancelled'
      ));
  END IF;
END $$;

-- ==================================================================
-- 5. Verify Realtime publication completeness
--    Ensure all live-relevant tables are in supabase_realtime.
-- ==================================================================

DO $$
DECLARE
  v_tables text[] := ARRAY[
    'matches',
    'match_live_state',
    'match_events',
    'live_match_events',
    'match_odds_cache'
  ];
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY v_tables
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_table
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        v_table
      );
    END IF;
  END LOOP;
END $$;

-- ==================================================================
-- 6. Convenience: hydrate_match_live_state() for admin tooling
--    Creates a match_live_state row for any match that doesn't
--    have one yet. Useful for admin dashboards.
-- ==================================================================

CREATE OR REPLACE FUNCTION public.hydrate_match_live_state(
  p_match_id text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inserted integer;
BEGIN
  INSERT INTO public.match_live_state (
    match_id, status, phase, home_score, away_score
  )
  SELECT
    m.id,
    coalesce(public.normalize_match_status_value(m.status), 'upcoming'),
    CASE
      WHEN public.normalize_match_status_value(m.status) = 'live' THEN 'unknown'
      WHEN public.normalize_match_status_value(m.status) = 'finished' THEN 'finished'
      ELSE 'pre_match'
    END,
    coalesce(m.live_home_score, m.ft_home, 0),
    coalesce(m.live_away_score, m.ft_away, 0)
  FROM public.matches m
  WHERE (p_match_id IS NULL OR m.id = p_match_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.match_live_state ls
      WHERE ls.match_id = m.id
    );

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hydrate_match_live_state(text) TO service_role;

COMMIT;
