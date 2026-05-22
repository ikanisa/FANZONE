SELECT 'Seeding authenticated UAT fixtures...' AS status;

BEGIN;

-- UAT fixtures are inserted as deterministic seed data. Mark the transaction
-- as service-role context so production auth-owned-entry triggers remain
-- unchanged while fixed reviewer personas can be created.
SELECT set_config('request.jwt.claim.role', 'service_role', true);

CREATE TEMP TABLE uat_fixture_users (
  id uuid PRIMARY KEY,
  phone text NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  label text NOT NULL,
  fan_id text NOT NULL UNIQUE,
  persona text NOT NULL
) ON COMMIT DROP;

INSERT INTO uat_fixture_users (id, phone, email, label, fan_id, persona)
VALUES
  ('00000000-0000-4000-8000-000000000101', '+35699711145', 'uat-review-owner@fanzone.test', 'UAT Review Owner', '910101', 'admin_owner'),
  ('00000000-0000-4000-8000-000000000102', '+35699711146', 'uat-venue-manager@fanzone.test', 'UAT Venue Manager', '910102', 'venue_manager'),
  ('00000000-0000-4000-8000-000000000103', '+35699711147', 'uat-venue-staff@fanzone.test', 'UAT Venue Staff', '910103', 'venue_staff'),
  ('00000000-0000-4000-8000-000000000104', '+35699711148', 'uat-eligible-guest@fanzone.test', 'UAT Eligible Guest', '910104', 'eligible_guest'),
  ('00000000-0000-4000-8000-000000000105', '+35699711149', 'uat-ineligible-guest@fanzone.test', 'UAT Ineligible Guest', '910105', 'ineligible_guest');

DELETE FROM auth.identities i
USING uat_fixture_users u
WHERE i.provider = 'phone'
  AND i.provider_id = u.phone
  AND i.user_id <> u.id;

DELETE FROM auth.users a
USING uat_fixture_users u
WHERE (a.phone = u.phone OR a.email = u.email)
  AND a.id <> u.id;

DELETE FROM public.profiles p
USING uat_fixture_users u
WHERE p.fan_id = u.fan_id
  AND p.user_id <> u.id;

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  phone,
  phone_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_anonymous
)
SELECT
  '00000000-0000-0000-0000-000000000000'::uuid,
  id,
  'authenticated',
  'authenticated',
  email,
  NULL,
  timezone('utc', now()),
  phone,
  timezone('utc', now()),
  '{"provider":"phone","providers":["phone"]}'::jsonb,
  jsonb_build_object(
    'phone', phone,
    'phone_verified', true,
    'display_name', label,
    'uat_fixture', true,
    'persona', persona
  ),
  timezone('utc', now()),
  timezone('utc', now()),
  false
FROM uat_fixture_users
ON CONFLICT (id) DO UPDATE
SET aud = EXCLUDED.aud,
    role = EXCLUDED.role,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    phone_confirmed_at = EXCLUDED.phone_confirmed_at,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = timezone('utc', now()),
    is_anonymous = false;

