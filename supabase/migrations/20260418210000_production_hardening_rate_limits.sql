-- ============================================================
-- production_hardening_rate_limits.sql
-- Add rate limits to unprotected financial RPCs.
--
-- R10: Rate limit submit_daily_prediction (3 per day per user)
-- R12: Rate limit submit_prediction_slip (20 per day per user)
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- R10: Harden submit_daily_prediction with rate limit
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.submit_daily_prediction(
  p_challenge_id UUID,
  p_home_score INTEGER,
  p_away_score INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_challenge RECORD;
  v_existing RECORD;
  v_entry_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Rate limit: max 3 daily predictions per day
  IF NOT public.check_rate_limit(v_user_id, 'submit_daily_prediction', 3, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 3 daily predictions per day';
  END IF;

  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  SELECT * INTO v_challenge
  FROM public.daily_challenges
  WHERE id = p_challenge_id;

  IF v_challenge IS NULL THEN
    RAISE EXCEPTION 'Challenge not found';
  END IF;

  IF v_challenge.status <> 'active' THEN
    RAISE EXCEPTION 'Challenge is no longer active';
  END IF;

  -- Check for existing entry
  SELECT * INTO v_existing
  FROM public.daily_challenge_entries
  WHERE challenge_id = p_challenge_id
    AND user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'You have already submitted a prediction for this challenge';
  END IF;

  INSERT INTO public.daily_challenge_entries (
    challenge_id,
    user_id,
    predicted_home_score,
    predicted_away_score,
    status
  ) VALUES (
    p_challenge_id,
    v_user_id,
    p_home_score,
    p_away_score,
    'pending'
  )
  RETURNING id INTO v_entry_id;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'entry_id', v_entry_id
  );
END;
$$;

-- -----------------------------------------------------------------
-- R12: Harden submit_prediction_slip with rate limit
-- -----------------------------------------------------------------

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
  v_selection_count INTEGER;
  v_total_projected BIGINT := 0;
  v_sel RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Rate limit: max 20 prediction slips per day
  IF NOT public.check_rate_limit(v_user_id, 'submit_prediction_slip', 20, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 20 prediction slips per day';
  END IF;

  IF p_selections IS NULL OR jsonb_array_length(p_selections) = 0 THEN
    RAISE EXCEPTION 'At least one selection is required';
  END IF;

  v_selection_count := jsonb_array_length(p_selections);

  -- Calculate total projected earnings
  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections)
  LOOP
    v_total_projected := v_total_projected + coalesce((v_sel.value->>'potential_earn_fet')::bigint, 0);
  END LOOP;

  INSERT INTO public.prediction_slips (
    user_id,
    status,
    selection_count,
    projected_earn_fet,
    submitted_at,
    updated_at
  ) VALUES (
    v_user_id,
    'submitted',
    v_selection_count,
    v_total_projected,
    now(),
    now()
  )
  RETURNING id INTO v_slip_id;

  -- Insert individual selections
  INSERT INTO public.prediction_slip_selections (
    slip_id,
    match_id,
    match_name,
    market,
    selection,
    potential_earn_fet
  )
  SELECT
    v_slip_id,
    (sel->>'match_id')::text,
    coalesce(sel->>'match_name', ''),
    coalesce(sel->>'market', '1X2'),
    sel->>'selection',
    coalesce((sel->>'potential_earn_fet')::bigint, 0)
  FROM jsonb_array_elements(p_selections) AS sel;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'slip_id', v_slip_id,
    'selection_count', v_selection_count,
    'projected_earn_fet', v_total_projected
  );
END;
$$;

-- Grant to authenticated only
REVOKE ALL ON FUNCTION public.submit_daily_prediction(UUID, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_daily_prediction(UUID, INTEGER, INTEGER) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_prediction_slip(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_prediction_slip(JSONB) TO authenticated;

COMMIT;
