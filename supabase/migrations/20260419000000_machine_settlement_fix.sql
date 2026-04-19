-- ============================================================
-- 20260419000000_machine_settlement_fix.sql
-- Fix P0 issues for service-role execution and push-notify grants
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1) Revoke push grants from authenticated to prevent abuse
-- -----------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION send_push_to_user(UUID, TEXT, TEXT, TEXT, JSONB) FROM authenticated;
REVOKE EXECUTE ON FUNCTION notify_pool_settled(UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION notify_daily_challenge_winners(UUID) FROM authenticated;

-- -----------------------------------------------------------------
-- 2) System User for Machine Settlement
-- -----------------------------------------------------------------
INSERT INTO auth.users (id, email) 
VALUES ('00000000-0000-0000-0000-000000000000', 'system@fanzone.machine') 
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.admin_users (user_id, email, display_name, role, is_active)
VALUES ('00000000-0000-0000-0000-000000000000', 'system@fanzone.machine', 'System (Machine)', 'super_admin', true)
ON CONFLICT (user_id) DO NOTHING;

-- -----------------------------------------------------------------
-- 3) Auto-Settle Auth Fix: allow service_role to bypass admin checks
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.require_active_admin_user()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text := current_setting('request.jwt.claims', true)::jsonb->>'role';
BEGIN
  -- If invoked via service_role client (e.g. edge function), use the machine UUID
  IF coalesce(v_role, '') = 'service_role' THEN
    RETURN '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_active_admin_user(v_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN v_user_id;
END;
$$;

COMMIT;
