-- Deterministic mobile UAT fixtures for the customer Flutter app.
-- These rows are public-read app fixtures, not customer payment or cash data.

INSERT INTO public.venues (
  id,
  name,
  slug,
  country_code,
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
  features_json,
  updated_at
)
VALUES (
  '00000000-0000-4000-8000-000000000301',
  'UAT Live Sports Bar',
  'uat-live-sports-bar',
  'MT',
  'bar',
  'sports_bar',
  'EUR',
  'Deterministic UAT venue for mobile venue discovery, menu browsing, and table-number order smoke.',
  '1 UAT Street',
  '1 UAT Street, St Julian''s',
  'St Julian''s',
  'Europe/Malta',
  true,
  true,
  'live',
  'active',
  'https://revolut.me/fanzone-uat',
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
  '{"uat_fixture":true,"mobile_smoke":true,"eligibility_window_minutes":120}'::jsonb,
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    country_code = EXCLUDED.country_code,
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

INSERT INTO public.menu_categories (
  id,
  venue_id,
  name,
  display_order,
  is_visible,
  updated_at
)
VALUES (
  '00000000-0000-4000-8000-000000000303',
  '00000000-0000-4000-8000-000000000301',
  'UAT Match Day',
  1,
  true,
  timezone('utc', now())
)
ON CONFLICT (id) DO UPDATE
SET venue_id = EXCLUDED.venue_id,
    name = EXCLUDED.name,
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
  metadata,
  updated_at
)
VALUES
  (
    '00000000-0000-4000-8000-000000000304',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000303',
    'UAT Burger Combo',
    'Burger, fries, and a soft drink for live order UAT.',
    12.50,
    'EUR',
    true,
    true,
    1,
    '{"uat_fixture":true,"mobile_smoke":true,"fet_earn_percent_override":10}'::jsonb,
    timezone('utc', now())
  ),
  (
    '00000000-0000-4000-8000-000000000305',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000303',
    'UAT Zero Beer',
    'Alcohol-free match day drink for menu browsing UAT.',
    4.50,
    'EUR',
    true,
    false,
    2,
    '{"uat_fixture":true,"mobile_smoke":true,"fet_earn_percent_override":5}'::jsonb,
    timezone('utc', now())
  )
ON CONFLICT (id) DO UPDATE
SET venue_id = EXCLUDED.venue_id,
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    currency_code = EXCLUDED.currency_code,
    is_available = true,
    is_featured = EXCLUDED.is_featured,
    display_order = EXCLUDED.display_order,
    metadata = EXCLUDED.metadata,
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
  is_featured,
  region,
  competition_type,
  country_or_region,
  is_active,
  type,
  priority
)
VALUES (
  'uat-premier-league-2026',
  'UAT Premier League',
  'UAT PL',
  'Malta',
  'uat_fixture',
  ARRAY['2026'],
  '2026',
  'active',
  false,
  'europe',
  'league',
  'MT',
  true,
  'league',
  100
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country = EXCLUDED.country,
    data_source = EXCLUDED.data_source,
    seasons = EXCLUDED.seasons,
    season = EXCLUDED.season,
    status = EXCLUDED.status,
    is_featured = EXCLUDED.is_featured,
    region = EXCLUDED.region,
    competition_type = EXCLUDED.competition_type,
    country_or_region = EXCLUDED.country_or_region,
    is_active = true,
    type = EXCLUDED.type,
    priority = EXCLUDED.priority,
    updated_at = timezone('utc', now());

INSERT INTO public.seasons (
  id,
  competition_id,
  season_label,
  start_year,
  end_year,
  is_current
)
VALUES (
  'uat-premier-league-2026-season',
  'uat-premier-league-2026',
  '2026',
  2026,
  2026,
  true
)
ON CONFLICT (id) DO UPDATE
SET competition_id = EXCLUDED.competition_id,
    season_label = EXCLUDED.season_label,
    start_year = EXCLUDED.start_year,
    end_year = EXCLUDED.end_year,
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
  popularity_score
)
VALUES
  (
    'uat-home-lions',
    'UAT Home Lions',
    'Lions',
    'Malta',
    ARRAY['uat-premier-league-2026'],
    'MT',
    'UAT Premier League',
    true,
    true,
    'club',
    50
  ),
  (
    'uat-away-harbors',
    'UAT Away Harbors',
    'Harbors',
    'Malta',
    ARRAY['uat-premier-league-2026'],
    'MT',
    'UAT Premier League',
    true,
    true,
    'club',
    49
  )
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
  'uat-match-2026-mobile',
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
  ARRAY['MT']
)
ON CONFLICT (id) DO UPDATE
SET match_date = EXCLUDED.match_date,
    starts_at = EXCLUDED.starts_at,
    match_status = EXCLUDED.match_status,
    status = EXCLUDED.status,
    source = EXCLUDED.source,
    source_name = EXCLUDED.source_name,
    is_curated = true,
    country_visibility = EXCLUDED.country_visibility,
    updated_at = timezone('utc', now());

