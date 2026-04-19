BEGIN;

-- Bridge older admin schema variants to the current repository shape.

ALTER TABLE public.partners
  ADD COLUMN IF NOT EXISTS slug text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS contact_phone text,
  ADD COLUMN IF NOT EXISTS website_url text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS market text,
  ADD COLUMN IF NOT EXISTS status text,
  ADD COLUMN IF NOT EXISTS is_featured boolean,
  ADD COLUMN IF NOT EXISTS approved_by uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.partners
  ALTER COLUMN country SET DEFAULT 'MT',
  ALTER COLUMN market SET DEFAULT 'MT',
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN is_featured SET DEFAULT false,
  ALTER COLUMN metadata SET DEFAULT '{}'::jsonb,
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

UPDATE public.partners
SET
  slug = coalesce(
    nullif(trim(slug), ''),
    nullif(regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'), '')
  ),
  country = coalesce(nullif(trim(country), ''), 'MT'),
  market = coalesce(nullif(trim(market), ''), 'MT'),
  status = coalesce(nullif(trim(status), ''), 'pending'),
  is_featured = coalesce(is_featured, false),
  metadata = coalesce(metadata, '{}'::jsonb),
  updated_at = coalesce(updated_at, created_at, timezone('utc', now()));

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'partners'
      AND column_name = 'location_description'
  ) THEN
    EXECUTE $sql$
      UPDATE public.partners
      SET description = coalesce(
        nullif(trim(description), ''),
        nullif(trim(location_description), '')
      )
      WHERE nullif(trim(description), '') IS NULL
        AND nullif(trim(location_description), '') IS NOT NULL
    $sql$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'partners'
      AND column_name = 'is_active'
  ) THEN
    EXECUTE $sql$
      UPDATE public.partners
      SET status = CASE
        WHEN nullif(trim(status), '') IS NOT NULL THEN status
        WHEN coalesce(is_active, false) THEN 'approved'
        ELSE 'pending'
      END
    $sql$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'partners_approved_by_fkey'
      AND conrelid = 'public.partners'::regclass
  ) THEN
    ALTER TABLE public.partners
      ADD CONSTRAINT partners_approved_by_fkey
      FOREIGN KEY (approved_by) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid REFERENCES public.partners(id),
  title text NOT NULL,
  description text,
  category text,
  fet_cost bigint NOT NULL,
  original_value text,
  currency text DEFAULT 'EUR',
  image_url text,
  inventory_total integer,
  inventory_remaining integer,
  valid_from timestamptz,
  valid_until timestamptz,
  country text DEFAULT 'MT',
  market text DEFAULT 'MT',
  is_featured boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES public.admin_users(id),
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT timezone('utc', now()),
  updated_at timestamptz DEFAULT timezone('utc', now())
);

ALTER TABLE public.rewards
  ADD COLUMN IF NOT EXISTS partner_id uuid,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS fet_cost bigint,
  ADD COLUMN IF NOT EXISTS original_value text,
  ADD COLUMN IF NOT EXISTS currency text,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS inventory_total integer,
  ADD COLUMN IF NOT EXISTS inventory_remaining integer,
  ADD COLUMN IF NOT EXISTS valid_from timestamptz,
  ADD COLUMN IF NOT EXISTS valid_until timestamptz,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS market text,
  ADD COLUMN IF NOT EXISTS is_featured boolean,
  ADD COLUMN IF NOT EXISTS is_active boolean,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.rewards
  ALTER COLUMN currency SET DEFAULT 'EUR',
  ALTER COLUMN country SET DEFAULT 'MT',
  ALTER COLUMN market SET DEFAULT 'MT',
  ALTER COLUMN is_featured SET DEFAULT false,
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN metadata SET DEFAULT '{}'::jsonb,
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'rewards_partner_id_fkey'
      AND conrelid = 'public.rewards'::regclass
  ) THEN
    ALTER TABLE public.rewards
      ADD CONSTRAINT rewards_partner_id_fkey
      FOREIGN KEY (partner_id) REFERENCES public.partners(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'rewards_created_by_fkey'
      AND conrelid = 'public.rewards'::regclass
  ) THEN
    ALTER TABLE public.rewards
      ADD CONSTRAINT rewards_created_by_fkey
      FOREIGN KEY (created_by) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.reward_offers') IS NOT NULL THEN
    INSERT INTO public.rewards (
      id,
      partner_id,
      title,
      description,
      fet_cost,
      currency,
      valid_until,
      country,
      market,
      is_featured,
      is_active,
      metadata,
      created_at,
      updated_at
    )
    SELECT
      offer.id,
      offer.partner_id,
      offer.title,
      offer.description,
      offer.fet_cost,
      'EUR',
      offer.expires_at,
      coalesce(partner.country, 'MT'),
      coalesce(partner.market, 'MT'),
      false,
      coalesce(offer.is_available, true),
      jsonb_build_object('legacy_source', 'reward_offers'),
      timezone('utc', now()),
      timezone('utc', now())
    FROM public.reward_offers AS offer
    LEFT JOIN public.partners AS partner
      ON partner.id = offer.partner_id
    LEFT JOIN public.rewards AS reward
      ON reward.id = offer.id
    WHERE reward.id IS NULL;
  END IF;
