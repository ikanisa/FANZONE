-- ============================================================================
-- DineIn Hospitality Schema Merge into FANZONE
-- Migration: 20260501_dinein_schema_merge.sql
-- Purpose: Add DineIn ordering/venue tables to FANZONE's existing schema
-- Strategy: All additive. No modifications to existing FANZONE tables.
-- ============================================================================

BEGIN;

-- ── Extensions (idempotent) ──────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS citext  WITH SCHEMA extensions;

-- ── Enums ────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'country_code'
  ) THEN
    CREATE TYPE public.country_code AS ENUM ('RW', 'MT');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'venue_type'
  ) THEN
    CREATE TYPE public.venue_type AS ENUM ('bar', 'restaurant', 'hotel', 'event');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'venue_user_role'
  ) THEN
    CREATE TYPE public.venue_user_role AS ENUM ('owner', 'manager', 'staff');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'onboarding_status'
  ) THEN
    CREATE TYPE public.onboarding_status AS ENUM (
      'draft',
      'profile_complete',
      'location_complete',
      'menu_pending',
      'qr_generated',
      'live'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'order_status'
  ) THEN
    CREATE TYPE public.order_status AS ENUM ('placed', 'received', 'served', 'cancelled');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'payment_method'
  ) THEN
    CREATE TYPE public.payment_method AS ENUM ('momo', 'revolut', 'cash');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'dinein_payment_status'
  ) THEN
    CREATE TYPE public.dinein_payment_status AS ENUM (
      'pending', 'paid', 'failed', 'cancelled', 'refunded'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'menu_import_source'
  ) THEN
    CREATE TYPE public.menu_import_source AS ENUM (
      'manual', 'ocr_image', 'ocr_pdf', 'file_import'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typnamespace = 'public'::regnamespace AND typname = 'menu_import_status'
  ) THEN
    CREATE TYPE public.menu_import_status AS ENUM (
      'pending', 'processing', 'review', 'approved', 'rejected', 'failed'
    );
  END IF;
END
$$;

-- ── Helper Functions ─────────────────────────────────────────────────────────

-- Generic updated_at trigger function for DineIn tables
CREATE OR REPLACE FUNCTION public.dinein_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

-- Order-specific timestamp trigger: auto-set accepted_at/served_at on status change
CREATE OR REPLACE FUNCTION public.dinein_set_order_timestamps()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());

  IF tg_op = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at = timezone('utc', now());

    IF NEW.status = 'preparing' AND OLD.accepted_at IS NULL THEN
      NEW.accepted_at = timezone('utc', now());
    END IF;

    IF NEW.status = 'served' AND OLD.served_at IS NULL THEN
      NEW.served_at = timezone('utc', now());
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- NOTE: dinein_is_venue_member and dinein_sync_owner_membership
-- are defined AFTER table creation (they reference venue_users).

-- ── Table 1: venues ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.venues (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  owner_id        uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  name            text NOT NULL CHECK (char_length(trim(name)) BETWEEN 2 AND 120),
  slug            text UNIQUE,
  country_code    public.country_code NOT NULL,
  venue_type      public.venue_type NOT NULL,
  currency_code   text NOT NULL CHECK (currency_code IN ('RWF', 'EUR')),
  description     text,
  contact_email   extensions.citext,
  contact_phone_hash  text,
  contact_phone_last4 text CHECK (
    contact_phone_last4 IS NULL OR contact_phone_last4 ~ '^[0-9]{4}$'
  ),
  website_url     text,
  google_place_id text,
  address_line1   text,
  address_line2   text,
  city            text,
  region          text,
  postal_code     text,
  latitude        double precision,
  longitude       double precision,
  timezone        text NOT NULL DEFAULT 'Europe/Malta',
  logo_url        text,
  cover_url       text,
  is_open         boolean NOT NULL DEFAULT false,
  is_active       boolean NOT NULL DEFAULT true,
  onboarding_status public.onboarding_status NOT NULL DEFAULT 'draft',
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ── Table 2: tables (physical tables inside venues) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.tables (
  id            uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id      uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  table_number  text NOT NULL CHECK (char_length(trim(table_number)) BETWEEN 1 AND 24),
  qr_code_url   text,
  deep_link_uri text,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at    timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (venue_id, table_number),
  UNIQUE (id, venue_id)
);

-- ── Table 3: venue_users (staff/owner/manager membership) ────────────────────

CREATE TABLE IF NOT EXISTS public.venue_users (
  id          uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id    uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role        public.venue_user_role NOT NULL DEFAULT 'staff',
  invited_by  uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (venue_id, user_id)
);

-- ── Table 4: menu_categories ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.menu_categories (
  id            uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id      uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  name          text NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  display_order integer NOT NULL DEFAULT 0 CHECK (display_order >= 0),
  is_visible    boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at    timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (id, venue_id)
);

-- ── Table 5: menu_items ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.menu_items (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  category_id     uuid NOT NULL,
  name            text NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 120),
  description     text,
  price           numeric(12, 2) NOT NULL CHECK (price >= 0),
  currency_code   text NOT NULL CHECK (currency_code IN ('RWF', 'EUR')),
  image_url       text,
  is_available    boolean NOT NULL DEFAULT true,
  is_featured     boolean NOT NULL DEFAULT false,
  dietary_flags   jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(dietary_flags) = 'object'),
  allergens       text[] NOT NULL DEFAULT '{}'::text[],
  add_ons         jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(add_ons) = 'array'),
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  display_order   integer NOT NULL DEFAULT 0 CHECK (display_order >= 0),
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (id, venue_id),
  CONSTRAINT menu_items_category_fkey
    FOREIGN KEY (category_id, venue_id)
    REFERENCES public.menu_categories (id, venue_id)
    ON DELETE CASCADE
);

