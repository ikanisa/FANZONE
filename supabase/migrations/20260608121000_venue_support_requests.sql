-- Non-order venue support requests for verified customers.
-- Complements table-scoped bell requests without requiring open QR/table sessions.

CREATE TABLE IF NOT EXISTS public.venue_support_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  table_number text,
  topic text NOT NULL DEFAULT 'general',
  message text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  resolution_notes text,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT venue_support_requests_topic_check CHECK (
    topic IN ('general', 'accessibility', 'venue', 'order', 'payment', 'safety')
  ),
  CONSTRAINT venue_support_requests_status_check CHECK (
    status IN ('open', 'in_review', 'resolved', 'closed', 'cancelled')
  )
);

CREATE INDEX IF NOT EXISTS idx_venue_support_requests_venue_status
  ON public.venue_support_requests (venue_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_venue_support_requests_user
  ON public.venue_support_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_venue_support_requests_order
  ON public.venue_support_requests (order_id)
  WHERE order_id IS NOT NULL;

ALTER TABLE public.venue_support_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'venue_support_requests'
      AND policyname = 'Users create own venue support requests'
  ) THEN
    CREATE POLICY "Users create own venue support requests"
      ON public.venue_support_requests
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        AND status = 'open'
        AND resolved_at IS NULL
        AND resolved_by IS NULL
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
      AND tablename = 'venue_support_requests'
      AND policyname = 'Users read own venue support requests'
  ) THEN
    CREATE POLICY "Users read own venue support requests"
      ON public.venue_support_requests
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
      AND tablename = 'venue_support_requests'
      AND policyname = 'Venue operators manage venue support requests'
  ) THEN
    CREATE POLICY "Venue operators manage venue support requests"
      ON public.venue_support_requests
      TO authenticated
      USING (
        public.is_admin_manager(auth.uid())
        OR public.venue_user_has_role(venue_id)
      )
      WITH CHECK (
        public.is_admin_manager(auth.uid())
        OR public.venue_user_has_role(venue_id)
      );
  END IF;
END
$$;

GRANT SELECT, INSERT ON public.venue_support_requests TO authenticated;
GRANT UPDATE ON public.venue_support_requests TO authenticated;
GRANT ALL ON public.venue_support_requests TO service_role;

COMMENT ON TABLE public.venue_support_requests IS
  'Verified customer venue support requests that do not depend on table-scoped bell requests.';
COMMENT ON COLUMN public.venue_support_requests.table_number IS
  'Optional manually entered table number. This is not a QR session dependency.';
COMMENT ON COLUMN public.venue_support_requests.status IS
  'Support workflow state managed by venue operators or platform admins.';
