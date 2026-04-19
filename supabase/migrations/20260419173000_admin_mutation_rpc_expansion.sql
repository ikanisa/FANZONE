BEGIN;

CREATE OR REPLACE FUNCTION public.admin_set_competition_featured(
  p_competition_id text,
  p_is_featured boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(competition)
  INTO v_before
  FROM public.competitions competition
  WHERE competition.id = p_competition_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Competition not found';
  END IF;

  UPDATE public.competitions
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_competition_id;

  SELECT to_jsonb(competition)
  INTO v_after
  FROM public.competitions competition
  WHERE competition.id = p_competition_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'toggle_competition_featured',
    'competitions',
    'competition',
    p_competition_id,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_competition_id,
    'is_featured', p_is_featured
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_match_result(
  p_match_id text,
  p_ft_home integer,
  p_ft_away integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  IF p_ft_home < 0 OR p_ft_away < 0 THEN
    RAISE EXCEPTION 'Match scores must be zero or greater';
  END IF;

  SELECT to_jsonb(match_row)
  INTO v_before
  FROM public.matches match_row
  WHERE match_row.id = p_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  UPDATE public.matches
  SET ft_home = p_ft_home,
      ft_away = p_ft_away,
      status = 'finished',
      updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  SELECT to_jsonb(match_row)
  INTO v_after
  FROM public.matches match_row
  WHERE match_row.id = p_match_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'update_match_result',
    'fixtures',
    'match',
    p_match_id,
    v_before,
    v_after,
    jsonb_build_object(
      'ft_home', p_ft_home,
      'ft_away', p_ft_away
    )
  );

  RETURN jsonb_build_object(
    'id', p_match_id,
    'ft_home', p_ft_home,
    'ft_away', p_ft_away,
    'status', 'finished'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_auto_settle_match(
  p_match_id text,
  p_home_score integer,
  p_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_result jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(match_row)
  INTO v_before
  FROM public.matches match_row
  WHERE match_row.id = p_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  v_result := public.auto_settle_pools(
    p_match_id,
    p_home_score,
    p_away_score
  );

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'auto_settle_match',
    'fixtures',
    'match',
    p_match_id,
    v_before,
    NULL,
    jsonb_build_object(
      'home_score', p_home_score,
      'away_score', p_away_score,
      'result', v_result
    )
  );

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_approve_partner(p_partner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(partner)
  INTO v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE public.partners
  SET status = 'approved',
      approved_by = v_admin_record_id,
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'approve_partner',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', 'approved')
  );

  RETURN jsonb_build_object('id', p_partner_id, 'status', 'approved');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_partner(
  p_partner_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_reason text := nullif(trim(p_reason), '');
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'Rejection reason is required';
  END IF;

  SELECT to_jsonb(partner)
  INTO v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE public.partners
  SET status = 'rejected',
      approved_by = NULL,
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('rejection_reason', v_reason),
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'reject_partner',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('reason', v_reason)
  );

  RETURN jsonb_build_object(
    'id', p_partner_id,
    'status', 'rejected',
    'reason', v_reason
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_partner_featured(
  p_partner_id uuid,
  p_is_featured boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_current_status text;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT status, to_jsonb(partner)
  INTO v_current_status, v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  IF p_is_featured AND v_current_status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved partners can be featured';
  END IF;

  UPDATE public.partners
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'toggle_partner_featured',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_partner_id,
    'is_featured', p_is_featured
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_featured_event_active(
  p_event_id uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(event_row)
  INTO v_before
  FROM public.featured_events event_row
  WHERE event_row.id = p_event_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Featured event not found';
  END IF;

  UPDATE public.featured_events
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_event_id;

  SELECT to_jsonb(event_row)
  INTO v_after
  FROM public.featured_events event_row
  WHERE event_row.id = p_event_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'toggle_featured_event_active',
    'events',
    'featured_event',
    p_event_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_event_id,
    'is_active', p_is_active
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_account_deletion_request(
  p_request_id uuid,
  p_status text,
  p_resolution_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_user_id uuid;
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_resolution_notes text := nullif(trim(p_resolution_notes), '');
BEGIN
  v_admin_user_id := public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(request_row)
  INTO v_before
  FROM public.account_deletion_requests request_row
  WHERE request_row.id = p_request_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Account deletion request not found';
  END IF;

  UPDATE public.account_deletion_requests
  SET status = p_status,
      resolution_notes = v_resolution_notes,
      processed_at = CASE
        WHEN p_status = 'pending' THEN NULL
        ELSE timezone('utc', now())
      END,
      processed_by = CASE
        WHEN p_status = 'pending' THEN NULL
        ELSE v_admin_user_id
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_request_id;

  SELECT to_jsonb(request_row)
  INTO v_after
  FROM public.account_deletion_requests request_row
  WHERE request_row.id = p_request_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'update_account_deletion_request',
    'account_deletions',
    'account_deletion_request',
    p_request_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object(
    'id', p_request_id,
    'status', p_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_competition_featured(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_match_result(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_auto_settle_match(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_partner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_partner(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_partner_featured(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_featured_event_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_account_deletion_request(uuid, text, text) TO authenticated;

COMMIT;
