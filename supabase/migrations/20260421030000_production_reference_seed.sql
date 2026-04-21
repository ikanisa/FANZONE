-- ============================================================
-- FANZONE Production Reference Data Seed
-- Purpose: Ensure all reference/lookup tables exist and have data
-- Safe: Uses IF NOT EXISTS + ON CONFLICT — re-runnable
-- ============================================================

BEGIN;

-- ------------------------------------------------------------------
-- 0. Ensure reference tables exist (may have been defined in
--    unnumbered migrations that were not pushed to remote)
-- ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fan_levels (
  level     INTEGER PRIMARY KEY,
  name      TEXT NOT NULL,
  title     TEXT NOT NULL DEFAULT '',
  min_xp    INTEGER NOT NULL DEFAULT 0,
  icon_name TEXT DEFAULT 'user',
  color_hex TEXT DEFAULT '#A8A29E'
);

CREATE TABLE IF NOT EXISTS public.fan_badges (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  description     TEXT DEFAULT '',
  category        TEXT DEFAULT 'milestone',
  icon_name       TEXT DEFAULT 'award',
  color_hex       TEXT DEFAULT '#22C55E',
  criteria_type   TEXT DEFAULT 'manual',
  criteria_value  INTEGER DEFAULT 0
);

ALTER TABLE public.fan_badges
  ADD COLUMN IF NOT EXISTS color_hex TEXT DEFAULT '#22C55E',
  ADD COLUMN IF NOT EXISTS criteria_type TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS criteria_value INTEGER DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.fan_earned_badges (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id   TEXT REFERENCES public.fan_badges(id),
  earned_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, badge_id)
);

CREATE TABLE IF NOT EXISTS public.currency_rates (
  base_currency   TEXT NOT NULL,
  target_currency TEXT NOT NULL,
  rate            NUMERIC(18,6) NOT NULL DEFAULT 1,
  source          TEXT DEFAULT 'manual',
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (base_currency, target_currency)
);

