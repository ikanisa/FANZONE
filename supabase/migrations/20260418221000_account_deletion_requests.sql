BEGIN;

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_review', 'completed', 'rejected', 'cancelled')),
  reason text NOT NULL,
  contact_email text,
  resolution_notes text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processed_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status
  ON public.account_deletion_requests (status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user
  ON public.account_deletion_requests (user_id, requested_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_deletion_requests_pending_unique
  ON public.account_deletion_requests (user_id)
  WHERE status IN ('pending', 'in_review');

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_deletion_requests'
      AND policyname = 'Users read own account deletion requests'
  ) THEN
    CREATE POLICY "Users read own account deletion requests"
      ON public.account_deletion_requests
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_deletion_requests'
      AND policyname = 'Users create own account deletion requests'
  ) THEN
    CREATE POLICY "Users create own account deletion requests"
      ON public.account_deletion_requests
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        AND status = 'pending'
        AND processed_at IS NULL
        AND processed_by IS NULL
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_deletion_requests'
      AND policyname = 'Users cancel own pending deletion requests'
  ) THEN
    CREATE POLICY "Users cancel own pending deletion requests"
      ON public.account_deletion_requests
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id AND status = 'pending')
      WITH CHECK (
        auth.uid() = user_id
        AND status IN ('pending', 'cancelled')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'account_deletion_requests'
      AND policyname = 'Admins manage account deletion requests'
  ) THEN
    CREATE POLICY "Admins manage account deletion requests"
      ON public.account_deletion_requests
      FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()));
  END IF;
END
$$;

GRANT SELECT, INSERT, UPDATE
  ON public.account_deletion_requests
  TO authenticated;

COMMIT;
