-- ============================================================
-- FANZONE Production Reference Data Seed
-- Purpose: Ensure all reference/lookup tables have complete data
-- Safe: Uses ON CONFLICT DO NOTHING — re-runnable without side effects
-- ============================================================

BEGIN;

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
-- 3. Currency Rates (EUR base)
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
-- 4. Competitions (top leagues + regional)
-- ------------------------------------------------------------------
INSERT INTO public.competitions (id, name, short_name, country, tier, data_source, status, region, competition_type, is_featured) VALUES
  -- Europe Top 5
  ('premier-league',     'Premier League',          'PL',   'England',     1, 'api', 'active', 'europe', 'league', true),
  ('la-liga',            'La Liga',                 'LL',   'Spain',       1, 'api', 'active', 'europe', 'league', true),
  ('serie-a',            'Serie A',                 'SA',   'Italy',       1, 'api', 'active', 'europe', 'league', true),
  ('bundesliga',         'Bundesliga',              'BL',   'Germany',     1, 'api', 'active', 'europe', 'league', true),
  ('ligue-1',            'Ligue 1',                 'L1',   'France',      1, 'api', 'active', 'europe', 'league', true),
  -- UEFA
  ('champions-league',   'UEFA Champions League',   'UCL',  'Europe',      1, 'api', 'active', 'europe', 'cup',    true),
  ('europa-league',      'UEFA Europa League',      'UEL',  'Europe',      2, 'api', 'active', 'europe', 'cup',    false),
  -- Regional
  ('eredivisie',         'Eredivisie',              'ERE',  'Netherlands', 1, 'manual', 'active', 'europe', 'league', false),
  ('primeira-liga',      'Primeira Liga',           'PRI',  'Portugal',    1, 'manual', 'active', 'europe', 'league', false),
  ('scottish-prem',      'Scottish Premiership',    'SPL',  'Scotland',    1, 'manual', 'active', 'europe', 'league', false),
  -- Malta
  ('malta-premier',      'Malta Premier League',    'MPL',  'Malta',       1, 'manual', 'active', 'europe', 'league', true),
  -- Africa
  ('rwanda-premier',     'Rwanda Premier League',   'RPL',  'Rwanda',      1, 'manual', 'active', 'africa', 'league', true),
  ('egyptian-premier',   'Egyptian Premier League', 'EPL',  'Egypt',       1, 'manual', 'active', 'africa', 'league', false),
  ('caf-champions',      'CAF Champions League',    'CAFCL','Africa',      1, 'manual', 'active', 'africa', 'cup',    true),
  -- Americas  
  ('mls',                'Major League Soccer',     'MLS',  'USA',         1, 'manual', 'active', 'americas', 'league', false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  region = COALESCE(EXCLUDED.region, competitions.region),
  competition_type = COALESCE(EXCLUDED.competition_type, competitions.competition_type),
  is_featured = EXCLUDED.is_featured;

-- ------------------------------------------------------------------
-- 5. Leaderboard Season (current active season)
-- ------------------------------------------------------------------
INSERT INTO public.leaderboard_seasons (id, name, start_date, end_date, status) VALUES
  ('season-2025-26', '2025/26 Season', '2025-08-01', '2026-06-30', 'active')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------
-- 6. Marketplace Partners + Offers
-- ------------------------------------------------------------------
INSERT INTO public.marketplace_partners (id, name, description, logo_url, is_active) VALUES
  ('fanzone-merch',     'FANZONE Merch',        'Official FANZONE merchandise and collectibles',  NULL, true),
  ('matchday-experiences', 'Matchday Experiences', 'Premium football experiences and events',       NULL, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketplace_offers (id, partner_id, title, description, category, cost_fet, delivery_type, is_active, original_value) VALUES
  ('offer-scarf',       'fanzone-merch',         'Club Scarf Voucher',         'Redeem for an official club scarf digital voucher.',         'merch',       120, 'voucher', true, '€20'),
  ('offer-jersey',      'fanzone-merch',         'Jersey Discount Code',       'Get a 25% discount code for official jerseys.',              'merch',       300, 'code',    true, '€50'),
  ('offer-watchparty',  'matchday-experiences',  'Watch Party Pass',           'Access to one premium live watch party event.',               'experience',  180, 'code',    true, '€30'),
  ('offer-vip',         'matchday-experiences',  'VIP Matchday Experience',    'Exclusive VIP access to a matchday event near you.',          'experience',  500, 'manual',  true, '€80')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------
-- 7. Featured Events (current/upcoming)
-- ------------------------------------------------------------------
INSERT INTO public.featured_events (id, name, event_tag, description, start_date, end_date, is_active, banner_url, region) VALUES
  ('ucl-final-2026',     'UCL Final 2026',    'ucl-final-2026',    'The biggest club match of the year — predict the champion!',  '2026-05-20', '2026-05-31', true,  NULL, 'global'),
  ('world-cup-2026',     'World Cup 2026',    'worldcup2026',      'FIFA World Cup 2026 kicks off in North America.',              '2026-06-11', '2026-07-19', false, NULL, 'global'),
  ('fanzone-launch-mt',  'FANZONE Malta Launch', 'launch-mt',      'FANZONE officially launches in Malta — join the community!',   '2026-04-01', '2026-06-30', true,  NULL, 'europe')
ON CONFLICT (id) DO NOTHING;

COMMIT;
