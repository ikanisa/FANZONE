-- Remove retired table-entry ordering from the production product surface.

ALTER TABLE public.orders
  ALTER COLUMN table_id DROP NOT NULL;

COMMENT ON COLUMN public.orders.table_id IS
  'App-entered table reference for staff delivery. QR ordering is retired.';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'onboarding_status'
      AND e.enumlabel = 'qr_generated'
  ) THEN
    EXECUTE $sql$
      UPDATE public.venues
      SET onboarding_status = 'menu_pending'::public.onboarding_status,
          updated_at = now()
      WHERE onboarding_status = 'qr_generated'::public.onboarding_status
    $sql$;
  END IF;
END $$;

DROP VIEW IF EXISTS public.venue_tables;

CREATE VIEW public.venue_tables
WITH (security_invoker = true) AS
SELECT
  t.id,
  t.venue_id,
  t.table_number,
  t.is_active,
  t.created_at,
  t.updated_at
FROM public.tables t;

COMMENT ON VIEW public.venue_tables IS
  'Canonical table surface over public.tables. Table-based customer ordering is retired.';

GRANT SELECT ON TABLE public.venue_tables TO anon, authenticated, service_role;

DROP INDEX IF EXISTS public.tables_qr_token_unique_idx;
DROP INDEX IF EXISTS public.tables_qr_token_idx;

ALTER TABLE public.tables
  DROP COLUMN IF EXISTS qr_url,
  DROP COLUMN IF EXISTS qr_code_url,
  DROP COLUMN IF EXISTS qr_token,
  DROP COLUMN IF EXISTS deep_link_uri;

DROP FUNCTION IF EXISTS public.generate_table_qr(uuid, text, text);
