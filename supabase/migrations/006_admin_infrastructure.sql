-- ============================================================
-- 006_admin_infrastructure.sql
-- Admin panel infrastructure tables.
-- Additive only — does not modify any existing tables.
-- All admin-only tables use RLS blocking anon/authenticated access.
-- ============================================================

BEGIN;

-- ======================
-- 1) admin_users — admin identity and roles
-- ======================
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin','admin','moderator','viewer')),
  permissions JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  invited_by UUID REFERENCES public.admin_users(id),
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON public.admin_users(email);

-- ======================
-- 2) admin_audit_logs — immutable action log
-- ======================
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES public.admin_users(id),
  action TEXT NOT NULL,
  module TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  before_state JSONB,
  after_state JSONB,
  metadata JSONB DEFAULT '{}',
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON public.admin_audit_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON public.admin_audit_logs(module);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON public.admin_audit_logs(target_type, target_id);

-- ======================
-- 3) admin_feature_flags — runtime feature controls
-- ======================
CREATE TABLE IF NOT EXISTS public.admin_feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  is_enabled BOOLEAN DEFAULT false,
  market TEXT DEFAULT 'MT',
  module TEXT,
  config JSONB DEFAULT '{}',
  updated_by UUID REFERENCES public.admin_users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 4) admin_notes — internal comments on any entity
-- ======================
CREATE TABLE IF NOT EXISTS public.admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES public.admin_users(id),
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_target ON public.admin_notes(target_type, target_id);

-- ======================
-- 5) partners — partner businesses
-- ======================
CREATE TABLE IF NOT EXISTS public.partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  category TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  website_url TEXT,
  country TEXT DEFAULT 'MT',
  market TEXT DEFAULT 'MT',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','suspended','archived')),
  is_featured BOOLEAN DEFAULT false,
  approved_by UUID REFERENCES public.admin_users(id),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partners_status ON public.partners(status);
CREATE INDEX IF NOT EXISTS idx_partners_country ON public.partners(country);

-- ======================
-- 6) rewards — FET redemption offers
-- ======================
CREATE TABLE IF NOT EXISTS public.rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID REFERENCES public.partners(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  fet_cost BIGINT NOT NULL,
  original_value TEXT,
  currency TEXT DEFAULT 'EUR',
  image_url TEXT,
  inventory_total INT,
  inventory_remaining INT,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  country TEXT DEFAULT 'MT',
  market TEXT DEFAULT 'MT',
  is_featured BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.admin_users(id),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rewards_partner ON public.rewards(partner_id);
CREATE INDEX IF NOT EXISTS idx_rewards_active ON public.rewards(is_active, country);

-- ======================
-- 7) redemptions — user reward claims
-- ======================
CREATE TABLE IF NOT EXISTS public.redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  reward_id UUID REFERENCES public.rewards(id),
  partner_id UUID REFERENCES public.partners(id),
  fet_amount BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','fulfilled','rejected','disputed')),
  redemption_code TEXT,
  admin_notes TEXT,
  reviewed_by UUID REFERENCES public.admin_users(id),
  fraud_flag BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_redemptions_status ON public.redemptions(status);
CREATE INDEX IF NOT EXISTS idx_redemptions_user ON public.redemptions(user_id);

-- ======================
-- 8) content_banners — in-app promotional banners
-- ======================
CREATE TABLE IF NOT EXISTS public.content_banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  subtitle TEXT,
  image_url TEXT,
  action_url TEXT,
  placement TEXT DEFAULT 'home_hero',
  priority INT DEFAULT 0,
  country TEXT DEFAULT 'MT',
  is_active BOOLEAN DEFAULT true,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  created_by UUID REFERENCES public.admin_users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 9) campaigns — push/in-app messaging
-- ======================
CREATE TABLE IF NOT EXISTS public.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'in_app' CHECK (type IN ('push','in_app','email')),
  segment JSONB DEFAULT '{}',
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft','scheduled','sent','cancelled')),
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  recipient_count INT DEFAULT 0,
  country TEXT DEFAULT 'MT',
  created_by UUID REFERENCES public.admin_users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 10) moderation_reports — abuse/fraud review
-- ======================
CREATE TABLE IF NOT EXISTS public.moderation_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id UUID,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','dismissed','escalated')),
  severity TEXT DEFAULT 'low' CHECK (severity IN ('low','medium','high','critical')),
  assigned_to UUID REFERENCES public.admin_users(id),
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.moderation_reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_target ON public.moderation_reports(target_type, target_id);

-- ======================
-- 11) ROW LEVEL SECURITY — admin-only tables
-- Block all access for anon/authenticated roles.
-- Admin panel uses service_role via Edge Functions or
-- authenticated admin users with custom RLS policies.
-- ======================

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

-- Admin users can read their own row
CREATE POLICY "Admin users read own profile"
  ON public.admin_users FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admin audit logs: admins can read (via matching admin_users row)
CREATE POLICY "Admins can read audit logs"
  ON public.admin_audit_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid() AND is_active = true AND role IN ('super_admin', 'admin')
    )
  );

-- Audit logs are append-only via service_role or authorized admin
CREATE POLICY "Admins can insert audit logs"
  ON public.admin_audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- Feature flags: readable by any admin
CREATE POLICY "Admins can read feature flags"
  ON public.admin_feature_flags FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- Partners: public read for approved, admin write
CREATE POLICY "Public read approved partners"
  ON public.partners FOR SELECT
  USING (status = 'approved');

CREATE POLICY "Admins read all partners"
  ON public.partners FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid() AND is_active = true AND role IN ('super_admin', 'admin')
    )
  );

-- Rewards: public read for active
CREATE POLICY "Public read active rewards"
  ON public.rewards FOR SELECT
  USING (is_active = true);

-- Redemptions: users read own
CREATE POLICY "Users read own redemptions"
  ON public.redemptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Content banners: public read for active
CREATE POLICY "Public read active banners"
  ON public.content_banners FOR SELECT
  USING (is_active = true);

-- Campaigns: admin-only, no public access

-- Moderation reports: admin-only, no public access

-- Admin notes: admin-only read
CREATE POLICY "Admins can read notes"
  ON public.admin_notes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

COMMIT;
