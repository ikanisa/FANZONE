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

COMMIT;
