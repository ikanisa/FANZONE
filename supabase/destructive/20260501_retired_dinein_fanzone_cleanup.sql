-- Destructive cleanup for retired FANZONE objects.
--
-- public.bell_requests is an active table-assistance surface used by the
-- ring_bell Edge Function and venue portal staff queue. Do not drop it here.
--
-- DO NOT place this file in supabase/migrations.
-- DO NOT run without a fresh backup and a live dependency check.
--
-- Required backup marker:
--   psql "$SUPABASE_DB_URL" \
--     -v ON_ERROR_STOP=1 \
--     -c "set app.confirm_destructive_cleanup = '2026-05-01-backup-complete';" \
--     -f supabase/destructive/20260501_retired_dinein_fanzone_cleanup.sql

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_setting('app.confirm_destructive_cleanup', true) <> '2026-05-01-backup-complete' THEN
    RAISE EXCEPTION
      'Backup marker missing. Set app.confirm_destructive_cleanup=2026-05-01-backup-complete in the same DB session after backup and dependency review.';
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regprocedure('public.sports_bar_write_audit(text,text,text,jsonb,jsonb,uuid)') IS NOT NULL THEN
    PERFORM public.sports_bar_write_audit(
      'destructive_cleanup_started',
      'schema_cleanup',
      '20260501_retired_dinein_fanzone_cleanup',
      NULL,
      jsonb_build_object(
        'retired_objects', ARRAY[
          'standings',
          'team_form_features',
          'user_followed_competitions',
          'predictions',
          'prediction_entries',
          'fantasy_teams'
        ],
        'backup_marker', current_setting('app.confirm_destructive_cleanup', true)
      ),
      NULL
    );
  END IF;
END;
$$;

DROP TABLE IF EXISTS public.standings CASCADE;
DROP TABLE IF EXISTS public.team_form_features CASCADE;
DROP TABLE IF EXISTS public.user_followed_competitions CASCADE;
DROP TABLE IF EXISTS public.predictions CASCADE;
DROP TABLE IF EXISTS public.prediction_entries CASCADE;
DROP TABLE IF EXISTS public.fantasy_teams CASCADE;

DO $$
BEGIN
  IF to_regclass('public.user_market_preferences') IS NOT NULL THEN
    ALTER TABLE public.user_market_preferences
      DROP COLUMN IF EXISTS favorite_competition_ids,
      DROP COLUMN IF EXISTS follow_champions_league;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regprocedure('public.sports_bar_write_audit(text,text,text,jsonb,jsonb,uuid)') IS NOT NULL THEN
    PERFORM public.sports_bar_write_audit(
      'destructive_cleanup_completed',
      'schema_cleanup',
      '20260501_retired_dinein_fanzone_cleanup',
      NULL,
      jsonb_build_object('completed_at', timezone('utc', now())),
      NULL
    );
  END IF;
END;
$$;
