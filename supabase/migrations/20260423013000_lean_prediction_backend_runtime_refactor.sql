BEGIN;

-- Lean prediction runtime repair after accidental contract drops.
-- This migration keeps wallet/token logic intact, restores lean app views/RPCs,
-- hardens scoring/import flows, and removes obsolete broken backend RPCs.

-- Normalize existing match rows to the lean status/result contract.
UPDATE public.matches
SET
  match_status = public.normalize_match_status(match_status),
  result_code = public.compute_result_code(home_goals, away_goals),
  updated_at = timezone('utc', now())
WHERE
  match_status IS DISTINCT FROM public.normalize_match_status(match_status)
  OR result_code IS DISTINCT FROM public.compute_result_code(home_goals, away_goals);

-- Clean and deduplicate aliases before tightening import/runtime behavior.
UPDATE public.team_aliases
SET alias_name = btrim(alias_name)
WHERE alias_name <> btrim(alias_name);

WITH ranked_aliases AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY team_id, lower(alias_name)
      ORDER BY created_at ASC, id ASC
    ) AS rn
  FROM public.team_aliases
  WHERE btrim(coalesce(alias_name, '')) <> ''
)
DELETE FROM public.team_aliases ta
USING ranked_aliases r
WHERE ta.id = r.id
  AND r.rn > 1;

-- Wallet/runtime compatibility fixes.
DROP VIEW IF EXISTS public.fet_transactions_admin;

ALTER TABLE public.fet_wallet_transactions
  ALTER COLUMN reference_id TYPE text
  USING reference_id::text;

ALTER TABLE public.marketplace_offers
  ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS stock integer,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS terms text,
  ADD COLUMN IF NOT EXISTS valid_until timestamp with time zone,
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL;

DROP TRIGGER IF EXISTS trg_marketplace_offers_updated_at ON public.marketplace_offers;
CREATE TRIGGER trg_marketplace_offers_updated_at
BEFORE UPDATE ON public.marketplace_offers
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- Tighten canonical lean constraints.
ALTER TABLE public.team_aliases
  DROP CONSTRAINT IF EXISTS team_aliases_alias_name_not_blank;
ALTER TABLE public.team_aliases
  ADD CONSTRAINT team_aliases_alias_name_not_blank
  CHECK (btrim(alias_name) <> '');

ALTER TABLE public.matches
  DROP CONSTRAINT IF EXISTS matches_result_code_check;
ALTER TABLE public.matches
  ADD CONSTRAINT matches_result_code_check
  CHECK (
    result_code IS NULL
    OR result_code = ANY (ARRAY['H'::text, 'D'::text, 'A'::text])
  );

ALTER TABLE public.matches
  DROP CONSTRAINT IF EXISTS matches_match_status_canonical;
ALTER TABLE public.matches
  ADD CONSTRAINT matches_match_status_canonical
  CHECK (
    match_status = ANY (
      ARRAY[
        'scheduled'::text,
        'live'::text,
        'finished'::text,
        'postponed'::text,
        'cancelled'::text
      ]
    )
  );

ALTER TABLE public.matches
  DROP CONSTRAINT IF EXISTS matches_distinct_teams;
ALTER TABLE public.matches
  ADD CONSTRAINT matches_distinct_teams
  CHECK (
    home_team_id IS NULL
    OR away_team_id IS NULL
    OR home_team_id <> away_team_id
  );

ALTER TABLE public.predictions_engine_outputs
  DROP CONSTRAINT IF EXISTS predictions_engine_outputs_score_range_check;
ALTER TABLE public.predictions_engine_outputs
  ADD CONSTRAINT predictions_engine_outputs_score_range_check
  CHECK (
    home_win_score BETWEEN 0 AND 1
    AND draw_score BETWEEN 0 AND 1
    AND away_win_score BETWEEN 0 AND 1
    AND over25_score BETWEEN 0 AND 1
    AND btts_score BETWEEN 0 AND 1
  );

ALTER TABLE public.marketplace_offers
  DROP CONSTRAINT IF EXISTS marketplace_offers_stock_nonnegative;
ALTER TABLE public.marketplace_offers
  ADD CONSTRAINT marketplace_offers_stock_nonnegative
  CHECK (stock IS NULL OR stock >= 0);