CREATE TABLE IF NOT EXISTS public.leaderboard_seasons (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  status     TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS public.marketplace_partners (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT DEFAULT '',
  logo_url    TEXT,
  is_active   BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.marketplace_offers (
  id              TEXT PRIMARY KEY,
  partner_id      TEXT REFERENCES public.marketplace_partners(id),
  title           TEXT NOT NULL,
  description     TEXT DEFAULT '',
  category        TEXT DEFAULT 'merch',
  cost_fet        INTEGER NOT NULL DEFAULT 0,
  delivery_type   TEXT DEFAULT 'voucher',
  is_active       BOOLEAN DEFAULT true,
  original_value  TEXT
);

CREATE TABLE IF NOT EXISTS public.featured_events (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  short_name     TEXT NOT NULL,
  event_tag      TEXT NOT NULL UNIQUE,
  region         TEXT NOT NULL DEFAULT 'global' CHECK (region IN ('global', 'africa', 'europe', 'americas')),
  competition_id TEXT REFERENCES public.competitions(id),
  start_date     TIMESTAMPTZ NOT NULL,
  end_date       TIMESTAMPTZ NOT NULL,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  banner_color   TEXT,
  description    TEXT,
  logo_url       TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on new tables with public read
DO $$ BEGIN
  ALTER TABLE public.fan_levels ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.fan_badges ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.currency_rates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.leaderboard_seasons ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.marketplace_partners ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.marketplace_offers ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.featured_events ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Public read policies
DO $$ BEGIN
  CREATE POLICY "fan_levels_public_read" ON public.fan_levels FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "fan_badges_public_read" ON public.fan_badges FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "currency_rates_public_read" ON public.currency_rates FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "leaderboard_seasons_public_read" ON public.leaderboard_seasons FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "marketplace_partners_public_read" ON public.marketplace_partners FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "marketplace_offers_public_read" ON public.marketplace_offers FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "featured_events_public_read" ON public.featured_events FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ------------------------------------------------------------------
-- 1. Fan Levels (XP progression tiers)
-- ------------------------------------------------------------------
INSERT INTO public.fan_levels (level, name, title, min_xp, icon_name, color_hex) VALUES
  (1,  'Rookie',     'Fresh Supporter',     0,      'user',       '#A8A29E'),
  (2,  'Regular',    'Matchday Regular',     100,    'star',       '#22C55E'),
  (3,  'Committed',  'Dedicated Fan',        500,    'heart',      '#0EA5E9'),
  (4,  'Veteran',    'Seasoned Predictor',   1500,   'shield',     '#8B5CF6'),
  (5,  'Expert',     'Expert Analyst',       5000,   'award',      '#F59E0B'),
  (6,  'Elite',      'Elite Tactician',      15000,  'crown',      '#EF4444'),
  (7,  'Legend',     'FANZONE Legend',        50000,  'trophy',     '#FFD700'),
  (8,  'Immortal',   'Hall of Fame',          100000, 'flame',      '#FF4500'),
  (9,  'Titan',      'Prediction Titan',      250000, 'diamond',    '#00CED1'),
  (10, 'GOAT',       'Greatest of All Time',  500000, 'zap',        '#FF1493')
ON CONFLICT (level) DO NOTHING;

-- ------------------------------------------------------------------
-- 2. Fan Badges (achievement system)
-- ------------------------------------------------------------------
INSERT INTO public.fan_badges (id, name, description, category, icon_name, color_hex, criteria_type, criteria_value) VALUES
  ('first-prediction',   'First Prediction',   'Made your first match prediction',         'milestone',  'target',      '#22C55E', 'predictions_count', 1),
  ('streak-3',           '3-Day Streak',       'Predicted 3 days in a row',                'streak',     'flame',       '#F59E0B', 'streak_days',       3),
  ('streak-7',           'Week Warrior',       'Predicted every day for a week',            'streak',     'flame',       '#EF4444', 'streak_days',       7),
  ('streak-30',          'Monthly Machine',    'Predicted every day for a month',           'streak',     'fire',        '#FF4500', 'streak_days',       30),
  ('predictions-50',     'Half Century',       'Made 50 match predictions',                'milestone',  'award',       '#8B5CF6', 'predictions_count', 50),
  ('predictions-100',    'Century Club',       'Made 100 match predictions',               'milestone',  'trophy',      '#FFD700', 'predictions_count', 100),
  ('pool-creator',       'Pool Creator',       'Created your first prediction pool',       'social',     'users',       '#0EA5E9', 'pools_created',     1),
  ('community-builder',  'Community Builder',  'Joined 5 prediction pools',                'social',     'heart',       '#EC4899', 'pools_joined',      5),
  ('correct-10',         'Sharp Eye',          'Got 10 predictions correct',               'accuracy',   'check',       '#10B981', 'correct_count',     10),
  ('correct-50',         'Oracle',             'Got 50 predictions correct',               'accuracy',   'eye',         '#6366F1', 'correct_count',     50),
  ('first-contribution', 'First Contributor',  'Made your first team contribution',        'community',  'coins',       '#F97316', 'contributions',     1),
  ('early-adopter',      'Early Adopter',      'Joined FANZONE in the first wave',         'special',    'rocket',      '#14B8A6', 'manual',            0)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------
-- 3. Currency Rates (EUR base — real-world rates Apr 2026)
-- ------------------------------------------------------------------
INSERT INTO public.currency_rates (base_currency, target_currency, rate, source, updated_at) VALUES
  ('EUR', 'EUR', 1.00,    'system',  NOW()),
  ('EUR', 'USD', 1.14,    'manual',  NOW()),
  ('EUR', 'GBP', 0.86,    'manual',  NOW()),
  ('EUR', 'RWF', 1580.00, 'manual',  NOW())
ON CONFLICT (base_currency, target_currency) DO UPDATE SET
  rate = EXCLUDED.rate,
  updated_at = NOW();

-- ------------------------------------------------------------------
-- 4. Competitions
-- ------------------------------------------------------------------
INSERT INTO public.competitions (id, name, short_name, country, tier, data_source, status, region, competition_type, is_featured) VALUES
  ('premier-league',     'Premier League',          'PL',   'England',     1, 'api', 'active', 'europe', 'league', true),
  ('la-liga',            'La Liga',                 'LL',   'Spain',       1, 'api', 'active', 'europe', 'league', true),
  ('serie-a',            'Serie A',                 'SA',   'Italy',       1, 'api', 'active', 'europe', 'league', true),
  ('bundesliga',         'Bundesliga',              'BL',   'Germany',     1, 'api', 'active', 'europe', 'league', true),
  ('ligue-1',            'Ligue 1',                 'L1',   'France',      1, 'api', 'active', 'europe', 'league', true),
  ('champions-league',   'UEFA Champions League',   'UCL',  'Europe',      1, 'api', 'active', 'europe', 'cup',    true),
  ('europa-league',      'UEFA Europa League',      'UEL',  'Europe',      1, 'api', 'active', 'europe', 'cup',    false),
  ('eredivisie',         'Eredivisie',              'ERE',  'Netherlands', 1, 'manual', 'active', 'europe', 'league', false),
  ('primeira-liga',      'Primeira Liga',           'PRI',  'Portugal',    1, 'manual', 'active', 'europe', 'league', false),
  ('scottish-prem',      'Scottish Premiership',    'SPL',  'Scotland',    1, 'manual', 'active', 'europe', 'league', false),
  ('malta-premier',      'Malta Premier League',    'MPL',  'Malta',       1, 'manual', 'active', 'europe', 'league', true),
  ('rwanda-premier',     'Rwanda Premier League',   'RPL',  'Rwanda',      1, 'manual', 'active', 'africa', 'league', true),
  ('egyptian-premier',   'Egyptian Premier League', 'EPL',  'Egypt',       1, 'manual', 'active', 'africa', 'league', false),
  ('caf-champions',      'CAF Champions League',    'CAFCL','Africa',      1, 'manual', 'active', 'africa', 'cup',    true),
  ('mls',                'Major League Soccer',     'MLS',  'USA',         1, 'manual', 'active', 'americas', 'league', false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  region = COALESCE(EXCLUDED.region, competitions.region),
  competition_type = COALESCE(EXCLUDED.competition_type, competitions.competition_type),
  is_featured = EXCLUDED.is_featured;

-- ------------------------------------------------------------------
-- 5. Leaderboard Season
-- ------------------------------------------------------------------
DO $$
DECLARE
  v_has_legacy_shape BOOLEAN;
  v_has_uuid_shape BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'leaderboard_seasons'
      AND column_name = 'start_date'
  ) INTO v_has_legacy_shape;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'leaderboard_seasons'
      AND column_name = 'starts_at'
  ) INTO v_has_uuid_shape;

  IF v_has_legacy_shape THEN
    INSERT INTO public.leaderboard_seasons (id, name, start_date, end_date, status)
    VALUES ('season-2025-26', '2025/26 Season', '2025-08-01', '2026-06-30', 'active')
    ON CONFLICT (id) DO NOTHING;
  ELSIF v_has_uuid_shape THEN
    UPDATE public.leaderboard_seasons
    SET
      season_type = 'seasonal',
      starts_at = '2025-08-01T00:00:00Z'::timestamptz,
      ends_at = '2026-06-30T23:59:59Z'::timestamptz,
      status = 'active'
    WHERE name = '2025/26 Season';

    IF NOT FOUND THEN
      INSERT INTO public.leaderboard_seasons (
        name,
        season_type,
        competition_id,
        starts_at,
        ends_at,
        status
      ) VALUES (
        '2025/26 Season',
        'seasonal',
        NULL,
        '2025-08-01T00:00:00Z'::timestamptz,
        '2026-06-30T23:59:59Z'::timestamptz,
        'active'
      );
    END IF;
  END IF;
END $$;

-- ------------------------------------------------------------------
-- 6. Marketplace
-- ------------------------------------------------------------------
DO $$
DECLARE
  v_text_partner_ids BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'marketplace_partners'
      AND column_name = 'id'
      AND data_type = 'text'
  ) INTO v_text_partner_ids;

  IF v_text_partner_ids THEN
    INSERT INTO public.marketplace_partners (id, name, description, logo_url, is_active) VALUES
      ('fanzone-merch',        'FANZONE Merch',         'Official FANZONE merchandise and collectibles', NULL, true),
      ('matchday-experiences', 'Matchday Experiences',  'Premium football experiences and events',        NULL, true)
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      logo_url = EXCLUDED.logo_url,
      is_active = EXCLUDED.is_active;

    INSERT INTO public.marketplace_offers (id, partner_id, title, description, category, cost_fet, delivery_type, is_active, original_value) VALUES
      ('offer-scarf',      'fanzone-merch',         'Club Scarf Voucher',       'Redeem for an official club scarf digital voucher.', 'merch',      120, 'voucher', true, '€20'),
      ('offer-jersey',     'fanzone-merch',         'Jersey Discount Code',     'Get a 25% discount code for official jerseys.',      'merch',      300, 'code',    true, '€50'),
      ('offer-watchparty', 'matchday-experiences',  'Watch Party Pass',         'Access to one premium live watch party event.',      'experience', 180, 'code',    true, '€30'),
      ('offer-vip',        'matchday-experiences',  'VIP Matchday Experience',  'Exclusive VIP access to a matchday event near you.', 'experience', 500, 'voucher', true, '€80')
    ON CONFLICT (id) DO UPDATE SET
      partner_id = EXCLUDED.partner_id,
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      category = EXCLUDED.category,
      cost_fet = EXCLUDED.cost_fet,
      delivery_type = EXCLUDED.delivery_type,
      is_active = EXCLUDED.is_active,
      original_value = EXCLUDED.original_value;
  ELSE
    UPDATE public.marketplace_partners
    SET
      description = 'Official FANZONE merchandise and collectibles',
      logo_url = NULL,
      category = 'merchandise',
      country = 'MT',
      is_active = true
    WHERE name = 'FANZONE Merch';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_partners (
        name,
        description,
        logo_url,
        category,
        country,
        is_active
      ) VALUES (
        'FANZONE Merch',
        'Official FANZONE merchandise and collectibles',
        NULL,
        'merchandise',
        'MT',
        true
      );
    END IF;

    UPDATE public.marketplace_partners
    SET
      description = 'Premium football experiences and events',
      logo_url = NULL,
      category = 'experience',
      country = 'MT',
      is_active = true
    WHERE name = 'Matchday Experiences';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_partners (
        name,
        description,
        logo_url,
        category,
        country,
        is_active
      ) VALUES (
        'Matchday Experiences',
        'Premium football experiences and events',
        NULL,
        'experience',
        'MT',
        true
      );
    END IF;

    UPDATE public.marketplace_offers mo
    SET
      partner_id = mp.id,
      description = 'Redeem for an official club scarf digital voucher.',
      category = 'merch',
      cost_fet = 120,
      delivery_type = 'voucher',
      is_active = true,
      original_value = '€20',
      stock = NULL,
      sort_order = 0
    FROM public.marketplace_partners mp
    WHERE mo.title = 'Club Scarf Voucher'
      AND mp.name = 'FANZONE Merch';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_offers (
        partner_id,
        title,
        description,
        category,
        cost_fet,
        delivery_type,
        is_active,
        original_value,
        stock,
        sort_order
      )
      SELECT
        mp.id,
        'Club Scarf Voucher',
        'Redeem for an official club scarf digital voucher.',
        'merch',
        120,
        'voucher',
        true,
        '€20',
        NULL,
        0
      FROM public.marketplace_partners mp
      WHERE mp.name = 'FANZONE Merch';
    END IF;

    UPDATE public.marketplace_offers mo
    SET
      partner_id = mp.id,
      description = 'Get a 25% discount code for official jerseys.',
      category = 'merch',
      cost_fet = 300,
      delivery_type = 'code',
      is_active = true,
      original_value = '€50',
      stock = NULL,
      sort_order = 1
    FROM public.marketplace_partners mp
    WHERE mo.title = 'Jersey Discount Code'
      AND mp.name = 'FANZONE Merch';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_offers (
        partner_id,
        title,
        description,
        category,
        cost_fet,
        delivery_type,
        is_active,
        original_value,
        stock,
        sort_order
      )
      SELECT
        mp.id,
        'Jersey Discount Code',
        'Get a 25% discount code for official jerseys.',
        'merch',
        300,
        'code',
        true,
        '€50',
        NULL,
        1
      FROM public.marketplace_partners mp
      WHERE mp.name = 'FANZONE Merch';
    END IF;

    UPDATE public.marketplace_offers mo
    SET
      partner_id = mp.id,
      description = 'Access to one premium live watch party event.',
      category = 'experience',
      cost_fet = 180,
      delivery_type = 'code',
      is_active = true,
      original_value = '€30',
      stock = NULL,
      sort_order = 2
    FROM public.marketplace_partners mp
    WHERE mo.title = 'Watch Party Pass'
      AND mp.name = 'Matchday Experiences';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_offers (
        partner_id,
        title,
        description,
        category,
        cost_fet,
        delivery_type,
        is_active,
        original_value,
        stock,
        sort_order
      )
      SELECT
        mp.id,
        'Watch Party Pass',
        'Access to one premium live watch party event.',
        'experience',
        180,
        'code',
        true,
        '€30',
        NULL,
        2
      FROM public.marketplace_partners mp
      WHERE mp.name = 'Matchday Experiences';
    END IF;

    UPDATE public.marketplace_offers mo
    SET
      partner_id = mp.id,
      description = 'Exclusive VIP access to a matchday event near you.',
      category = 'experience',
      cost_fet = 500,
      delivery_type = 'voucher',
      is_active = true,
      original_value = '€80',
      stock = NULL,
      sort_order = 3
    FROM public.marketplace_partners mp
    WHERE mo.title = 'VIP Matchday Experience'
      AND mp.name = 'Matchday Experiences';

    IF NOT FOUND THEN
      INSERT INTO public.marketplace_offers (
        partner_id,
        title,
        description,
        category,
        cost_fet,
        delivery_type,
        is_active,
        original_value,
        stock,
        sort_order
      )
      SELECT
        mp.id,
        'VIP Matchday Experience',
        'Exclusive VIP access to a matchday event near you.',
        'experience',
        500,
        'voucher',
        true,
        '€80',
        NULL,
        3
      FROM public.marketplace_partners mp
      WHERE mp.name = 'Matchday Experiences';
    END IF;
  END IF;
END $$;

-- ------------------------------------------------------------------
-- 7. Featured Events
-- ------------------------------------------------------------------
INSERT INTO public.featured_events (event_tag, name, short_name, description, start_date, end_date, is_active, region, competition_id) VALUES
  ('ucl-final-2026',   'UCL Final 2026',       'UCL Final', 'The biggest club match of the year — predict the champion!', '2026-05-20', '2026-05-31', true,  'global', 'champions-league'),
  ('worldcup2026',     'World Cup 2026',       'World Cup', 'FIFA World Cup 2026 kicks off in North America.',             '2026-06-11', '2026-07-19', false, 'global', NULL),
  ('launch-mt',        'FANZONE Malta Launch', 'MT Launch', 'FANZONE officially launches in Malta — join the community!',  '2026-04-01', '2026-06-30', true,  'europe', NULL)
ON CONFLICT (event_tag) DO UPDATE SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  description = EXCLUDED.description,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  is_active = EXCLUDED.is_active,
  region = EXCLUDED.region;

COMMIT;