END;
$$;

UPDATE public.rewards
SET
  title = coalesce(title, 'Reward'),
  fet_cost = coalesce(fet_cost, 0),
  currency = coalesce(nullif(trim(currency), ''), 'EUR'),
  country = coalesce(nullif(trim(country), ''), 'MT'),
  market = coalesce(nullif(trim(market), ''), 'MT'),
  is_featured = coalesce(is_featured, false),
  is_active = coalesce(is_active, true),
  metadata = coalesce(metadata, '{}'::jsonb),
  created_at = coalesce(created_at, timezone('utc', now())),
  updated_at = coalesce(updated_at, created_at, timezone('utc', now()));

CREATE INDEX IF NOT EXISTS idx_rewards_partner ON public.rewards(partner_id);
CREATE INDEX IF NOT EXISTS idx_rewards_active ON public.rewards(is_active, country);

ALTER TABLE public.redemptions
  ADD COLUMN IF NOT EXISTS reward_id uuid,
  ADD COLUMN IF NOT EXISTS partner_id uuid,
  ADD COLUMN IF NOT EXISTS fet_amount bigint,
  ADD COLUMN IF NOT EXISTS admin_notes text,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid,
  ADD COLUMN IF NOT EXISTS fraud_flag boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT timezone('utc', now());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'redemptions_reward_id_fkey'
      AND conrelid = 'public.redemptions'::regclass
  ) THEN
    ALTER TABLE public.redemptions
      ADD CONSTRAINT redemptions_reward_id_fkey
      FOREIGN KEY (reward_id) REFERENCES public.rewards(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'redemptions_partner_id_fkey'
      AND conrelid = 'public.redemptions'::regclass
  ) THEN
    ALTER TABLE public.redemptions
      ADD CONSTRAINT redemptions_partner_id_fkey
      FOREIGN KEY (partner_id) REFERENCES public.partners(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'redemptions_reviewed_by_fkey'
      AND conrelid = 'public.redemptions'::regclass
  ) THEN
    ALTER TABLE public.redemptions
      ADD CONSTRAINT redemptions_reviewed_by_fkey
      FOREIGN KEY (reviewed_by) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'redemptions'
      AND column_name = 'offer_id'
  ) THEN
    EXECUTE $sql$
      UPDATE public.redemptions AS redemption
      SET
        reward_id = coalesce(redemption.reward_id, reward.id),
        partner_id = coalesce(redemption.partner_id, reward.partner_id),
        fet_amount = coalesce(redemption.fet_amount, reward.fet_cost),
        fraud_flag = coalesce(redemption.fraud_flag, false),
        updated_at = coalesce(redemption.updated_at, redemption.created_at, timezone('utc', now()))
      FROM public.rewards AS reward
      WHERE redemption.offer_id = reward.id
        AND (
          redemption.reward_id IS NULL
          OR redemption.partner_id IS NULL
          OR redemption.fet_amount IS NULL
          OR redemption.updated_at IS NULL
          OR redemption.fraud_flag IS NULL
        )
    $sql$;
  END IF;
END;
$$;

UPDATE public.redemptions
SET
  fraud_flag = coalesce(fraud_flag, false),
  updated_at = coalesce(updated_at, created_at, timezone('utc', now()));

CREATE TABLE IF NOT EXISTS public.content_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_url text,
  action_url text,
  placement text DEFAULT 'home_hero',
  priority integer DEFAULT 0,
  country text DEFAULT 'MT',
  is_active boolean DEFAULT true,
  valid_from timestamptz,
  valid_until timestamptz,
  created_by uuid REFERENCES public.admin_users(id),
  created_at timestamptz DEFAULT timezone('utc', now()),
  updated_at timestamptz DEFAULT timezone('utc', now())
);

