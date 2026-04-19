BEGIN;

CREATE OR REPLACE FUNCTION public.require_admin_manager_user()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := public.require_active_admin_user();

  IF NOT public.is_admin_manager(v_user_id) THEN
    RAISE EXCEPTION 'Admin manager role required';
  END IF;

  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.active_admin_record_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_admin_record_id uuid;
BEGIN
  v_user_id := public.require_active_admin_user();

  SELECT id
  INTO v_admin_record_id
  FROM public.admin_users
  WHERE user_id = v_user_id
    AND is_active = true
  LIMIT 1;

  IF v_admin_record_id IS NULL THEN
    RAISE EXCEPTION 'Active admin record not found';
  END IF;

  RETURN v_admin_record_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_feature_flag(
  p_flag_id uuid,
  p_is_enabled boolean
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

  SELECT to_jsonb(flag)
  INTO v_before
  FROM public.admin_feature_flags flag
  WHERE flag.id = p_flag_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Feature flag not found';
  END IF;

  UPDATE public.admin_feature_flags
  SET is_enabled = p_is_enabled,
      updated_by = v_admin_record_id,
      updated_at = timezone('utc', now())
  WHERE id = p_flag_id;

  SELECT to_jsonb(flag)
  INTO v_after
  FROM public.admin_feature_flags flag
  WHERE flag.id = p_flag_id;

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
    'toggle_feature_flag',
    'settings',
    'feature_flag',
    p_flag_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_enabled', p_is_enabled)
  );

  RETURN jsonb_build_object(
    'id', p_flag_id,
    'is_enabled', p_is_enabled
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_reward_active(
  p_reward_id uuid,
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

  SELECT to_jsonb(reward)
  INTO v_before
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Reward not found';
  END IF;

  UPDATE public.rewards
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_reward_id;

  SELECT to_jsonb(reward)
  INTO v_after
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

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
    'toggle_reward_active',
    'rewards',
    'reward',
    p_reward_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_reward_id,
    'is_active', p_is_active
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_reward_featured(
  p_reward_id uuid,
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

  SELECT to_jsonb(reward)
  INTO v_before
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Reward not found';
  END IF;

  UPDATE public.rewards
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_reward_id;

  SELECT to_jsonb(reward)
  INTO v_after
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

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
    'toggle_reward_featured',
    'rewards',
    'reward',
    p_reward_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_reward_id,
    'is_featured', p_is_featured
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_banner_active(
  p_banner_id uuid,
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

  SELECT to_jsonb(banner)
  INTO v_before
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Banner not found';
  END IF;

  UPDATE public.content_banners
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_banner_id;

  SELECT to_jsonb(banner)
  INTO v_after
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

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
    'toggle_banner_active',
    'content',
    'banner',
    p_banner_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_banner_id,
    'is_active', p_is_active
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_banner(p_banner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(banner)
  INTO v_before
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Banner not found';
  END IF;

  DELETE FROM public.content_banners
  WHERE id = p_banner_id;

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
    'delete_banner',
    'content',
    'banner',
    p_banner_id::text,
    v_before,
    NULL,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('id', p_banner_id, 'deleted', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_moderation_report_status(
  p_report_id uuid,
  p_status text,
  p_resolution_notes text DEFAULT NULL
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
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(report)
  INTO v_before
  FROM public.moderation_reports report
  WHERE report.id = p_report_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Moderation report not found';
  END IF;

  UPDATE public.moderation_reports
  SET status = p_status,
      resolution_notes = COALESCE(NULLIF(trim(p_resolution_notes), ''), resolution_notes),
      assigned_to = COALESCE(assigned_to, v_admin_record_id),
      updated_at = timezone('utc', now())
  WHERE id = p_report_id;

  SELECT to_jsonb(report)
  INTO v_after
  FROM public.moderation_reports report
  WHERE report.id = p_report_id;

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
    'update_report_status',
    'moderation',
    'report',
    p_report_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object('id', p_report_id, 'status', p_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_campaign(
  p_title text,
  p_message text,
  p_type text,
  p_segment jsonb DEFAULT '{}'::jsonb,
  p_scheduled_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  INSERT INTO public.campaigns (
    title,
    message,
    type,
    segment,
    status,
    scheduled_at,
    country,
    created_by,
    updated_at
  ) VALUES (
    p_title,
    p_message,
    p_type,
    COALESCE(p_segment, '{}'::jsonb),
    CASE WHEN p_scheduled_at IS NULL THEN 'draft' ELSE 'scheduled' END,
    p_scheduled_at,
    'MT',
    v_admin_record_id,
    timezone('utc', now())
  )
  RETURNING * INTO v_campaign;

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
    'create_campaign',
    'notifications',
    'campaign',
    v_campaign.id::text,
    NULL,
    to_jsonb(v_campaign),
    jsonb_build_object('scheduled', p_scheduled_at IS NOT NULL)
  );

  RETURN jsonb_build_object(
    'id', v_campaign.id,
    'status', v_campaign.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_campaign_status(
  p_campaign_id uuid,
  p_status text
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

  SELECT to_jsonb(campaign)
  INTO v_before
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  UPDATE public.campaigns
  SET status = p_status,
      sent_at = CASE
        WHEN p_status = 'sent' AND sent_at IS NULL THEN timezone('utc', now())
        ELSE sent_at
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_campaign_id;

  SELECT to_jsonb(campaign)
  INTO v_after
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

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
    'update_campaign_status',
    'notifications',
    'campaign',
    p_campaign_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object('id', p_campaign_id, 'status', p_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_campaign(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(campaign)
  INTO v_before
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;

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
    'delete_campaign',
    'notifications',
    'campaign',
    p_campaign_id::text,
    v_before,
    NULL,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('id', p_campaign_id, 'deleted', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.require_admin_manager_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_admin_record_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_reward_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_reward_featured(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_banner_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_banner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_moderation_report_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_campaign(text, text, text, jsonb, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_campaign_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_campaign(uuid) TO authenticated;

COMMIT;