INSERT INTO auth.identities (
  id,
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  CASE persona
    WHEN 'admin_owner' THEN '00000000-0000-4000-8000-000000001101'::uuid
    WHEN 'venue_manager' THEN '00000000-0000-4000-8000-000000001102'::uuid
    WHEN 'venue_staff' THEN '00000000-0000-4000-8000-000000001103'::uuid
    WHEN 'eligible_guest' THEN '00000000-0000-4000-8000-000000001104'::uuid
    ELSE '00000000-0000-4000-8000-000000001105'::uuid
  END,
  phone,
  id,
  jsonb_build_object('sub', id::text, 'phone', phone, 'phone_verified', true),
  'phone',
  timezone('utc', now()),
  timezone('utc', now()),
  timezone('utc', now())
FROM uat_fixture_users
ON CONFLICT (provider_id, provider) DO UPDATE
SET user_id = EXCLUDED.user_id,
    identity_data = EXCLUDED.identity_data,
    updated_at = timezone('utc', now());

INSERT INTO public.profiles (
  id,
  user_id,
  fan_id,
  display_name,
  phone_number,
  country_code,
  active_country,
  currency_code,
  onboarding_completed,
  allow_fan_discovery,
  is_anonymous,
  auth_method
)
SELECT
  id,
  id,
  fan_id,
  label,
  phone,
  '+356',
  'MT',
  'EUR',
  true,
  false,
  false,
  'phone'
FROM uat_fixture_users
ON CONFLICT (user_id) DO UPDATE
SET fan_id = EXCLUDED.fan_id,
    display_name = EXCLUDED.display_name,
    phone_number = EXCLUDED.phone_number,
    country_code = EXCLUDED.country_code,
    active_country = EXCLUDED.active_country,
    currency_code = EXCLUDED.currency_code,
    onboarding_completed = true,
    is_anonymous = false,
    auth_method = 'phone',
    updated_at = timezone('utc', now());

INSERT INTO public.admin_users (
  user_id,
  email,
  display_name,
  role,
  is_active,
  whatsapp_number,
  phone
)
SELECT id, email, label, 'admin', true, phone, phone
FROM uat_fixture_users
WHERE persona = 'admin_owner'
ON CONFLICT (user_id) DO UPDATE
SET email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    role = EXCLUDED.role,
    is_active = true,
    whatsapp_number = EXCLUDED.whatsapp_number,
    phone = EXCLUDED.phone,
    updated_at = timezone('utc', now());

INSERT INTO public.countries (id, name, iso_code, region, is_active, rollout_priority)
VALUES
  ('00000000-0000-4000-8000-000000000201', 'Malta', 'MT', 'europe', true, 1),
  ('00000000-0000-4000-8000-000000000202', 'Rwanda', 'RW', 'africa', true, 2),
  ('00000000-0000-4000-8000-000000000203', 'United Kingdom', 'GB', 'europe', true, 3)
ON CONFLICT (iso_code) DO UPDATE
SET name = EXCLUDED.name,
    region = EXCLUDED.region,
    is_active = true,
    rollout_priority = EXCLUDED.rollout_priority,
    updated_at = timezone('utc', now());

INSERT INTO public.competitions (
  id,
  name,
  short_name,
  country,
  data_source,
  seasons,
  season,
  status,
  region,
  competition_type,
  country_or_region,
  is_international,
  is_active,
  country_id,
  type,
  priority
)
VALUES (
  'uat-premier-league-2026',
  'UAT Premier League',
  'UAT PL',
  'GB',
  'uat_fixture',
  ARRAY['2026'],
  '2026',
  'active',
  'europe',
  'league',
  'GB',
  false,
  true,
  (SELECT id FROM public.countries WHERE iso_code = 'GB'),
  'league',
  1
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country = EXCLUDED.country,
    data_source = EXCLUDED.data_source,
    seasons = EXCLUDED.seasons,
    season = EXCLUDED.season,
    status = EXCLUDED.status,
    region = EXCLUDED.region,
    competition_type = EXCLUDED.competition_type,
    country_or_region = EXCLUDED.country_or_region,
    is_active = true,
    country_id = EXCLUDED.country_id,
    type = EXCLUDED.type,
    priority = EXCLUDED.priority,
    updated_at = timezone('utc', now());

INSERT INTO public.seasons (id, competition_id, season_label, start_year, end_year, is_current)
VALUES ('uat-premier-league-2026-season', 'uat-premier-league-2026', '2026', 2026, 2026, true)
ON CONFLICT (id) DO UPDATE
SET season_label = EXCLUDED.season_label,
    is_current = true,
    updated_at = timezone('utc', now());

INSERT INTO public.teams (
  id,
  name,
  short_name,
  country,
  competition_ids,
  country_code,
  league_name,
  is_active,
  is_featured,
  team_type,
  country_id,
  popularity_score
)
VALUES
  ('uat-home-lions', 'UAT Home Lions', 'Lions', 'GB', ARRAY['uat-premier-league-2026'], 'GB', 'UAT Premier League', true, true, 'club', (SELECT id FROM public.countries WHERE iso_code = 'GB'), 50),
  ('uat-away-harbors', 'UAT Away Harbors', 'Harbors', 'GB', ARRAY['uat-premier-league-2026'], 'GB', 'UAT Premier League', true, true, 'club', (SELECT id FROM public.countries WHERE iso_code = 'GB'), 49)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country = EXCLUDED.country,
    competition_ids = EXCLUDED.competition_ids,
    country_code = EXCLUDED.country_code,
    league_name = EXCLUDED.league_name,
    is_active = true,
    is_featured = EXCLUDED.is_featured,
    team_type = EXCLUDED.team_type,
    country_id = EXCLUDED.country_id,
    popularity_score = EXCLUDED.popularity_score,
    updated_at = timezone('utc', now());

INSERT INTO public.matches (
  id,
  competition_id,
  home_team_id,
  away_team_id,
  venue,
  season_id,
  stage,
  matchday_or_round,
  match_date,
  match_status,
  starts_at,
  status,
  source,
  source_name,
  is_curated,
  country_visibility
)
VALUES (
  'uat-match-2026-05-03',
  'uat-premier-league-2026',
  'uat-home-lions',
  'uat-away-harbors',
  'UAT Live Sports Bar',
  'uat-premier-league-2026-season',
  'League',
  'Round 1',
  timezone('utc', now()) + interval '1 hour',
  'scheduled',
  timezone('utc', now()) + interval '1 hour',
  'scheduled',
  'uat_fixture',
  'uat_fixture',
  true,
  ARRAY['MT', 'RW', 'GB']
)
ON CONFLICT (id) DO UPDATE
SET match_date = EXCLUDED.match_date,
    starts_at = EXCLUDED.starts_at,
    match_status = EXCLUDED.match_status,
    status = EXCLUDED.status,
    is_curated = true,
    country_visibility = EXCLUDED.country_visibility,
    updated_at = timezone('utc', now());

DELETE FROM public.venues
WHERE slug = 'uat-live-sports-bar'
  AND id <> '00000000-0000-4000-8000-000000000301';

INSERT INTO public.venues (
  id,
  owner_id,
  owner_user_id,
  name,
  slug,
  country_code,
  country_id,
  venue_type,
  type,
  currency_code,
  description,
  address_line1,
  address,
  city,
  timezone,
  is_open,
  is_active,
  onboarding_status,
  status,
  revolut_link,
  momo_code,
  whatsapp,
  primary_category,
  rating,
  price_level,
  claimed,
  verified_at,
  fet_reward_percent,
  accepts_fet_spend,
  payment_methods,
  hours_json,
  features_json
)
VALUES (
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000101',
  'UAT Live Sports Bar',
  'uat-live-sports-bar',
  'MT',
  (SELECT id FROM public.countries WHERE iso_code = 'MT'),
  'bar',
  'sports_bar',
  'EUR',
  'Deterministic live UAT venue for authenticated dashboard, admin, and TV screen validation.',
  '1 UAT Street',
  '1 UAT Street, St Julian''s',
  'St Julian''s',
  'Europe/Malta',
  true,
  true,
  'live',
  'active',
  'https://revolut.me/fanzone-uat',
  NULL,
  '+35699711145',
  'Sports bar',
  4.70,
  2,
  true,
  timezone('utc', now()),
  10.00,
  false,
  ARRAY['revolut', 'cash'],
  '{"monday":{"open":"12:00","close":"23:30"},"tuesday":{"open":"12:00","close":"23:30"},"wednesday":{"open":"12:00","close":"23:30"},"thursday":{"open":"12:00","close":"23:30"},"friday":{"open":"12:00","close":"01:00"},"saturday":{"open":"12:00","close":"01:00"},"sunday":{"open":"12:00","close":"23:30"}}'::jsonb,
  '{"uat_fixture":true,"screens":["dashboard","tv"],"eligibility_window_minutes":120}'::jsonb
)
ON CONFLICT (id) DO UPDATE
SET owner_id = EXCLUDED.owner_id,
    owner_user_id = EXCLUDED.owner_user_id,
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    country_code = EXCLUDED.country_code,
    country_id = EXCLUDED.country_id,
    venue_type = EXCLUDED.venue_type,
    type = EXCLUDED.type,
    currency_code = EXCLUDED.currency_code,
    description = EXCLUDED.description,
    address_line1 = EXCLUDED.address_line1,
    address = EXCLUDED.address,
    city = EXCLUDED.city,
    timezone = EXCLUDED.timezone,
    is_open = true,
    is_active = true,
    onboarding_status = 'live',
    status = 'active',
    revolut_link = EXCLUDED.revolut_link,
    whatsapp = EXCLUDED.whatsapp,
    primary_category = EXCLUDED.primary_category,
    rating = EXCLUDED.rating,
    price_level = EXCLUDED.price_level,
    claimed = true,
    verified_at = EXCLUDED.verified_at,
    fet_reward_percent = EXCLUDED.fet_reward_percent,
    accepts_fet_spend = EXCLUDED.accepts_fet_spend,
    payment_methods = EXCLUDED.payment_methods,
    hours_json = EXCLUDED.hours_json,
    features_json = EXCLUDED.features_json,
    updated_at = timezone('utc', now());

INSERT INTO public.venue_users (venue_id, user_id, role, is_active, invited_by)
VALUES
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', 'owner', true, NULL),
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000102', 'manager', true, '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000103', 'staff', true, '00000000-0000-4000-8000-000000000101')
ON CONFLICT (venue_id, user_id) DO UPDATE
SET role = EXCLUDED.role,
    is_active = true,
    invited_by = EXCLUDED.invited_by,
    updated_at = timezone('utc', now());

DELETE FROM public.tables
WHERE venue_id = '00000000-0000-4000-8000-000000000301'
  AND table_number = 'UAT-1'
  AND id <> '00000000-0000-4000-8000-000000000302';

INSERT INTO public.tables (
  id,
  venue_id,
  table_number,
  is_active
)
VALUES (
  '00000000-0000-4000-8000-000000000302',
  '00000000-0000-4000-8000-000000000301',
  'UAT-1',
  true
)
ON CONFLICT (id) DO UPDATE
SET venue_id = EXCLUDED.venue_id,
    table_number = EXCLUDED.table_number,
    is_active = true,
    updated_at = timezone('utc', now());

INSERT INTO public.menu_categories (id, venue_id, name, display_order, is_visible)
VALUES ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000301', 'UAT Match Day', 1, true)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    is_visible = true,
    updated_at = timezone('utc', now());

INSERT INTO public.menu_items (
  id,
  venue_id,
  category_id,
  name,
  description,
  price,
  currency_code,
  is_available,
  is_featured,
  display_order,
  metadata
)
VALUES
  ('00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000303', 'UAT Burger Combo', 'Burger, fries, and a soft drink for live order UAT.', 12.50, 'EUR', true, true, 1, '{"uat_fixture":true,"fet_earn_percent_override":10}'::jsonb),
  ('00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000303', 'UAT Zero Beer', 'Alcohol-free match day drink for menu browsing UAT.', 4.50, 'EUR', true, false, 2, '{"uat_fixture":true,"fet_earn_percent_override":5}'::jsonb)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    currency_code = EXCLUDED.currency_code,
    is_available = true,
    is_featured = EXCLUDED.is_featured,
    display_order = EXCLUDED.display_order,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());

DELETE FROM public.payment_events
WHERE external_reference IN ('UAT-REVOLUT-PAID-001', 'UAT-REVOLUT-UNPAID-001');

DELETE FROM public.orders
WHERE order_code IN ('UATPAID01', 'UATUNPAID1')
  AND id NOT IN (
    '00000000-0000-4000-8000-000000000306',
    '00000000-0000-4000-8000-000000000307'
  );

INSERT INTO public.orders (
  id,
  venue_id,
  table_id,
  user_id,
  order_code,
  status,
  payment_method,
  payment_status,
  payment_reference,
  currency_code,
  subtotal_amount,
  tax_amount,
  tip_amount,
  total_amount,
  accepted_at,
  status_changed_at,
  created_at,
  fet_earned
)
VALUES
  ('00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000104', 'UATPAID01', 'received', 'revolut', 'paid', 'UAT-REVOLUT-PAID-001', 'EUR', 12.50, 0, 0, 12.50, timezone('utc', now()) - interval '8 minutes', timezone('utc', now()) - interval '8 minutes', timezone('utc', now()) - interval '10 minutes', 25),
  ('00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000105', 'UATUNPAID1', 'received', 'revolut', 'unpaid', 'UAT-REVOLUT-UNPAID-001', 'EUR', 4.50, 0, 0, 4.50, timezone('utc', now()) - interval '8 minutes', timezone('utc', now()) - interval '8 minutes', timezone('utc', now()) - interval '10 minutes', 0)
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    payment_method = EXCLUDED.payment_method,
    payment_status = EXCLUDED.payment_status,
    payment_reference = EXCLUDED.payment_reference,
    subtotal_amount = EXCLUDED.subtotal_amount,
    total_amount = EXCLUDED.total_amount,
    accepted_at = EXCLUDED.accepted_at,
    status_changed_at = EXCLUDED.status_changed_at,
    created_at = EXCLUDED.created_at,
    fet_earned = EXCLUDED.fet_earned,
    updated_at = timezone('utc', now());

INSERT INTO public.order_state_events (
  id,
  order_id,
  venue_id,
  actor_user_id,
  previous_status,
  next_status,
  reason,
  source,
  metadata,
  created_at
)
VALUES
  ('00000000-0000-4000-8000-000000000311', '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000102', 'submitted', 'accepted', 'UAT seed accepted paid order', 'uat_seed', '{"uat_fixture":true}'::jsonb, timezone('utc', now()) - interval '8 minutes'),
  ('00000000-0000-4000-8000-000000000312', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000102', 'submitted', 'accepted', 'UAT seed accepted unpaid order', 'uat_seed', '{"uat_fixture":true}'::jsonb, timezone('utc', now()) - interval '8 minutes')
ON CONFLICT (id) DO UPDATE
SET previous_status = EXCLUDED.previous_status,
    next_status = EXCLUDED.next_status,
    reason = EXCLUDED.reason,
    source = EXCLUDED.source,
    metadata = EXCLUDED.metadata,
    created_at = EXCLUDED.created_at;

INSERT INTO public.order_items (
  id,
  order_id,
  menu_item_id,
  item_name_snapshot,
  item_description_snapshot,
  quantity,
  unit_price,
  line_total,
  currency_code
)
VALUES
  ('00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000304', 'UAT Burger Combo', 'Burger, fries, and a soft drink for live order UAT.', 1, 12.50, 12.50, 'EUR'),
  ('00000000-0000-4000-8000-000000000309', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000305', 'UAT Zero Beer', 'Alcohol-free match day drink for menu browsing UAT.', 1, 4.50, 4.50, 'EUR')
ON CONFLICT (id) DO UPDATE
SET item_name_snapshot = EXCLUDED.item_name_snapshot,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    line_total = EXCLUDED.line_total;

INSERT INTO public.payment_events (
  id,
  order_id,
  provider,
  status,
  external_reference,
  request_payload,
  response_payload
)
VALUES (
  '00000000-0000-4000-8000-000000000310',
  '00000000-0000-4000-8000-000000000306',
  'revolut',
  'paid',
  'UAT-REVOLUT-PAID-001',
  '{"source":"uat_seed","provider_api_used":false}'::jsonb,
  '{"manual_confirmation":true,"amount":12.50,"currency":"EUR"}'::jsonb
)
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    request_payload = EXCLUDED.request_payload,
    response_payload = EXCLUDED.response_payload,
    updated_at = timezone('utc', now());

INSERT INTO public.fet_wallets (
  user_id,
  id,
  available_balance_fet,
  staked_balance_fet,
  pending_balance_fet,
  locked_balance_fet,
  balance_available,
  balance_staked,
  balance_pending
)
VALUES
  ('00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000701', 500, 25, 0, 25, 500, 25, 0),
  ('00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000702', 175, 25, 0, 25, 175, 25, 0)
ON CONFLICT (user_id) DO UPDATE
SET id = EXCLUDED.id,
    available_balance_fet = EXCLUDED.available_balance_fet,
    staked_balance_fet = EXCLUDED.staked_balance_fet,
    pending_balance_fet = EXCLUDED.pending_balance_fet,
    locked_balance_fet = EXCLUDED.locked_balance_fet,
    balance_available = EXCLUDED.balance_available,
    balance_staked = EXCLUDED.balance_staked,
    balance_pending = EXCLUDED.balance_pending,
    updated_at = timezone('utc', now());

INSERT INTO public.match_pools (
  id,
  match_id,
  scope,
  country_code,
  venue_id,
  creator_user_id,
  title,
  status,
  is_official,
  entry_fee_fet,
  stake_min_fet,
  stake_max_fet,
  min_participants,
  total_members,
  total_staked_fet,
  creator_reward_fet,
  share_slug,
  share_url,
  metadata,
  rules_json,
  deep_link_url
)
VALUES (
  '00000000-0000-4000-8000-000000000401',
  'uat-match-2026-05-03',
  'venue',
  'MT',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000101',
  'UAT Home Lions vs Away Harbors',
  'open',
  true,
  25,
  25,
  25,
  2,
  2,
  50,
  0,
  'uatlivepool20260503',
  '/pools/uatlivepool20260503',
  jsonb_build_object(
    'uat_fixture', true,
    'creator_stake_fet', 400,
    'participant_stake_fet', 25,
    'eligibility_window_minutes', 120,
    'linked_bar_required', true
  ),
  jsonb_build_object(
    'options', jsonb_build_array('home_win', 'draw', 'away_win'),
    'settlement_requires_paid_order', true,
    'eligibility_window_minutes', 120
  ),
  'fanzone://pools/uatlivepool20260503'
)
ON CONFLICT (id) DO UPDATE
SET match_id = EXCLUDED.match_id,
    scope = EXCLUDED.scope,
    country_code = EXCLUDED.country_code,
    venue_id = EXCLUDED.venue_id,
    creator_user_id = EXCLUDED.creator_user_id,
    title = EXCLUDED.title,
    status = EXCLUDED.status,
    is_official = EXCLUDED.is_official,
    entry_fee_fet = EXCLUDED.entry_fee_fet,
    stake_min_fet = EXCLUDED.stake_min_fet,
    stake_max_fet = EXCLUDED.stake_max_fet,
    min_participants = EXCLUDED.min_participants,
    total_members = EXCLUDED.total_members,
    total_staked_fet = EXCLUDED.total_staked_fet,
    creator_reward_fet = EXCLUDED.creator_reward_fet,
    share_slug = EXCLUDED.share_slug,
    share_url = EXCLUDED.share_url,
    metadata = EXCLUDED.metadata,
    rules_json = EXCLUDED.rules_json,
    deep_link_url = EXCLUDED.deep_link_url,
    updated_at = timezone('utc', now());

INSERT INTO public.match_pool_camps (
  id,
  pool_id,
  code,
  camp_key,
  label,
  result_code,
  display_order,
  member_count,
  total_staked_fet,
  team_id,
  is_winning_camp
)
VALUES
  ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000401', 'home', 'home', 'Home win', 'H', 1, 1, 25, 'uat-home-lions', false),
  ('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000401', 'draw', 'draw', 'Draw', 'D', 2, 0, 0, NULL, false),
  ('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000401', 'away', 'away', 'Away win', 'A', 3, 1, 25, 'uat-away-harbors', false)
ON CONFLICT (id) DO UPDATE
SET label = EXCLUDED.label,
    result_code = EXCLUDED.result_code,
    display_order = EXCLUDED.display_order,
    member_count = EXCLUDED.member_count,
    total_staked_fet = EXCLUDED.total_staked_fet,
    team_id = EXCLUDED.team_id,
    is_winning_camp = EXCLUDED.is_winning_camp,
    updated_at = timezone('utc', now());

INSERT INTO public.match_pool_entries (
  id,
  pool_id,
  camp_id,
  user_id,
  amount_fet,
  status,
  payout_fet,
  source,
  metadata
)
VALUES
  ('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000104', 25, 'active', 0, 'venue_qr', '{"uat_fixture":true,"eligibility":"eligible"}'::jsonb),
  ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000105', 25, 'active', 0, 'venue_qr', '{"uat_fixture":true,"eligibility":"order_required"}'::jsonb)
ON CONFLICT (id) DO UPDATE
SET camp_id = EXCLUDED.camp_id,
    amount_fet = EXCLUDED.amount_fet,
    status = EXCLUDED.status,
    payout_fet = EXCLUDED.payout_fet,
    source = EXCLUDED.source,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());

INSERT INTO public.fet_wallet_transactions (
  id,
  user_id,
  wallet_id,
  tx_type,
  transaction_type,
  direction,
  amount_fet,
  balance_before_fet,
  balance_after_fet,
  reference_type,
  reference_id,
  match_id,
  pool_id,
  pool_entry_id,
  order_id,
  venue_id,
  title,
  source,
  status,
  idempotency_key,
  metadata
)
VALUES
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000701', 'wallet_welcome_bonus', 'welcome_credit', 'credit', 500, 0, 500, 'uat_seed', 'welcome-eligible', NULL, NULL, NULL, NULL, NULL, 'UAT welcome FET', 'uat_seed', 'posted', 'uat:eligible:welcome', '{"uat_fixture":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000701', 'order_reward', 'order_earn', 'credit', 25, 500, 525, 'order', '00000000-0000-4000-8000-000000000306', NULL, NULL, NULL, '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000301', 'UAT order FET earned', 'order_reward', 'posted', 'uat:eligible:order_reward', '{"uat_fixture":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000603', '00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000701', 'match_pool_entry', 'pool_stake', 'debit', 25, 525, 500, 'pool_entry', '00000000-0000-4000-8000-000000000405', 'uat-match-2026-05-03', '00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000405', NULL, '00000000-0000-4000-8000-000000000301', 'UAT pool stake', 'match_pool_entry', 'posted', 'uat:eligible:pool_stake', '{"uat_fixture":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000702', 'wallet_welcome_bonus', 'welcome_credit', 'credit', 200, 0, 200, 'uat_seed', 'welcome-ineligible', NULL, NULL, NULL, NULL, NULL, 'UAT welcome FET', 'uat_seed', 'posted', 'uat:ineligible:welcome', '{"uat_fixture":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000605', '00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000702', 'match_pool_entry', 'pool_stake', 'debit', 25, 200, 175, 'pool_entry', '00000000-0000-4000-8000-000000000406', 'uat-match-2026-05-03', '00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000406', NULL, '00000000-0000-4000-8000-000000000301', 'UAT pool stake', 'match_pool_entry', 'posted', 'uat:ineligible:pool_stake', '{"uat_fixture":true}'::jsonb)
ON CONFLICT (id) DO UPDATE
SET amount_fet = EXCLUDED.amount_fet,
    balance_before_fet = EXCLUDED.balance_before_fet,
    balance_after_fet = EXCLUDED.balance_after_fet,
    reference_type = EXCLUDED.reference_type,
    reference_id = EXCLUDED.reference_id,
    match_id = EXCLUDED.match_id,
    pool_id = EXCLUDED.pool_id,
    pool_entry_id = EXCLUDED.pool_entry_id,
    order_id = EXCLUDED.order_id,
    venue_id = EXCLUDED.venue_id,
    title = EXCLUDED.title,
    source = EXCLUDED.source,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;

INSERT INTO public.venue_fet_wallets (
  venue_id,
  available_balance_fet,
  staked_balance_fet,
  pending_balance_fet
)
VALUES ('00000000-0000-4000-8000-000000000301', 12000, 400, 0)
ON CONFLICT (venue_id) DO UPDATE
SET available_balance_fet = EXCLUDED.available_balance_fet,
    staked_balance_fet = EXCLUDED.staked_balance_fet,
    pending_balance_fet = EXCLUDED.pending_balance_fet,
    updated_at = timezone('utc', now());

INSERT INTO public.venue_fet_wallet_transactions (
  id,
  venue_id,
  transaction_type,
  direction,
  amount_fet,
  balance_bucket,
  balance_before_fet,
  balance_after_fet,
  reference_type,
  reference_id,
  pool_id,
  game_session_id,
  idempotency_key,
  title,
  status,
  metadata,
  created_by
)
VALUES
  ('00000000-0000-4000-8000-000000000611', '00000000-0000-4000-8000-000000000301', 'bar_fet_top_up', 'credit', 12400, 'available', 0, 12400, 'uat_seed', 'venue-top-up', NULL, NULL, 'uat:venue:top_up', 'UAT venue wallet top-up', 'posted', '{"uat_fixture":true}'::jsonb, '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000612', '00000000-0000-4000-8000-000000000301', 'game_reward_pool', 'debit', 400, 'available', 12400, 12000, 'game_session', '00000000-0000-4000-8000-000000000501', NULL, '00000000-0000-4000-8000-000000000501', 'uat:venue:game_reward_pool', 'UAT game reward allocation', 'posted', '{"uat_fixture":true}'::jsonb, '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000613', '00000000-0000-4000-8000-000000000301', 'pool_creator_stake', 'credit', 400, 'staked', 0, 400, 'pool', '00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000401', NULL, 'uat:venue:pool_creator_stake', 'UAT pool creator stake reserve', 'posted', '{"uat_fixture":true}'::jsonb, '00000000-0000-4000-8000-000000000101')
ON CONFLICT (id) DO UPDATE
SET amount_fet = EXCLUDED.amount_fet,
    balance_before_fet = EXCLUDED.balance_before_fet,
    balance_after_fet = EXCLUDED.balance_after_fet,
    reference_type = EXCLUDED.reference_type,
    reference_id = EXCLUDED.reference_id,
    pool_id = EXCLUDED.pool_id,
    game_session_id = EXCLUDED.game_session_id,
    title = EXCLUDED.title,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;

INSERT INTO public.game_templates (id, name, category, is_active)
VALUES
  ('bar_trivia', 'Bar Trivia', 'trivia', true),
  ('fan_trivia', 'Fan Trivia', 'trivia', true),
  ('music_bingo', 'Music Bingo', 'music_bingo', true),
  ('song_guess', 'Song Guess', 'song_guess', true)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    is_active = true,
    updated_at = timezone('utc', now());

DELETE FROM public.game_answers
WHERE session_id = '00000000-0000-4000-8000-000000000501';

DELETE FROM public.game_team_members
WHERE session_id = '00000000-0000-4000-8000-000000000501';

DELETE FROM public.game_teams
WHERE session_id = '00000000-0000-4000-8000-000000000501';

DELETE FROM public.game_session_questions
WHERE session_id = '00000000-0000-4000-8000-000000000501';

DELETE FROM public.game_sessions
WHERE id = '00000000-0000-4000-8000-000000000501';

DELETE FROM public.game_questions
WHERE template_id = 'fan_trivia'
  AND metadata->>'uat_fixture' = 'true';

INSERT INTO public.game_questions (
  template_id,
  category,
  prompt,
  options,
  correct_answer,
  is_active,
  approved_at,
  metadata
)
SELECT
  'fan_trivia',
  'football',
  format('UAT Fan Trivia question %s: choose the correct match-day answer.', lpad(gs::text, 3, '0')),
  jsonb_build_array('Home win', 'Draw', 'Away win', 'VAR review'),
  CASE gs % 4
    WHEN 1 THEN 'Home win'
    WHEN 2 THEN 'Draw'
    WHEN 3 THEN 'Away win'
    ELSE 'VAR review'
  END,
  true,
  timezone('utc', now()),
  jsonb_build_object('uat_fixture', true, 'question_number', gs)
FROM generate_series(1, 110) AS gs;

INSERT INTO public.game_sessions (
  id,
  venue_id,
  template_id,
  status,
  scheduled_start_at,
  started_at,
  reward_fet,
  selected_question_count,
  current_question_ordinal,
  created_by,
  metadata
)
VALUES (
  '00000000-0000-4000-8000-000000000501',
  '00000000-0000-4000-8000-000000000301',
  'fan_trivia',
  'live',
  timezone('utc', now()) + interval '1 hour',
  timezone('utc', now()) - interval '5 minutes',
  400,
  20,
  1,
  '00000000-0000-4000-8000-000000000101',
  '{"uat_fixture":true,"eligibility_window_minutes":120,"selected_question_policy":"20_stable_questions"}'::jsonb
);

WITH selected AS (
  SELECT
    q.id,
    q.prompt,
    q.options,
    q.correct_answer,
    q.template_id,
    q.created_at,
    row_number() OVER (ORDER BY (q.metadata->>'question_number')::integer) AS ordinal
  FROM public.game_questions q
  WHERE q.template_id = 'fan_trivia'
    AND q.is_active = true
    AND q.approved_at IS NOT NULL
    AND q.metadata->>'uat_fixture' = 'true'
  ORDER BY (q.metadata->>'question_number')::integer
  LIMIT 20
)
INSERT INTO public.game_session_questions (session_id, question_id, ordinal, snapshot)
SELECT
  '00000000-0000-4000-8000-000000000501',
  id,
  ordinal,
  jsonb_build_object(
    'prompt', prompt,
    'options', options,
    'correct_answer', correct_answer,
    'template_id', template_id,
    'question_created_at', created_at,
    'uat_fixture', true
  )
FROM selected;

INSERT INTO public.game_teams (
  id,
  session_id,
  venue_id,
  name,
  created_by_user_id,
  score_fet,
  invite_code,
  metadata
)
VALUES
  ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000301', 'UAT Red Camp', '00000000-0000-4000-8000-000000000104', 20, 'uatred2026', '{"uat_fixture":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000301', 'UAT Blue Camp', '00000000-0000-4000-8000-000000000105', 0, 'uatblue2026', '{"uat_fixture":true}'::jsonb)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    score_fet = EXCLUDED.score_fet,
    invite_code = EXCLUDED.invite_code,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());

INSERT INTO public.game_team_members (team_id, session_id, user_id, role)
VALUES
  ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000104', 'captain'),
  ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000105', 'captain')
ON CONFLICT (team_id, user_id) DO UPDATE
SET role = EXCLUDED.role;

WITH first_question AS (
  SELECT question_id
  FROM public.game_session_questions
  WHERE session_id = '00000000-0000-4000-8000-000000000501'
    AND ordinal = 1
)
INSERT INTO public.game_answers (
  id,
  session_id,
  question_id,
  team_id,
  user_id,
  answer_text,
  is_correct,
  is_first_correct,
  awarded_fet,
  metadata
)
SELECT
  '00000000-0000-4000-8000-000000000504',
  '00000000-0000-4000-8000-000000000501',
  question_id,
  '00000000-0000-4000-8000-000000000502',
  '00000000-0000-4000-8000-000000000104',
  'Home win',
  true,
  true,
  20,
  '{"uat_fixture":true,"validation":"first_correct"}'::jsonb
FROM first_question
ON CONFLICT (id) DO UPDATE
SET answer_text = EXCLUDED.answer_text,
    is_correct = true,
    is_first_correct = true,
    awarded_fet = EXCLUDED.awarded_fet,
    metadata = EXCLUDED.metadata;

INSERT INTO public.venue_screen_states (
  venue_id,
  mode,
  active_pool_id,
  active_game_session_id,
  payload,
  updated_by
)
VALUES (
  '00000000-0000-4000-8000-000000000301',
  'game_question',
  '00000000-0000-4000-8000-000000000401',
  '00000000-0000-4000-8000-000000000501',
  '{"uat_fixture":true,"headline":"UAT Fan Trivia Live","qr_path":"/venue/uat-live-sports-bar","eligibility_window_minutes":120}'::jsonb,
  '00000000-0000-4000-8000-000000000101'
)
ON CONFLICT (venue_id) DO UPDATE
SET mode = EXCLUDED.mode,
    active_pool_id = EXCLUDED.active_pool_id,
    active_game_session_id = EXCLUDED.active_game_session_id,
    payload = EXCLUDED.payload,
    updated_by = EXCLUDED.updated_by,
    updated_at = timezone('utc', now());

INSERT INTO public.curated_matches (
  id,
  match_id,
  country_code,
  venue_id,
  priority_score,
  is_active,
  reason,
  curated_by,
  starts_at,
  expires_at,
  metadata
)
VALUES (
  '00000000-0000-4000-8000-000000000407',
  'uat-match-2026-05-03',
  'MT',
  '00000000-0000-4000-8000-000000000301',
  100,
  true,
  'UAT live fixture',
  '00000000-0000-4000-8000-000000000101',
  timezone('utc', now()) + interval '1 hour',
  timezone('utc', now()) + interval '4 hours',
  '{"uat_fixture":true}'::jsonb
)
ON CONFLICT (id) DO UPDATE
SET priority_score = EXCLUDED.priority_score,
    is_active = true,
    starts_at = EXCLUDED.starts_at,
    expires_at = EXCLUDED.expires_at,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());

COMMIT;

SELECT 'Authenticated UAT fixtures seeded.' AS status;
