BEGIN;

DROP VIEW IF EXISTS public.matches_live_view;
CREATE VIEW public.matches_live_view AS
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
  m.live_minute,
  m.status,
  m.venue,
  m.data_source,
  m.source_url,
  m.home_logo_url,
  m.away_logo_url
FROM public.matches AS m;

GRANT SELECT ON public.matches_live_view TO anon, authenticated;

DROP FUNCTION IF EXISTS public.submit_prediction_slip(JSONB);

CREATE OR REPLACE FUNCTION public.submit_prediction_slip(
  p_selections JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_slip_id UUID;
  v_count INT;
  v_total_earn BIGINT := 0;
  v_sel JSONB;
  v_market_val TEXT;
  v_market_type_id TEXT;
  v_base_fet INT;
  v_table_exists BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_selections IS NULL OR jsonb_array_length(p_selections) = 0 THEN
    RAISE EXCEPTION 'At least one selection is required';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'prediction_slips'
  ) INTO v_table_exists;

  IF NOT v_table_exists THEN
    RAISE EXCEPTION 'Prediction slips system is not yet deployed';
  END IF;

  v_count := jsonb_array_length(p_selections);

  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections) LOOP
    v_total_earn := v_total_earn + COALESCE((v_sel->>'potential_earn_fet')::BIGINT, 0);
  END LOOP;

  INSERT INTO prediction_slips (user_id, selection_count, projected_earn_fet)
  VALUES (v_user_id, v_count, v_total_earn)
  RETURNING id INTO v_slip_id;

  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections) LOOP
    v_market_val := COALESCE(v_sel->>'market', 'match_result');
    v_market_type_id := COALESCE(v_sel->>'market_type_id', v_market_val);

    SELECT base_fet INTO v_base_fet
    FROM public.prediction_market_types
    WHERE id = v_market_type_id;

    v_base_fet := COALESCE((v_sel->>'base_fet')::INT, v_base_fet, 0);

    INSERT INTO prediction_slip_selections (
      slip_id,
      match_id,
      match_name,
      market,
      market_type_id,
      selection,
      base_fet,
      potential_earn_fet
    ) VALUES (
      v_slip_id,
      v_sel->>'match_id',
      COALESCE(v_sel->>'match_name', ''),
      v_market_val,
      NULLIF(v_market_type_id, ''),
      v_sel->>'selection',
      v_base_fet,
      COALESCE((v_sel->>'potential_earn_fet')::BIGINT, 0)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'slip_id', v_slip_id,
    'selection_count', v_count,
    'projected_earn_fet', v_total_earn
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_prediction_slip(JSONB) TO authenticated;

COMMIT;