ALTER TABLE public.content_banners
  ADD COLUMN IF NOT EXISTS subtitle text,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS action_url text,
  ADD COLUMN IF NOT EXISTS placement text,
  ADD COLUMN IF NOT EXISTS priority integer,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS is_active boolean,
  ADD COLUMN IF NOT EXISTS valid_from timestamptz,
  ADD COLUMN IF NOT EXISTS valid_until timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.content_banners
  ALTER COLUMN placement SET DEFAULT 'home_hero',
  ALTER COLUMN priority SET DEFAULT 0,
  ALTER COLUMN country SET DEFAULT 'MT',
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'content_banners_created_by_fkey'
      AND conrelid = 'public.content_banners'::regclass
  ) THEN
    ALTER TABLE public.content_banners
      ADD CONSTRAINT content_banners_created_by_fkey
      FOREIGN KEY (created_by) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'in_app' CHECK (type IN ('push', 'in_app', 'email')),
  segment jsonb DEFAULT '{}'::jsonb,
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'sent', 'cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  recipient_count integer DEFAULT 0,
  country text DEFAULT 'MT',
  created_by uuid REFERENCES public.admin_users(id),
  created_at timestamptz DEFAULT timezone('utc', now()),
  updated_at timestamptz DEFAULT timezone('utc', now())
);

ALTER TABLE public.campaigns
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS message text,
  ADD COLUMN IF NOT EXISTS type text,
  ADD COLUMN IF NOT EXISTS segment jsonb,
  ADD COLUMN IF NOT EXISTS status text,
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS recipient_count integer,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.campaigns
  ALTER COLUMN type SET DEFAULT 'in_app',
  ALTER COLUMN segment SET DEFAULT '{}'::jsonb,
  ALTER COLUMN status SET DEFAULT 'draft',
  ALTER COLUMN recipient_count SET DEFAULT 0,
  ALTER COLUMN country SET DEFAULT 'MT',
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'campaigns_created_by_fkey'
      AND conrelid = 'public.campaigns'::regclass
  ) THEN
    ALTER TABLE public.campaigns
      ADD CONSTRAINT campaigns_created_by_fkey
      FOREIGN KEY (created_by) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.moderation_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id uuid,
  target_type text NOT NULL,
  target_id text NOT NULL,
  reason text NOT NULL,
  description text,
  status text DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'dismissed', 'escalated')),
  severity text DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  assigned_to uuid REFERENCES public.admin_users(id),
  resolution_notes text,
  created_at timestamptz DEFAULT timezone('utc', now()),
  updated_at timestamptz DEFAULT timezone('utc', now())
);

ALTER TABLE public.moderation_reports
  ADD COLUMN IF NOT EXISTS reporter_user_id uuid,
  ADD COLUMN IF NOT EXISTS target_type text,
  ADD COLUMN IF NOT EXISTS target_id text,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS status text,
  ADD COLUMN IF NOT EXISTS severity text,
  ADD COLUMN IF NOT EXISTS assigned_to uuid,
  ADD COLUMN IF NOT EXISTS resolution_notes text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.moderation_reports
  ALTER COLUMN status SET DEFAULT 'open',
  ALTER COLUMN severity SET DEFAULT 'low',
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'moderation_reports_assigned_to_fkey'
      AND conrelid = 'public.moderation_reports'::regclass
  ) THEN
    ALTER TABLE public.moderation_reports
      ADD CONSTRAINT moderation_reports_assigned_to_fkey
      FOREIGN KEY (assigned_to) REFERENCES public.admin_users(id);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.moderation_reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_target ON public.moderation_reports(target_type, target_id);

DO $$
BEGIN
  IF to_regclass('public.rewards') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Public read active rewards" ON public.rewards';
    EXECUTE 'CREATE POLICY "Public read active rewards"
      ON public.rewards FOR SELECT
      USING (is_active = true)';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage rewards" ON public.rewards';
    EXECUTE 'CREATE POLICY "Admins manage rewards"
      ON public.rewards FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.content_banners') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.content_banners ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Public read active banners" ON public.content_banners';
    EXECUTE 'CREATE POLICY "Public read active banners"
      ON public.content_banners FOR SELECT
      USING (is_active = true)';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage content banners" ON public.content_banners';
    EXECUTE 'CREATE POLICY "Admins manage content banners"
      ON public.content_banners FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.campaigns') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read campaigns" ON public.campaigns';
    EXECUTE 'CREATE POLICY "Admins read campaigns"
      ON public.campaigns FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage campaigns" ON public.campaigns';
    EXECUTE 'CREATE POLICY "Admins manage campaigns"
      ON public.campaigns FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read moderation reports" ON public.moderation_reports';
    EXECUTE 'CREATE POLICY "Admins read moderation reports"
      ON public.moderation_reports FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage moderation reports" ON public.moderation_reports';
    EXECUTE 'CREATE POLICY "Admins manage moderation reports"
      ON public.moderation_reports FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;
END;
$$;

COMMIT;