-- ── Table 6: orders ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.orders (
  id                    uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id              uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  table_id              uuid NOT NULL,
  user_id               uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE RESTRICT,
  order_code            text NOT NULL DEFAULT upper(encode(extensions.gen_random_bytes(6), 'hex')),
  status                public.order_status NOT NULL DEFAULT 'placed',
  payment_method        public.payment_method NOT NULL,
  payment_status        public.dinein_payment_status NOT NULL DEFAULT 'pending',
  payment_reference     text,
  currency_code         text NOT NULL CHECK (currency_code IN ('RWF', 'EUR')),
  subtotal_amount       numeric(12, 2) NOT NULL DEFAULT 0 CHECK (subtotal_amount >= 0),
  tax_amount            numeric(12, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  tip_amount            numeric(12, 2) NOT NULL DEFAULT 0 CHECK (tip_amount >= 0),
  total_amount          numeric(12, 2) NOT NULL CHECK (total_amount >= 0),
  special_instructions  text,
  estimated_ready_at    timestamptz,
  accepted_at           timestamptz,
  served_at             timestamptz,
  status_changed_at     timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_at            timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at            timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (order_code),
  CONSTRAINT orders_table_fkey
    FOREIGN KEY (table_id, venue_id)
    REFERENCES public.tables (id, venue_id)
    ON DELETE RESTRICT
);

-- ── Table 7: order_items ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.order_items (
  id                      uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  order_id                uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  menu_item_id            uuid REFERENCES public.menu_items (id) ON DELETE SET NULL,
  item_name_snapshot      text NOT NULL,
  item_description_snapshot text,
  quantity                integer NOT NULL CHECK (quantity > 0),
  unit_price              numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
  line_total              numeric(12, 2) NOT NULL CHECK (line_total >= 0),
  currency_code           text NOT NULL CHECK (currency_code IN ('RWF', 'EUR')),
  add_ons                 jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(add_ons) = 'array'),
  special_instructions    text,
  created_at              timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ── Table 8: bell_requests ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bell_requests (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  table_id        uuid NOT NULL,
  user_id         uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE RESTRICT,
  message         text,
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT bell_requests_table_fkey
    FOREIGN KEY (table_id, venue_id)
    REFERENCES public.tables (id, venue_id)
    ON DELETE CASCADE
);

-- ── Table 9: pending_menu_imports ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pending_menu_imports (
  id                uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id          uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  created_by        uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE RESTRICT,
  source            public.menu_import_source NOT NULL,
  status            public.menu_import_status NOT NULL DEFAULT 'pending',
  storage_bucket    text NOT NULL DEFAULT 'menu-ocr-queue',
  storage_path      text NOT NULL,
  original_filename text,
  detected_currency text CHECK (detected_currency IS NULL OR detected_currency IN ('RWF', 'EUR')),
  extracted_payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(extracted_payload) = 'object'),
  review_payload    jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(review_payload) = 'object'),
  error_message     text,
  processed_at      timestamptz,
  reviewed_at       timestamptz,
  created_at        timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at        timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ── Table 10: payment_events ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.payment_events (
  id                uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  order_id          uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  provider          public.payment_method NOT NULL,
  status            public.dinein_payment_status NOT NULL DEFAULT 'pending',
  external_reference text,
  request_payload   jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(request_payload) = 'object'),
  response_payload  jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(response_payload) = 'object'),
  created_at        timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at        timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ── Functions (depend on tables above) ──────────────────────────────────

-- RLS helper: check if current user is a venue member with given roles
CREATE OR REPLACE FUNCTION public.dinein_is_venue_member(
  target_venue_id uuid,
  allowed_roles public.venue_user_role[] DEFAULT ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.venue_users vu
    WHERE vu.venue_id = target_venue_id
      AND vu.user_id = auth.uid()
      AND vu.is_active = true
      AND vu.role::text = ANY (
        ARRAY(SELECT unnest(allowed_roles)::text)
      )
  );
$$;

