BEGIN;

-- ============================================================
-- 20260421010000_team_id_canonicalization.sql
--
-- Phase 2 of the full-stack Supabase refactor.
-- Resolves team ID fragmentation where the same club has multiple
-- IDs across different data sources.
--
-- All table references are wrapped in existence checks so this
-- migration is safe regardless of which upstream migrations have
-- been applied to the remote database.
-- ============================================================

-- ==================================================================
-- 1. team_aliases — canonical ID lookup
-- ==================================================================

CREATE TABLE IF NOT EXISTS public.team_aliases (
  alias_id text PRIMARY KEY,
  canonical_id text NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  source text DEFAULT 'manual_audit',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_aliases_canonical
  ON public.team_aliases (canonical_id);

ALTER TABLE public.team_aliases ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'team_aliases' AND policyname = 'Public read team aliases'
  ) THEN
    EXECUTE 'CREATE POLICY "Public read team aliases" ON public.team_aliases FOR SELECT USING (true)';
  END IF;
END $$;

-- ==================================================================
-- 2. Populate known aliases
-- ==================================================================

INSERT INTO public.team_aliases (alias_id, canonical_id, source) VALUES
  -- Inter Milan aliases
  ('inter',           'fc-internazionale-milano', 'audit_20260421'),
  ('it-inter-milan',  'fc-internazionale-milano', 'audit_20260421'),
  ('inter-ita',       'fc-internazionale-milano', 'audit_20260421'),
  -- Napoli aliases
  ('it-ssc-napoli',   'ssc-napoli', 'audit_20260421'),
  -- Lazio aliases
  ('it-ss-lazio',     'ss-lazio', 'audit_20260421'),
  ('lazio-roma',      'ss-lazio', 'audit_20260421'),
  -- Sevilla aliases
  ('es-sevilla',      'sevilla-fc', 'audit_20260421'),
  -- Villarreal aliases
  ('es-villarreal',   'villarreal-cf', 'audit_20260421'),
  -- Monaco aliases
  ('as-monaco',       'as-monaco-fc', 'audit_20260421'),
  ('fr-as-monaco',    'as-monaco-fc', 'audit_20260421'),
  -- Betis aliases
  ('real-betis-balompie', 'real-betis', 'audit_20260421'),
  -- Fiorentina aliases
  ('it-acf-fiorentina', 'acf-fiorentina', 'audit_20260421')
ON CONFLICT (alias_id) DO NOTHING;

-- ==================================================================
-- 3. resolve_team_id() — helper to resolve aliases
-- ==================================================================

CREATE OR REPLACE FUNCTION public.resolve_team_id(p_id text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT canonical_id FROM public.team_aliases WHERE alias_id = p_id),
    p_id
  );
$$;

-- ==================================================================
-- 4. Update matches to canonical team IDs
-- ==================================================================

UPDATE public.matches AS m
SET home_team_id = ta.canonical_id,
    updated_at = timezone('utc', now())
FROM public.team_aliases ta
WHERE m.home_team_id = ta.alias_id;

UPDATE public.matches AS m
SET away_team_id = ta.canonical_id,
    updated_at = timezone('utc', now())
FROM public.team_aliases ta
WHERE m.away_team_id = ta.alias_id;

-- ==================================================================
-- 5. Merge fan community data to canonical IDs
--    All wrapped in DO blocks that check table existence first.
-- ==================================================================

