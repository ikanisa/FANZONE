-- ============================================================
-- 005_teams_and_fan_communities.sql
-- Teams & Fan Communities feature — schema, RLS, and RPCs.
-- Additive migration: extends existing tables, creates new ones.
-- ============================================================

BEGIN;

-- ======================
-- 1) EXTEND existing teams table
-- ======================

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS crest_url TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS league_name TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS fet_contributions_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS fiat_contributions_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS fiat_contribution_mode TEXT; -- 'revolut_api' | 'revolut_link' | 'other_payment_link'
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS fiat_contribution_link TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS admin_notes TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS fan_count INT DEFAULT 0;
-- updated_at may already exist from a prior migration; add idempotently
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Backfill slug from name for existing rows (lowercase, dash-separated)
UPDATE public.teams
SET slug = lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))
WHERE slug IS NULL;

-- ======================
-- 2) team_supporters — fan registry with anonymous IDs
-- ======================

CREATE TABLE IF NOT EXISTS public.team_supporters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id TEXT NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  anonymous_fan_id TEXT NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_supporters_team_id ON public.team_supporters(team_id);
CREATE INDEX IF NOT EXISTS idx_team_supporters_user_id ON public.team_supporters(user_id);
CREATE INDEX IF NOT EXISTS idx_team_supporters_active ON public.team_supporters(team_id, is_active);

-- ======================
-- 3) team_contributions — FET and fiat donations
-- ======================

CREATE TABLE IF NOT EXISTS public.team_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id TEXT NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  contribution_type TEXT NOT NULL CHECK (contribution_type IN ('fet', 'fiat')),
  amount_fet BIGINT,
  amount_money NUMERIC,
  currency_code TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  provider TEXT,
  provider_reference TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_contributions_team_id ON public.team_contributions(team_id);
CREATE INDEX IF NOT EXISTS idx_team_contributions_user_id ON public.team_contributions(user_id);

-- ======================
-- 4) team_news — AI-curated team-specific news
-- ======================

CREATE TABLE IF NOT EXISTS public.team_news (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id TEXT NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  summary TEXT,
  content TEXT,
  category TEXT DEFAULT 'general', -- 'breaking_news','transfers','match_updates','club_announcements','fan_community_news','general'
  source_url TEXT,
  source_name TEXT,
  image_url TEXT,
  published_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'review', 'published', 'archived')),
  is_ai_curated BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_news_team_id ON public.team_news(team_id);
CREATE INDEX IF NOT EXISTS idx_team_news_status ON public.team_news(status);
CREATE INDEX IF NOT EXISTS idx_team_news_published ON public.team_news(team_id, status, published_at DESC);

-- ======================
-- 5) team_news_ingestion_runs — audit trail for Gemini runs
-- ======================

CREATE TABLE IF NOT EXISTS public.team_news_ingestion_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id TEXT NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  run_type TEXT NOT NULL DEFAULT 'gemini_grounded_search',
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
  articles_found INT DEFAULT 0,
  articles_stored INT DEFAULT 0,
  result_summary TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 6) HELPER FUNCTION: generate_anonymous_fan_id
-- Deterministic per (user_id, team_id) pair using MD5 hash prefix.
-- ======================

CREATE OR REPLACE FUNCTION generate_anonymous_fan_id(
  p_user_id UUID,
  p_team_id TEXT
) RETURNS TEXT AS $$
BEGIN
  RETURN 'FAN-' || upper(substring(md5(p_user_id::text || '::' || p_team_id) FROM 1 FOR 8));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ======================
-- 7) RPC: support_team — join a team's fan community
-- ======================

CREATE OR REPLACE FUNCTION support_team(p_team_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_fan_id TEXT;
  v_existing RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check team exists and is active
  IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = p_team_id AND is_active = true) THEN
    RAISE EXCEPTION 'Team not found or inactive';
  END IF;

  -- Generate the deterministic anonymous fan ID
  v_fan_id := generate_anonymous_fan_id(v_user_id, p_team_id);

  -- Check if already a supporter
  SELECT * INTO v_existing
  FROM public.team_supporters
  WHERE team_id = p_team_id AND user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    IF v_existing.is_active THEN
      -- Already active supporter
      RETURN jsonb_build_object('status', 'already_supporting', 'anonymous_fan_id', v_fan_id);
    ELSE
      -- Reactivate
      UPDATE public.team_supporters
      SET is_active = true, joined_at = now()
      WHERE id = v_existing.id;

      UPDATE public.teams
      SET fan_count = GREATEST(fan_count + 1, 0), updated_at = now()
      WHERE id = p_team_id;

      RETURN jsonb_build_object('status', 'reactivated', 'anonymous_fan_id', v_fan_id);
    END IF;
  END IF;

  -- Insert new supporter
  INSERT INTO public.team_supporters (team_id, user_id, anonymous_fan_id)
  VALUES (p_team_id, v_user_id, v_fan_id);

  -- Increment fan count
  UPDATE public.teams
  SET fan_count = fan_count + 1, updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('status', 'joined', 'anonymous_fan_id', v_fan_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 8) RPC: unsupport_team — leave a team's fan community