INSERT INTO public.curated_matches (
  id,
  match_id,
  country_code,
  venue_id,
  priority_score,
  is_active,
  reason,
  starts_at,
  expires_at,
  metadata,
  is_pool_eligible
)
VALUES (
  '00000000-0000-4000-8000-000000000407',
  'uat-match-2026-mobile',
  'MT',
  '00000000-0000-4000-8000-000000000301',
  100,
  true,
  'Mobile UAT pool fixture',
  timezone('utc', now()) - interval '5 minutes',
  timezone('utc', now()) + interval '4 hours',
  '{"uat_fixture":true,"mobile_smoke":true,"pool_eligible":true}'::jsonb,
  true
)
ON CONFLICT (id) DO UPDATE
SET match_id = EXCLUDED.match_id,
    country_code = EXCLUDED.country_code,
    venue_id = EXCLUDED.venue_id,
    priority_score = EXCLUDED.priority_score,
    is_active = true,
    reason = EXCLUDED.reason,
    starts_at = EXCLUDED.starts_at,
    expires_at = EXCLUDED.expires_at,
    metadata = EXCLUDED.metadata,
    is_pool_eligible = true,
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
  deep_link_url,
  allow_multiple
)
VALUES (
  '00000000-0000-4000-8000-000000000401',
  'uat-match-2026-mobile',
  'venue',
  'MT',
  '00000000-0000-4000-8000-000000000301',
  NULL,
  'UAT Home Lions vs Away Harbors',
  'open',
  true,
  25,
  25,
  25,
  2,
  0,
  0,
  0,
  'uat-mobile-pool-2026',
  '/pools/uat-mobile-pool-2026',
  jsonb_build_object(
    'uat_fixture', true,
    'mobile_smoke', true,
    'participant_stake_fet', 25,
    'linked_bar_required', true
  ),
  jsonb_build_object(
    'options',
    jsonb_build_array('home_win', 'draw', 'away_win'),
    'settlement_requires_paid_order',
    false,
    'eligibility_window_minutes',
    120
  ),
  'fanzone://pools/uat-mobile-pool-2026',
  false
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
    allow_multiple = EXCLUDED.allow_multiple,
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
  (
    '00000000-0000-4000-8000-000000000402',
    '00000000-0000-4000-8000-000000000401',
    'home',
    'home',
    'Home win',
    'H',
    1,
    0,
    0,
    'uat-home-lions',
    false
  ),
  (
    '00000000-0000-4000-8000-000000000403',
    '00000000-0000-4000-8000-000000000401',
    'draw',
    'draw',
    'Draw',
    'D',
    2,
    0,
    0,
    NULL,
    false
  ),
  (
    '00000000-0000-4000-8000-000000000404',
    '00000000-0000-4000-8000-000000000401',
    'away',
    'away',
    'Away win',
    'A',
    3,
    0,
    0,
    'uat-away-harbors',
    false
  )
ON CONFLICT (id) DO UPDATE
SET code = EXCLUDED.code,
    camp_key = EXCLUDED.camp_key,
    label = EXCLUDED.label,
    result_code = EXCLUDED.result_code,
    display_order = EXCLUDED.display_order,
    member_count = EXCLUDED.member_count,
    total_staked_fet = EXCLUDED.total_staked_fet,
    team_id = EXCLUDED.team_id,
    is_winning_camp = EXCLUDED.is_winning_camp,
    updated_at = timezone('utc', now());

INSERT INTO public.game_templates (id, name, category, is_active, updated_at)
VALUES
  ('fan_trivia', 'Fan Trivia', 'trivia', true, timezone('utc', now())),
  ('music_bingo', 'Music Bingo', 'music_bingo', true, timezone('utc', now())),
  ('song_guess', 'Song Guess', 'song_guess', true, timezone('utc', now()))
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    is_active = true,
    updated_at = timezone('utc', now());

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
  metadata,
  updated_at
)
VALUES
  (
    '00000000-0000-4000-8000-000000000501',
    '00000000-0000-4000-8000-000000000301',
    'fan_trivia',
    'live',
    timezone('utc', now()) + interval '1 hour',
    timezone('utc', now()) - interval '5 minutes',
    400,
    20,
    1,
    '{"uat_fixture":true,"mobile_smoke":true,"selected_question_policy":"app_visible_entry"}'::jsonb,
    timezone('utc', now())
  ),
  (
    '00000000-0000-4000-8000-000000000504',
    '00000000-0000-4000-8000-000000000301',
    'song_guess',
    'lobby',
    timezone('utc', now()) + interval '90 minutes',
    NULL,
    250,
    12,
    1,
    '{"uat_fixture":true,"mobile_smoke":true,"selected_question_policy":"song_guess_entry"}'::jsonb,
    timezone('utc', now())
  ),
  (
    '00000000-0000-4000-8000-000000000505',
    '00000000-0000-4000-8000-000000000301',
    'music_bingo',
    'scheduled',
    timezone('utc', now()) + interval '2 hours',
    NULL,
    300,
    0,
    NULL,
    '{"uat_fixture":true,"mobile_smoke":true,"selected_question_policy":"bingo_card_entry"}'::jsonb,
    timezone('utc', now())
  )
ON CONFLICT (id) DO UPDATE
SET venue_id = EXCLUDED.venue_id,
    template_id = EXCLUDED.template_id,
    status = EXCLUDED.status,
    scheduled_start_at = EXCLUDED.scheduled_start_at,
    started_at = EXCLUDED.started_at,
    reward_fet = EXCLUDED.reward_fet,
    selected_question_count = EXCLUDED.selected_question_count,
    current_question_ordinal = EXCLUDED.current_question_ordinal,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());
