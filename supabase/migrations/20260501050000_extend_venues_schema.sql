-- ============================================================================
-- Extend Venues Table for Full CSV Compatibility
-- Migration: 20260501050000_extend_venues_schema.sql
-- Purpose: Add missing columns from venues_rows.csv to public.venues
-- ============================================================================

BEGIN;

-- Convert country_code from Enum to TEXT for easier expansion
ALTER TABLE public.venues 
  ALTER COLUMN country_code TYPE text;

-- Add check constraint to ensure 2-character country codes (ISO 3166-1 alpha-2)
ALTER TABLE public.venues
  ADD CONSTRAINT venues_country_code_format CHECK (country_code ~ '^[A-Z]{2}$');

ALTER TABLE public.venues
  ADD COLUMN IF NOT EXISTS hours_json               jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS photos_json              jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS revolut_link             text,
  ADD COLUMN IF NOT EXISTS whatsapp                 text,
  ADD COLUMN IF NOT EXISTS momo_code                text,
  ADD COLUMN IF NOT EXISTS ai_description           text,
  ADD COLUMN IF NOT EXISTS ai_image_url             text,
  ADD COLUMN IF NOT EXISTS primary_category         text,
  ADD COLUMN IF NOT EXISTS cuisine_types            text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS ambiance_tags            text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS special_features         text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS ai_category_confidence   numeric(5,4),
  ADD COLUMN IF NOT EXISTS last_ai_update           timestamptz,
  ADD COLUMN IF NOT EXISTS price_level              integer,
  ADD COLUMN IF NOT EXISTS rating                   numeric(3,2),
  ADD COLUMN IF NOT EXISTS claimed                  boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS owner_email              text,
  ADD COLUMN IF NOT EXISTS owner_pin                text,
  ADD COLUMN IF NOT EXISTS owner_phone              text,
  ADD COLUMN IF NOT EXISTS tenant_id                uuid,
  ADD COLUMN IF NOT EXISTS price_band               integer,
  ADD COLUMN IF NOT EXISTS features_json            jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS verified_at              timestamptz;

-- Add indexes for common search fields
CREATE INDEX IF NOT EXISTS venues_primary_category_idx ON public.venues (primary_category);
CREATE INDEX IF NOT EXISTS venues_claimed_idx ON public.venues (claimed);

CREATE TABLE IF NOT EXISTS public.onboarding_requests (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  submitted_by    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  email           text,
  phone           text,
  whatsapp        text,
  revolut_link    text,
  momo_code       text,
  menu_items_json jsonb,
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes     text,
  reviewed_by     uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  reviewed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS onboarding_requests_status_created_idx
  ON public.onboarding_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS onboarding_requests_venue_idx
  ON public.onboarding_requests (venue_id);

ALTER TABLE public.onboarding_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS onboarding_requests_select_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_select_submitter ON public.onboarding_requests
  FOR SELECT TO authenticated
  USING (
    submitted_by = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

DROP POLICY IF EXISTS onboarding_requests_insert_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_insert_submitter ON public.onboarding_requests
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by = (select auth.uid()));

DROP POLICY IF EXISTS onboarding_requests_update_admin ON public.onboarding_requests;
CREATE POLICY onboarding_requests_update_admin ON public.onboarding_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.onboarding_requests TO authenticated;

COMMIT;
