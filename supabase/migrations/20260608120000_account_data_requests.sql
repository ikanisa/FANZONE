-- Account data access and correction requests for privacy support.
-- Requests are support-reviewed and do not expose account data directly to the app.

CREATE TABLE IF NOT EXISTS public.account_data_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_type text NOT NULL DEFAULT 'export',
  status text NOT NULL DEFAULT 'pending',
  reason text NOT NULL,
  contact_email text,
  resolution_notes text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processed_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT account_data_requests_type_check CHECK (
    request_type IN ('export', 'correction')
  ),
  CONSTRAINT account_data_requests_status_check CHECK (
    status IN ('pending', 'in_review', 'completed', 'rejected', 'cancelled')
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_data_requests_pending_unique
  ON public.account_data_requests (user_id, request_type)
  WHERE status IN ('pending', 'in_review');

CREATE INDEX IF NOT EXISTS idx_account_data_requests_user
  ON public.account_data_requests (user_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_account_data_requests_status
  ON public.account_data_requests (status, requested_at DESC);

ALTER TABLE public.account_data_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_data_requests'
      AND policyname = 'Admins manage account data requests'
  ) THEN
    CREATE POLICY "Admins manage account data requests"
      ON public.account_data_requests
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()));
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_data_requests'
      AND policyname = 'Users read own account data requests'
  ) THEN
    CREATE POLICY "Users read own account data requests"
      ON public.account_data_requests
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_data_requests'
      AND policyname = 'Users create own account data requests'
  ) THEN
    CREATE POLICY "Users create own account data requests"
      ON public.account_data_requests
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        AND status = 'pending'
        AND request_type IN ('export', 'correction')
        AND processed_at IS NULL
        AND processed_by IS NULL
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_data_requests'
      AND policyname = 'Users cancel own pending account data requests'
  ) THEN
    CREATE POLICY "Users cancel own pending account data requests"
      ON public.account_data_requests
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id AND status = 'pending')
      WITH CHECK (
        auth.uid() = user_id
        AND status IN ('pending', 'cancelled')
        AND request_type IN ('export', 'correction')
      );
  END IF;
END
$$;

GRANT SELECT, INSERT, UPDATE ON public.account_data_requests TO authenticated;
GRANT ALL ON public.account_data_requests TO service_role;

COMMENT ON TABLE public.account_data_requests IS
  'Support-reviewed account data export and correction requests submitted by users.';
COMMENT ON COLUMN public.account_data_requests.request_type IS
  'Data support request type. export requests account data access; correction requests account data correction support.';
COMMENT ON COLUMN public.account_data_requests.status IS
  'Support workflow state. Client users can create pending requests and cancel their own pending requests only.';