-- Auto-sync owner_id changes to venue_users membership
CREATE OR REPLACE FUNCTION public.dinein_sync_owner_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Deactivate old owner membership
  IF tg_op = 'UPDATE'
     AND OLD.owner_id IS DISTINCT FROM NEW.owner_id
     AND OLD.owner_id IS NOT NULL
  THEN
    UPDATE public.venue_users
    SET is_active = false,
        updated_at = timezone('utc', now())
    WHERE venue_id = NEW.id
      AND user_id = OLD.owner_id
      AND role = 'owner';
  END IF;

  -- Upsert new owner membership
  IF NEW.owner_id IS NOT NULL THEN
    INSERT INTO public.venue_users (venue_id, user_id, role, is_active)
    VALUES (NEW.id, NEW.owner_id, 'owner', true)
    ON CONFLICT (venue_id, user_id) DO UPDATE
    SET role = 'owner',
        is_active = true,
        updated_at = timezone('utc', now());
  END IF;

  RETURN NEW;
END;
$$;

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS venues_owner_id_idx
  ON public.venues (owner_id);
CREATE INDEX IF NOT EXISTS venues_slug_idx
  ON public.venues (slug) WHERE slug IS NOT NULL;
CREATE INDEX IF NOT EXISTS venues_country_open_idx
  ON public.venues (country_code, is_open, is_active);

CREATE INDEX IF NOT EXISTS tables_venue_active_idx
  ON public.tables (venue_id, is_active);

CREATE INDEX IF NOT EXISTS venue_users_user_idx
  ON public.venue_users (user_id);

CREATE INDEX IF NOT EXISTS menu_categories_venue_order_idx
  ON public.menu_categories (venue_id, display_order);

CREATE INDEX IF NOT EXISTS menu_items_venue_category_order_idx
  ON public.menu_items (venue_id, category_id, display_order);
CREATE INDEX IF NOT EXISTS menu_items_venue_available_idx
  ON public.menu_items (venue_id, is_available);

CREATE INDEX IF NOT EXISTS orders_venue_status_created_idx
  ON public.orders (venue_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS orders_user_created_idx
  ON public.orders (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS order_items_order_idx
  ON public.order_items (order_id);

CREATE INDEX IF NOT EXISTS bell_requests_venue_ack_created_idx
  ON public.bell_requests (venue_id, acknowledged_at, created_at DESC);

CREATE INDEX IF NOT EXISTS pending_menu_imports_venue_status_created_idx
  ON public.pending_menu_imports (venue_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS payment_events_order_created_idx
  ON public.payment_events (order_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS payment_events_provider_reference_uidx
  ON public.payment_events (provider, external_reference)
  WHERE external_reference IS NOT NULL;

-- ── Triggers ─────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS set_venues_updated_at ON public.venues;
CREATE TRIGGER set_venues_updated_at
  BEFORE UPDATE ON public.venues
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_tables_updated_at ON public.tables;
CREATE TRIGGER set_tables_updated_at
  BEFORE UPDATE ON public.tables
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_venue_users_updated_at ON public.venue_users;
CREATE TRIGGER set_venue_users_updated_at
  BEFORE UPDATE ON public.venue_users
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_menu_categories_updated_at ON public.menu_categories;
CREATE TRIGGER set_menu_categories_updated_at
  BEFORE UPDATE ON public.menu_categories
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_menu_items_updated_at ON public.menu_items;
CREATE TRIGGER set_menu_items_updated_at
  BEFORE UPDATE ON public.menu_items
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_orders_timestamps ON public.orders;
CREATE TRIGGER set_orders_timestamps
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_order_timestamps();

DROP TRIGGER IF EXISTS set_pending_menu_imports_updated_at ON public.pending_menu_imports;
CREATE TRIGGER set_pending_menu_imports_updated_at
  BEFORE UPDATE ON public.pending_menu_imports
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS set_payment_events_updated_at ON public.payment_events;
CREATE TRIGGER set_payment_events_updated_at
  BEFORE UPDATE ON public.payment_events
  FOR EACH ROW EXECUTE FUNCTION public.dinein_set_updated_at();

DROP TRIGGER IF EXISTS sync_owner_membership ON public.venues;
CREATE TRIGGER sync_owner_membership
  AFTER INSERT OR UPDATE OF owner_id ON public.venues
  FOR EACH ROW EXECUTE FUNCTION public.dinein_sync_owner_membership();

-- ── Grants (anon + authenticated read, authenticated write) ──────────────────

GRANT SELECT ON public.venues TO anon, authenticated;
GRANT SELECT ON public.tables TO anon, authenticated;
GRANT SELECT ON public.menu_categories TO anon, authenticated;
GRANT SELECT ON public.menu_items TO anon, authenticated;

GRANT SELECT, INSERT ON public.orders TO authenticated;
GRANT SELECT, INSERT ON public.order_items TO authenticated;
GRANT SELECT, INSERT ON public.bell_requests TO authenticated;

GRANT ALL ON public.venue_users TO authenticated;
GRANT ALL ON public.pending_menu_imports TO authenticated;
GRANT ALL ON public.payment_events TO authenticated;

COMMIT;