-- ======================

CREATE OR REPLACE FUNCTION unsupport_team(p_team_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_existing RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_existing
  FROM public.team_supporters
  WHERE team_id = p_team_id AND user_id = v_user_id AND is_active = true;

  IF v_existing IS NULL THEN
    RETURN jsonb_build_object('status', 'not_supporting');
  END IF;

  -- Deactivate, don't delete (preserve history)
  UPDATE public.team_supporters
  SET is_active = false
  WHERE id = v_existing.id;

  -- Decrement fan count
  UPDATE public.teams
  SET fan_count = GREATEST(fan_count - 1, 0), updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('status', 'left');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 9) RPC: contribute_fet_to_team — donate FET to a team
-- Uses the existing fet_wallets table for balance management.
-- ======================

CREATE OR REPLACE FUNCTION contribute_fet_to_team(
  p_team_id TEXT,
  p_amount_fet BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_balance BIGINT;
  v_contribution_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate amount
  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  -- Check team exists and has FET contributions enabled
  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id AND is_active = true AND fet_contributions_enabled = true
  ) THEN
    RAISE EXCEPTION 'FET contributions not enabled for this team';
  END IF;

  -- Check sender balance
  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  -- Debit sender wallet
  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Record contribution
  INSERT INTO public.team_contributions (team_id, user_id, contribution_type, amount_fet, status)
  VALUES (p_team_id, v_user_id, 'fet', p_amount_fet, 'completed')
  RETURNING id INTO v_contribution_id;

  -- Record wallet transaction
  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'contribution', 'debit', p_amount_fet,
    v_balance, v_balance - p_amount_fet,
    'team_contribution', v_contribution_id,
    'Team contribution'
  );

  RETURN jsonb_build_object(
    'status', 'completed',
    'contribution_id', v_contribution_id,
    'balance_after', v_balance - p_amount_fet
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 10) RLS POLICIES
-- ======================

ALTER TABLE public.team_supporters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_news ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_news_ingestion_runs ENABLE ROW LEVEL SECURITY;

-- team_supporters: users can read their own; public can read anonymized aggregates via RPCs
CREATE POLICY "Users read own team supporters"
  ON public.team_supporters FOR SELECT
  USING (auth.uid() = user_id);

-- For public community page queries, we use a separate RPC that only returns anonymous_fan_id
-- Direct table access is restricted to own records only.

CREATE POLICY "Users cannot directly insert supporters"
  ON public.team_supporters FOR INSERT
  WITH CHECK (false); -- Must go through support_team RPC

CREATE POLICY "Users cannot directly update supporters"
  ON public.team_supporters FOR UPDATE
  USING (false); -- Must go through RPC

CREATE POLICY "Users cannot directly delete supporters"
  ON public.team_supporters FOR DELETE
  USING (false); -- Must go through unsupport_team RPC

-- team_contributions: users read own only
CREATE POLICY "Users read own contributions"
  ON public.team_contributions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users cannot directly insert contributions"
  ON public.team_contributions FOR INSERT
  WITH CHECK (false); -- Must go through contribute_fet_to_team RPC

-- team_news: public read for published items
CREATE POLICY "Public read published team news"
  ON public.team_news FOR SELECT
  USING (status = 'published');

-- team_news write is service_role only (admin/edge functions)

-- team_news_ingestion_runs: service_role only (no direct access)
-- No SELECT policy = no public access

-- ======================
-- 11) PUBLIC VIEW: team community stats (safe for public queries)
-- ======================

CREATE OR REPLACE VIEW public.team_community_stats AS
SELECT
  t.id AS team_id,
  t.name AS team_name,
  t.fan_count,
  COALESCE(tc.total_fet_contributed, 0) AS total_fet_contributed,
  COALESCE(tc.contribution_count, 0) AS contribution_count,
  COALESCE(ts.recent_supporters, 0) AS supporters_last_30d
FROM public.teams t
LEFT JOIN (
  SELECT
    team_id,
    SUM(amount_fet) AS total_fet_contributed,
    COUNT(*) AS contribution_count
  FROM public.team_contributions
  WHERE status = 'completed' AND contribution_type = 'fet'
  GROUP BY team_id
) tc ON tc.team_id = t.id
LEFT JOIN (
  SELECT
    team_id,
    COUNT(*) AS recent_supporters
  FROM public.team_supporters
  WHERE is_active = true AND joined_at > now() - interval '30 days'
  GROUP BY team_id
) ts ON ts.team_id = t.id
WHERE t.is_active = true;

-- ======================
-- 12) PUBLIC RPC: get_team_anonymous_fans
-- Returns only anonymous_fan_id and join date for a team's active supporters.
-- Never exposes user_id or any personal data.
-- ======================

CREATE OR REPLACE FUNCTION get_team_anonymous_fans(
  p_team_id TEXT,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
) RETURNS TABLE (
  anonymous_fan_id TEXT,
  joined_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT ts.anonymous_fan_id, ts.joined_at
  FROM public.team_supporters ts
  WHERE ts.team_id = p_team_id AND ts.is_active = true
  ORDER BY ts.joined_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMIT;