-- 5a. team_supporters
DO $$
BEGIN
  IF to_regclass('public.team_supporters') IS NOT NULL THEN
    -- Delete duplicates before updating
    EXECUTE '
      WITH duplicates AS (
        SELECT ts.id
        FROM public.team_supporters ts
        JOIN public.team_aliases ta ON ts.team_id = ta.alias_id
        WHERE EXISTS (
          SELECT 1 FROM public.team_supporters ts2
          WHERE ts2.team_id = ta.canonical_id AND ts2.user_id = ts.user_id
        )
      )
      DELETE FROM public.team_supporters WHERE id IN (SELECT id FROM duplicates)
    ';

    EXECUTE '
      UPDATE public.team_supporters AS ts
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE ts.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- 5b. team_contributions
DO $$
BEGIN
  IF to_regclass('public.team_contributions') IS NOT NULL THEN
    EXECUTE '
      UPDATE public.team_contributions AS tc
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE tc.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- 5c. team_news
DO $$
BEGIN
  IF to_regclass('public.team_news') IS NOT NULL THEN
    EXECUTE '
      UPDATE public.team_news AS tn
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE tn.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- 5d. user_followed_teams — composite PK (user_id, team_id), no 'id' column
DO $$
BEGIN
  IF to_regclass('public.user_followed_teams') IS NOT NULL THEN
    -- Delete rows where alias would clash with existing canonical
    EXECUTE '
      DELETE FROM public.user_followed_teams
      WHERE (user_id, team_id) IN (
        SELECT uft.user_id, uft.team_id
        FROM public.user_followed_teams uft
        JOIN public.team_aliases ta ON uft.team_id = ta.alias_id
        WHERE EXISTS (
          SELECT 1 FROM public.user_followed_teams uft2
          WHERE uft2.team_id = ta.canonical_id AND uft2.user_id = uft.user_id
        )
      )
    ';

    EXECUTE '
      UPDATE public.user_followed_teams AS uft
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE uft.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- 5e. match_events
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'match_events' AND column_name = 'team_id'
  ) THEN
    EXECUTE '
      UPDATE public.match_events AS me
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE me.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- 5f. match_player_stats
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'match_player_stats' AND column_name = 'team_id'
  ) THEN
    EXECUTE '
      UPDATE public.match_player_stats AS mps
      SET team_id = ta.canonical_id
      FROM public.team_aliases ta
      WHERE mps.team_id = ta.alias_id
    ';
  END IF;
END $$;

-- ==================================================================
-- 6. Recalculate fan_count on canonical teams
-- ==================================================================

DO $$
BEGIN
  IF to_regclass('public.team_supporters') IS NOT NULL THEN
    EXECUTE '
      UPDATE public.teams AS t
      SET fan_count = (
          SELECT COUNT(*)
          FROM public.team_supporters ts
          WHERE ts.team_id = t.id AND ts.is_active = true
        ),
        updated_at = timezone(''utc'', now())
      WHERE EXISTS (
        SELECT 1 FROM public.team_aliases ta WHERE ta.canonical_id = t.id
      )
    ';
  END IF;
END $$;

-- ==================================================================
-- 7. Propagate crest from alias to canonical if canonical has none
-- ==================================================================

UPDATE public.teams AS canonical
SET crest_url = alias_team.crest_url,
    updated_at = timezone('utc', now())
FROM public.team_aliases ta
JOIN public.teams alias_team ON alias_team.id = ta.alias_id
WHERE canonical.id = ta.canonical_id
  AND (canonical.crest_url IS NULL OR canonical.crest_url = '')
  AND alias_team.crest_url IS NOT NULL
  AND alias_team.crest_url != '';

-- ==================================================================
-- 8. Soft-delete alias team rows
-- ==================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'teams' AND column_name = 'admin_notes'
  ) THEN
    EXECUTE '
      UPDATE public.teams
      SET is_active = false,
          admin_notes = COALESCE(admin_notes, '''') || E''\n[AUDIT 2026-04-21] Deactivated: alias of canonical ID (see team_aliases)'',
          updated_at = timezone(''utc'', now())
      WHERE id IN (SELECT alias_id FROM public.team_aliases)
        AND (is_active IS NULL OR is_active = true)
    ';
  ELSE
    UPDATE public.teams
    SET is_active = false,
        updated_at = timezone('utc', now())
    WHERE id IN (SELECT alias_id FROM public.team_aliases)
      AND (is_active IS NULL OR is_active = true);
  END IF;
END $$;

-- ==================================================================
-- 9. Sync match logos from updated team crests
-- ==================================================================

SELECT public.sync_match_logos_from_teams();

COMMIT;
