-- ============================================================
-- 20260418145500_team_rls_policy_backfill.sql
-- Restore missing team/community RLS policies in drifted projects.
-- ============================================================

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.team_supporters') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.team_supporters ENABLE ROW LEVEL SECURITY';
  END IF;

  IF to_regclass('public.team_contributions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.team_contributions ENABLE ROW LEVEL SECURITY';
  END IF;

  IF to_regclass('public.team_news') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.team_news ENABLE ROW LEVEL SECURITY';
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'team_supporters'
      AND policyname = 'Users read own team supporters'
  ) AND to_regclass('public.team_supporters') IS NOT NULL THEN
    CREATE POLICY "Users read own team supporters"
      ON public.team_supporters
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'team_contributions'
      AND policyname = 'Users read own contributions'
  ) AND to_regclass('public.team_contributions') IS NOT NULL THEN
    CREATE POLICY "Users read own contributions"
      ON public.team_contributions
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'team_news'
      AND policyname = 'Public read published team news'
  ) AND to_regclass('public.team_news') IS NOT NULL THEN
    CREATE POLICY "Public read published team news"
      ON public.team_news
      FOR SELECT
      USING (status = 'published');
  END IF;
END;
$$;

COMMIT;