CREATE INDEX IF NOT EXISTS idx_matches_status_date
  ON public.matches USING btree (match_status, match_date DESC);

CREATE INDEX IF NOT EXISTS idx_matches_competition_season_date
  ON public.matches USING btree (competition_id, season_id, match_date DESC);

CREATE INDEX IF NOT EXISTS idx_team_form_features_team_match
  ON public.team_form_features USING btree (team_id, match_id);

CREATE INDEX IF NOT EXISTS idx_user_predictions_reward_status_updated
  ON public.user_predictions USING btree (reward_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_token_rewards_match_awarded
  ON public.token_rewards USING btree (match_id, awarded_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_offers_active_sort
  ON public.marketplace_offers USING btree (is_active, sort_order, cost_fet);

CREATE VIEW public.fet_transactions_admin AS
 SELECT tx.id,
    tx.user_id,
    tx.tx_type,
    tx.direction,
    tx.amount_fet,
    tx.balance_before_fet,
    tx.balance_after_fet,
    tx.reference_type,
    tx.reference_id,
    tx.metadata,
    tx.created_at,
    tx.title,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part((COALESCE(u.email, ''::character varying))::text, '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (tx.user_id)::text) AS display_name,
    COALESCE(((tx.metadata ->> 'flagged'::text))::boolean, false) AS flagged
   FROM (public.fet_wallet_transactions tx
     LEFT JOIN auth.users u ON ((u.id = tx.user_id)))
  WHERE public.is_active_admin_operator(auth.uid());

-- Canonical compatibility refreshers.
CREATE OR REPLACE FUNCTION public.refresh_competition_derived_fields(p_competition_ids text[] DEFAULT NULL::text[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_updated integer := 0;
BEGIN
  WITH target_competitions AS (
    SELECT c.id
    FROM public.competitions c
    WHERE p_competition_ids IS NULL
       OR c.id = ANY (p_competition_ids)
  ),
  season_catalog AS (
    SELECT
      ranked.competition_id,
      array_agg(ranked.season_label ORDER BY ranked.sort_rank) AS season_labels,
      (array_agg(ranked.season_label ORDER BY ranked.sort_rank))[1] AS current_season_label
    FROM (
      SELECT
        s.competition_id,
        s.season_label,
        row_number() OVER (
          PARTITION BY s.competition_id
          ORDER BY s.is_current DESC, s.start_year DESC, s.end_year DESC, s.season_label DESC
        ) AS sort_rank
      FROM public.seasons s
      JOIN target_competitions tc
        ON tc.id = s.competition_id
    ) ranked
    GROUP BY ranked.competition_id
  ),
  team_counts AS (
    SELECT
      match_rows.competition_id,
      count(DISTINCT match_rows.team_id)::integer AS team_count
    FROM (
      SELECT m.competition_id, m.home_team_id AS team_id
      FROM public.matches m
      JOIN target_competitions tc
        ON tc.id = m.competition_id
      WHERE m.home_team_id IS NOT NULL

      UNION ALL

      SELECT m.competition_id, m.away_team_id AS team_id
      FROM public.matches m
      JOIN target_competitions tc
        ON tc.id = m.competition_id
      WHERE m.away_team_id IS NOT NULL
    ) match_rows
    GROUP BY match_rows.competition_id
  )
  UPDATE public.competitions c
  SET
    seasons = coalesce(sc.season_labels, '{}'::text[]),
    season = sc.current_season_label,
    team_count = coalesce(team_counts.team_count, 0),
    country_or_region = coalesce(
      nullif(btrim(c.country_or_region), ''),
      nullif(btrim(c.country), ''),
      nullif(btrim(c.region), ''),
      'Global'
    ),
    updated_at = timezone('utc', now())
  FROM target_competitions target
  LEFT JOIN season_catalog sc
    ON sc.competition_id = target.id
  LEFT JOIN team_counts
    ON team_counts.competition_id = target.id
  WHERE c.id = target.id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN coalesce(v_updated, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_team_derived_fields(p_team_ids text[] DEFAULT NULL::text[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_updated integer := 0;
BEGIN
  WITH target_teams AS (
    SELECT t.id
    FROM public.teams t
    WHERE p_team_ids IS NULL
       OR t.id = ANY (p_team_ids)
  ),
  alias_rows AS (
    SELECT
      deduped.team_id,
      array_agg(deduped.alias_name ORDER BY lower(deduped.alias_name), deduped.alias_name) AS aliases
    FROM (
      SELECT DISTINCT
        ta.team_id,
        btrim(ta.alias_name) AS alias_name
      FROM public.team_aliases ta
      JOIN target_teams tt
        ON tt.id = ta.team_id
      WHERE btrim(coalesce(ta.alias_name, '')) <> ''
    ) deduped
    GROUP BY deduped.team_id
  ),
  team_match_competitions AS (
    SELECT
      rows.team_id,
      rows.competition_id,
      count(*)::integer AS match_count,
      max(rows.match_date) AS last_match_date
    FROM (
      SELECT m.home_team_id AS team_id, m.competition_id, m.match_date
      FROM public.matches m
      JOIN target_teams tt
        ON tt.id = m.home_team_id
      WHERE m.home_team_id IS NOT NULL

      UNION ALL

      SELECT m.away_team_id AS team_id, m.competition_id, m.match_date
      FROM public.matches m
      JOIN target_teams tt
        ON tt.id = m.away_team_id
      WHERE m.away_team_id IS NOT NULL
    ) rows
    GROUP BY rows.team_id, rows.competition_id
  ),
  competition_rows AS (
    SELECT
      tmc.team_id,
      array_agg(tmc.competition_id ORDER BY tmc.last_match_date DESC, tmc.competition_id) AS competition_ids
    FROM team_match_competitions tmc
    GROUP BY tmc.team_id
  ),
  league_rows AS (
    SELECT DISTINCT ON (tmc.team_id)
      tmc.team_id,
      c.name AS league_name
    FROM team_match_competitions tmc
    JOIN public.competitions c
      ON c.id = tmc.competition_id
    WHERE coalesce(c.competition_type, 'league') = 'league'
    ORDER BY tmc.team_id, tmc.match_count DESC, tmc.last_match_date DESC, c.name
  )
  UPDATE public.teams t
  SET
    aliases = coalesce(alias_rows.aliases, '{}'::text[]),
    competition_ids = coalesce(competition_rows.competition_ids, '{}'::text[]),
    league_name = coalesce(league_rows.league_name, t.league_name),
    updated_at = timezone('utc', now())
  FROM target_teams target
  LEFT JOIN alias_rows
    ON alias_rows.team_id = target.id
  LEFT JOIN competition_rows
    ON competition_rows.team_id = target.id
  LEFT JOIN league_rows
    ON league_rows.team_id = target.id
  WHERE t.id = target.id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN coalesce(v_updated, 0);
END;
$$;

-- Lean app-facing compatibility interfaces restored on top of the normalized model.
CREATE OR REPLACE VIEW public.team_catalog_entries AS
 SELECT
    t.id,
    t.name,
    COALESCE(NULLIF(TRIM(BOTH FROM t.short_name), ''), t.name) AS short_name,
    public.safe_catalog_key(COALESCE(NULLIF(TRIM(BOTH FROM t.short_name), ''), t.name)) AS slug,
    t.country,
    t.country_code,
    t.region,
    t.league_name,
    t.logo_url,
    t.crest_url,
    t.cover_image_url,
    t.description,
    t.search_terms,
    COALESCE(alias_rows.aliases, '{}'::text[]) AS aliases,
    COALESCE(competition_rows.competition_ids, '{}'::text[]) AS competition_ids,
    t.is_active,
    t.is_featured,
    t.is_popular_pick,
    t.popular_pick_rank,
    t.fan_count,
    t.team_type,
    t.created_at,
    t.updated_at
   FROM public.teams t
   LEFT JOIN LATERAL (
     SELECT array_agg(alias_rows.alias_name ORDER BY lower(alias_rows.alias_name), alias_rows.alias_name) AS aliases
     FROM (
       SELECT DISTINCT btrim(ta.alias_name) AS alias_name
       FROM public.team_aliases ta
       WHERE ta.team_id = t.id
         AND btrim(coalesce(ta.alias_name, '')) <> ''
     ) alias_rows
   ) alias_rows ON true
   LEFT JOIN LATERAL (
     SELECT array_agg(distinct_rows.competition_id ORDER BY distinct_rows.last_match_date DESC, distinct_rows.competition_id) AS competition_ids
     FROM (
       SELECT
         rows.competition_id,
         max(rows.match_date) AS last_match_date
       FROM (
         SELECT m.competition_id, m.match_date
         FROM public.matches m
         WHERE m.home_team_id = t.id

         UNION ALL

         SELECT m.competition_id, m.match_date
         FROM public.matches m
         WHERE m.away_team_id = t.id
       ) rows
       GROUP BY rows.competition_id
     ) distinct_rows
   ) competition_rows ON true;

CREATE OR REPLACE FUNCTION public.app_competition_teams(p_competition_id text) RETURNS SETOF public.team_catalog_entries
    LANGUAGE sql STABLE
    AS $$
  SELECT *
  FROM public.team_catalog_entries
  WHERE is_active = true
    AND (
      p_competition_id IS NULL
      OR p_competition_id = ''
      OR competition_ids @> ARRAY[p_competition_id]::text[]
    )
  ORDER BY
    is_popular_pick DESC,
    popular_pick_rank NULLS LAST,
    name;
$$;

CREATE OR REPLACE VIEW public.matches_live_view AS
 SELECT
    am.id,
    am.competition_id,
    am.competition_name,
    am.season_id,
    am.season_label,
    am.stage,
    am.round,
    am.matchday_or_round,
    am.match_date,
    am.date,
    am.kickoff_time,
    am.home_team_id,
    am.home_team,
    am.home_logo_url,
    am.away_team_id,
    am.away_team,
    am.away_logo_url,
    am.ft_home,
    am.ft_away,
    am.home_goals,
    am.away_goals,
    am.result_code,
    am.status,
    am.match_status,
    am.is_neutral,
    am.data_source,
    am.source_name,
    am.source_url,
    am.notes,
    am.created_at,
    am.updated_at,
    m.live_home_score,
    m.live_away_score,
    m.live_minute,
    m.live_phase,
    m.last_live_checked_at,
    m.last_live_sync_confidence,
    m.last_live_review_required
   FROM public.app_matches am
   JOIN public.matches m
     ON m.id = am.id
  WHERE m.match_status = 'live';

CREATE OR REPLACE FUNCTION public.get_live_matches() RETURNS SETOF public.matches_live_view
    LANGUAGE sql STABLE
    AS $$
  SELECT *
  FROM public.matches_live_view
  ORDER BY match_date ASC, id ASC;
$$;

-- Lean current-season resolver on normalized tables.
CREATE OR REPLACE FUNCTION public.get_competition_current_season(p_competition_id text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
DECLARE
  v_season_label text;
BEGIN
  IF p_competition_id IS NULL OR btrim(p_competition_id) = '' THEN
    RETURN NULL;
  END IF;

  SELECT s.season_label
  INTO v_season_label
  FROM public.seasons s
  WHERE s.competition_id = p_competition_id
  ORDER BY s.is_current DESC, s.end_year DESC, s.start_year DESC, s.season_label DESC
  LIMIT 1;

  IF v_season_label IS NOT NULL THEN
    RETURN v_season_label;
  END IF;

  SELECT s.season_label
  INTO v_season_label
  FROM public.matches m
  JOIN public.seasons s
    ON s.id = m.season_id
  WHERE m.competition_id = p_competition_id
  ORDER BY
    CASE m.match_status
      WHEN 'live' THEN 0
      WHEN 'scheduled' THEN 1
      WHEN 'finished' THEN 2
      ELSE 3
    END,
    m.match_date DESC
  LIMIT 1;

  RETURN v_season_label;
END;
$$;

-- Batch generators for imports and manual repair flows.
CREATE OR REPLACE FUNCTION public.generate_team_form_features_for_matches(p_match_ids text[] DEFAULT NULL::text[], p_limit integer DEFAULT 250) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  IF coalesce(array_length(p_match_ids, 1), 0) > 0 THEN
    FOR rec IN
      SELECT m.id
      FROM public.matches m
      WHERE m.id = ANY (p_match_ids)
      ORDER BY m.match_date ASC, m.id ASC
    LOOP
      PERFORM public.refresh_team_form_features_for_match(rec.id);
      v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
  END IF;

  FOR rec IN
    SELECT m.id
    FROM public.matches m
    WHERE m.match_status IN ('scheduled', 'live', 'finished')
    ORDER BY m.match_date ASC, m.id ASC
    LIMIT greatest(1, coalesce(p_limit, 250))
  LOOP
    PERFORM public.refresh_team_form_features_for_match(rec.id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_predictions_for_matches(p_match_ids text[] DEFAULT NULL::text[], p_limit integer DEFAULT 250, p_model_version text DEFAULT 'simple_form_v1'::text, p_include_finished boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  IF coalesce(array_length(p_match_ids, 1), 0) > 0 THEN
    FOR rec IN
      SELECT m.id
      FROM public.matches m
      WHERE m.id = ANY (p_match_ids)
        AND (
          p_include_finished
          OR m.match_status IN ('scheduled', 'live')
        )
      ORDER BY m.match_date ASC, m.id ASC
    LOOP
      PERFORM public.generate_prediction_engine_output(rec.id, p_model_version);
      v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
  END IF;

  FOR rec IN
    SELECT m.id
    FROM public.matches m
    WHERE m.match_status IN ('scheduled', 'live')
      AND m.match_date >= now() - interval '6 hours'
    ORDER BY m.match_date ASC, m.id ASC
    LIMIT greatest(1, coalesce(p_limit, 250))
  LOOP
    PERFORM public.generate_prediction_engine_output(rec.id, p_model_version);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_predictions_for_upcoming_matches(p_limit integer DEFAULT 50) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN public.generate_predictions_for_matches(
    NULL::text[],
    greatest(1, coalesce(p_limit, 50)),
    'simple_form_v1',
    false
  );
END;
$$;

-- Prediction submission hardening.
CREATE OR REPLACE FUNCTION public.submit_user_prediction(p_match_id text, p_predicted_result_code text DEFAULT NULL::text, p_predicted_over25 boolean DEFAULT NULL::boolean, p_predicted_btts boolean DEFAULT NULL::boolean, p_predicted_home_goals integer DEFAULT NULL::integer, p_predicted_away_goals integer DEFAULT NULL::integer) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_match record;
  v_prediction_id uuid;
  v_result_code text;
  v_score_result_code text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id, match_date, match_status
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  IF v_match.match_date <= now() OR v_match.match_status <> 'scheduled' THEN
    RAISE EXCEPTION 'Predictions are closed for this match';
  END IF;

  v_result_code := CASE
    WHEN p_predicted_result_code IS NULL OR trim(p_predicted_result_code) = '' THEN NULL
    ELSE upper(trim(p_predicted_result_code))
  END;

  IF v_result_code IS NOT NULL AND v_result_code NOT IN ('H', 'D', 'A') THEN
    RAISE EXCEPTION 'predicted_result_code must be H, D, or A';
  END IF;

  IF (p_predicted_home_goals IS NULL) <> (p_predicted_away_goals IS NULL) THEN
    RAISE EXCEPTION 'predicted_home_goals and predicted_away_goals must be provided together';
  END IF;

  IF p_predicted_home_goals IS NOT NULL AND p_predicted_home_goals < 0 THEN
    RAISE EXCEPTION 'predicted_home_goals must be non-negative';
  END IF;

  IF p_predicted_away_goals IS NOT NULL AND p_predicted_away_goals < 0 THEN
    RAISE EXCEPTION 'predicted_away_goals must be non-negative';
  END IF;

  IF p_predicted_home_goals IS NOT NULL AND p_predicted_away_goals IS NOT NULL THEN
    v_score_result_code := public.compute_result_code(
      p_predicted_home_goals,
      p_predicted_away_goals
    );

    IF v_result_code IS NULL THEN
      v_result_code := v_score_result_code;
    ELSIF v_result_code <> v_score_result_code THEN
      RAISE EXCEPTION 'predicted_result_code must match the supplied exact score';
    END IF;
  END IF;

  IF v_result_code IS NULL
    AND p_predicted_over25 IS NULL
    AND p_predicted_btts IS NULL
    AND p_predicted_home_goals IS NULL
    AND p_predicted_away_goals IS NULL
  THEN
    RAISE EXCEPTION 'At least one prediction input is required';
  END IF;

  INSERT INTO public.user_predictions (
    user_id,
    match_id,
    predicted_result_code,
    predicted_over25,
    predicted_btts,
    predicted_home_goals,
    predicted_away_goals,
    points_awarded,
    reward_status,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_match_id,
    v_result_code,
    p_predicted_over25,
    p_predicted_btts,
    p_predicted_home_goals,
    p_predicted_away_goals,
    0,
    'pending',
    now(),
    now()
  )
  ON CONFLICT (user_id, match_id) DO UPDATE SET
    predicted_result_code = EXCLUDED.predicted_result_code,
    predicted_over25 = EXCLUDED.predicted_over25,
    predicted_btts = EXCLUDED.predicted_btts,
    predicted_home_goals = EXCLUDED.predicted_home_goals,
    predicted_away_goals = EXCLUDED.predicted_away_goals,
    points_awarded = 0,
    reward_status = 'pending',
    updated_at = now()
  RETURNING id INTO v_prediction_id;

  RETURN v_prediction_id;
END;
$$;

-- Safe settlement flow: only process pending predictions, never silently re-credit.
CREATE OR REPLACE FUNCTION public.score_user_predictions_for_match(p_match_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_match record;
  v_processed integer := 0;
  v_rewards integer := 0;
  rec record;
  v_points integer;
  v_reward bigint;
  v_inserted_reward_id uuid;
BEGIN
  SELECT *
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  IF v_match.match_status <> 'finished'
    OR v_match.home_goals IS NULL
    OR v_match.away_goals IS NULL
  THEN
    RAISE EXCEPTION 'Match % is not finished', p_match_id;
  END IF;

  FOR rec IN
    SELECT *
    FROM public.user_predictions
    WHERE match_id = p_match_id
      AND reward_status = 'pending'
  LOOP
    v_points := 0;

    IF rec.predicted_result_code IS NOT NULL
      AND rec.predicted_result_code = v_match.result_code
    THEN
      v_points := v_points + 3;
    END IF;

    IF rec.predicted_over25 IS NOT NULL
      AND rec.predicted_over25 = ((v_match.home_goals + v_match.away_goals) > 2)
    THEN
      v_points := v_points + 1;
    END IF;

    IF rec.predicted_btts IS NOT NULL
      AND rec.predicted_btts = (v_match.home_goals > 0 AND v_match.away_goals > 0)
    THEN
      v_points := v_points + 1;
    END IF;

    IF rec.predicted_home_goals IS NOT NULL
      AND rec.predicted_away_goals IS NOT NULL
      AND rec.predicted_home_goals = v_match.home_goals
      AND rec.predicted_away_goals = v_match.away_goals
    THEN
      v_points := v_points + 2;
    END IF;

    v_reward := CASE
      WHEN v_points >= 7 THEN 40
      WHEN v_points >= 5 THEN 20
      WHEN v_points >= 3 THEN 10
      ELSE 0
    END;

    UPDATE public.user_predictions
    SET
      points_awarded = v_points,
      reward_status = CASE WHEN v_reward > 0 THEN 'awarded' ELSE 'no_reward' END,
      updated_at = now()
    WHERE id = rec.id;

    IF v_reward > 0 THEN
      INSERT INTO public.token_rewards (
        user_id,
        user_prediction_id,
        match_id,
        reward_type,
        token_amount,
        status,
        awarded_at,
        created_at
      )
      VALUES (
        rec.user_id,
        rec.id,
        p_match_id,
        'prediction_reward',
        v_reward,
        'awarded',
        now(),
        now()
      )
      ON CONFLICT (user_prediction_id, reward_type) DO NOTHING
      RETURNING id INTO v_inserted_reward_id;

      IF v_inserted_reward_id IS NOT NULL THEN
        INSERT INTO public.fet_wallets (
          user_id,
          available_balance_fet,
          locked_balance_fet,
          created_at,
          updated_at
        )
        VALUES (rec.user_id, 0, 0, now(), now())
        ON CONFLICT (user_id) DO NOTHING;

        UPDATE public.fet_wallets
        SET
          available_balance_fet = available_balance_fet + v_reward,
          updated_at = now()
        WHERE user_id = rec.user_id;

        INSERT INTO public.fet_wallet_transactions (
          user_id,
          tx_type,
          direction,
          amount_fet,
          balance_before_fet,
          balance_after_fet,
          reference_type,
          reference_id,
          metadata,
          title,
          created_at
        )
        SELECT
          w.user_id,
          'prediction_reward',
          'credit',
          v_reward,
          greatest(w.available_balance_fet - v_reward, 0),
          w.available_balance_fet,
          'user_prediction',
          rec.id::text,
          jsonb_build_object(
            'match_id', p_match_id,
            'points_awarded', v_points
          ),
          'Prediction reward',
          now()
        FROM public.fet_wallets w
        WHERE w.user_id = rec.user_id;

        v_rewards := v_rewards + 1;
      END IF;
    END IF;

    v_processed := v_processed + 1;
    v_inserted_reward_id := NULL;
  END LOOP;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'processed_predictions', v_processed,
    'awarded_rewards', v_rewards
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_requires_reward_review boolean := false;
  v_scoring_result jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.matches
  SET
    home_goals = p_home_goals,
    away_goals = p_away_goals,
    match_status = 'finished',
    updated_at = now()
  WHERE id = p_match_id;

  PERFORM public.refresh_team_form_features_for_match(p_match_id);
  PERFORM public.generate_prediction_engine_output(p_match_id);

  SELECT EXISTS (
    SELECT 1
    FROM public.user_predictions up
    WHERE up.match_id = p_match_id
      AND up.reward_status <> 'pending'
  )
  INTO v_requires_reward_review;

  IF v_requires_reward_review THEN
    v_scoring_result := jsonb_build_object(
      'match_id', p_match_id,
      'processed_predictions', 0,
      'awarded_rewards', 0,
      'reward_reconciliation_required', true
    );
  ELSE
    v_scoring_result := public.score_user_predictions_for_match(p_match_id);
  END IF;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'home_goals', p_home_goals,
    'away_goals', p_away_goals,
    'reward_reconciliation_required', v_requires_reward_review,
    'scoring', v_scoring_result
  );
END;
$$;

-- Wallet offer redemption aligned to text IDs and current marketplace schema.
DROP FUNCTION IF EXISTS public.redeem_offer(uuid);

CREATE OR REPLACE FUNCTION public.redeem_offer(p_offer_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_offer record;
  v_balance bigint;
  v_redemption_id uuid;
  v_delivery_value text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_user_id);

  SELECT *
  INTO v_offer
  FROM public.marketplace_offers
  WHERE id = p_offer_id
    AND is_active = true
  FOR UPDATE;

  IF v_offer IS NULL THEN
    RAISE EXCEPTION 'Offer not found or inactive';
  END IF;

  IF v_offer.stock IS NOT NULL AND v_offer.stock <= 0 THEN
    RAISE EXCEPTION 'Offer is out of stock';
  END IF;

  IF v_offer.valid_until IS NOT NULL AND v_offer.valid_until < now() THEN
    RAISE EXCEPTION 'Offer has expired';
  END IF;

  SELECT available_balance_fet
  INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_offer.cost_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET
    available_balance_fet = available_balance_fet - v_offer.cost_fet,
    updated_at = now()
  WHERE user_id = v_user_id;

  IF v_offer.stock IS NOT NULL THEN
    UPDATE public.marketplace_offers
    SET stock = stock - 1
    WHERE id = p_offer_id;
  END IF;

  v_delivery_value := 'FZ-' || upper(substring(gen_random_uuid()::text FROM 1 FOR 8));

  INSERT INTO public.marketplace_redemptions (
    offer_id,
    user_id,
    cost_fet,
    delivery_type,
    delivery_value,
    status
  )
  VALUES (
    p_offer_id,
    v_user_id,
    v_offer.cost_fet,
    v_offer.delivery_type,
    v_delivery_value,
    'fulfilled'
  )
  RETURNING id INTO v_redemption_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  )
  VALUES (
    v_user_id,
    'redemption',
    'debit',
    v_offer.cost_fet,
    v_balance,
    v_balance - v_offer.cost_fet,
    'marketplace_redemption',
    v_redemption_id::text,
    'Redeemed: ' || v_offer.title
  );

  RETURN jsonb_build_object(
    'status', 'fulfilled',
    'redemption_id', v_redemption_id,
    'delivery_type', v_offer.delivery_type,
    'delivery_value', v_delivery_value,
    'balance_after', v_balance - v_offer.cost_fet
  );
END;
$$;

-- Admin dashboard KPIs aligned to the lean prediction + wallet runtime.
CREATE OR REPLACE FUNCTION public.admin_dashboard_kpis() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_active_users bigint := 0;
  v_open_prediction_matches bigint := 0;
  v_total_fet_issued numeric := 0;
  v_fet_transferred_24h bigint := 0;
  v_pending_rewards bigint := 0;
  v_moderation_alerts bigint := 0;
  v_competitions_count bigint := 0;
  v_upcoming_fixtures bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  SELECT count(*)::bigint
  INTO v_active_users
  FROM auth.users
  WHERE last_sign_in_at >= timezone('utc', now()) - interval '30 days';

  SELECT count(*)::bigint
  INTO v_open_prediction_matches
  FROM public.matches
  WHERE match_status IN ('scheduled', 'live');

  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(total_supply, 0) FROM public.fet_supply_overview'
    INTO v_total_fet_issued;
  END IF;

  SELECT coalesce(sum(amount_fet)::bigint, 0)
  INTO v_fet_transferred_24h
  FROM public.fet_wallet_transactions
  WHERE direction = 'debit'
    AND tx_type IN ('transfer', 'transfer_fet')
    AND created_at >= timezone('utc', now()) - interval '24 hours';

  SELECT count(*)::bigint
  INTO v_pending_rewards
  FROM public.user_predictions up
  JOIN public.matches m
    ON m.id = up.match_id
  WHERE up.reward_status = 'pending'
    AND m.match_status = 'finished';

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    SELECT coalesce(count(*)::bigint, 0)
    INTO v_moderation_alerts
    FROM public.moderation_reports
    WHERE status IN ('open', 'investigating', 'escalated');
  END IF;

  SELECT count(*)::bigint
  INTO v_competitions_count
  FROM public.competitions
  WHERE coalesce(is_active, true) = true;

  SELECT count(*)::bigint
  INTO v_upcoming_fixtures
  FROM public.matches
  WHERE match_status IN ('scheduled', 'live');

  RETURN jsonb_build_object(
    'activeUsers', coalesce(v_active_users, 0),
    'openPredictionMatches', coalesce(v_open_prediction_matches, 0),
    'totalFetIssued', coalesce(v_total_fet_issued, 0),
    'fetTransferred24h', coalesce(v_fet_transferred_24h, 0),
    'pendingRewards', coalesce(v_pending_rewards, 0),
    'moderationAlerts', coalesce(v_moderation_alerts, 0),
    'competitionsCount', coalesce(v_competitions_count, 0),
    'upcomingFixtures', coalesce(v_upcoming_fixtures, 0)
  );
END;
$$;

-- Drop obsolete/broken backend functions that still referenced removed legacy tables.
DROP FUNCTION IF EXISTS public.admin_approve_partner(uuid);
DROP FUNCTION IF EXISTS public.admin_create_campaign(text, text, text, jsonb, timestamp with time zone);
DROP FUNCTION IF EXISTS public.admin_delete_banner(uuid);
DROP FUNCTION IF EXISTS public.admin_delete_campaign(uuid);
DROP FUNCTION IF EXISTS public.admin_reject_partner(uuid, text);
DROP FUNCTION IF EXISTS public.admin_send_campaign(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_set_partner_featured(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_set_reward_active(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_set_reward_featured(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_update_campaign_status(uuid, text);
DROP FUNCTION IF EXISTS public.normalize_match_status_before_write();
DROP FUNCTION IF EXISTS public.redeem_reward(uuid);
DROP FUNCTION IF EXISTS public.refresh_crowd_predictions();
DROP FUNCTION IF EXISTS public.sync_match_logos_from_teams();

-- Backfill compatibility fields from normalized source-of-truth tables.
SELECT public.refresh_competition_derived_fields(NULL);
SELECT public.refresh_team_derived_fields(NULL);

COMMIT;
