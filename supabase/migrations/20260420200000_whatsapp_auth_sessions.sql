BEGIN;

CREATE TABLE IF NOT EXISTS public.whatsapp_auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text NOT NULL,
  refresh_token_hash text NOT NULL UNIQUE,
  access_expires_at timestamptz NOT NULL,
  refresh_expires_at timestamptz NOT NULL,
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  revoke_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_auth_sessions_user_active
  ON public.whatsapp_auth_sessions (user_id, refresh_expires_at DESC)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_whatsapp_auth_sessions_phone_active
  ON public.whatsapp_auth_sessions (phone, refresh_expires_at DESC)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_whatsapp_auth_sessions_cleanup
  ON public.whatsapp_auth_sessions (revoked_at, refresh_expires_at, updated_at);

ALTER TABLE public.whatsapp_auth_sessions ENABLE ROW LEVEL SECURITY;

COMMIT;
