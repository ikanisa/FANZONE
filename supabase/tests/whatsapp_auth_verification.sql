\pset tuples_only on
\pset pager off

\echo 'Verifying WhatsApp-only auth contract...'

DO $$
DECLARE
  grant_access_def text;
BEGIN
  IF to_regclass('public.otp_verifications') IS NULL THEN
    RAISE EXCEPTION 'Missing public.otp_verifications table';
  END IF;

  IF to_regclass('public.whatsapp_auth_sessions') IS NULL THEN
    RAISE EXCEPTION 'Missing public.whatsapp_auth_sessions table';
  END IF;

  IF to_regprocedure('public.find_auth_user_by_phone(text)') IS NULL THEN
    RAISE EXCEPTION 'Missing public.find_auth_user_by_phone(text) RPC';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'admin_users'
      AND column_name = 'phone'
  ) THEN
    RAISE EXCEPTION 'admin_users.phone column is required for WhatsApp-only admin access';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_admin_users_email'
  ) THEN
    RAISE EXCEPTION 'Legacy admin email index still exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_admin_users_phone'
  ) THEN
    RAISE EXCEPTION 'Missing idx_admin_users_phone index';
  END IF;

  SELECT pg_get_functiondef('public.admin_grant_access(text,text)'::regprocedure)
  INTO grant_access_def;

  IF grant_access_def IS NULL THEN
    RAISE EXCEPTION 'Missing public.admin_grant_access(text,text) RPC';
  END IF;

  IF grant_access_def LIKE '%p_email%' THEN
    RAISE EXCEPTION 'admin_grant_access still references email-based provisioning';
  END IF;

  IF grant_access_def NOT LIKE '%p_phone%' THEN
    RAISE EXCEPTION 'admin_grant_access is not parameterized by phone';
  END IF;
END;
$$;

\echo 'WhatsApp-only auth contract verified'
