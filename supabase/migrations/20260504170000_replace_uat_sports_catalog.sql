-- Replace the production UAT sports feed with real Supabase-curated football data.
-- The mobile app reads teams from public.teams, competitions from public.competitions,
-- and fixtures from public.curated_active_matches/get_curated_matches.

-- Disable old UAT/demo rows without deleting them, so historical test orders/pools
-- keep referential integrity but public discovery no longer renders them.
UPDATE public.curated_matches
SET is_active = false,
    updated_at = timezone('utc', now()),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'disabled_reason', 'replaced_uat_fixture_with_real_catalog'
    )
WHERE match_id LIKE 'uat-%'
   OR coalesce(metadata ->> 'uat_fixture', 'false') = 'true'
   OR lower(reason) LIKE '%uat%';

UPDATE public.matches
SET hide_from_home = true,
    is_curated = false,
    match_status = CASE WHEN match_status = 'live' THEN 'scheduled' ELSE match_status END,
    status = CASE WHEN status = 'live' THEN 'scheduled' ELSE status END,
    updated_at = timezone('utc', now()),
    notes = trim(coalesce(notes, '') || ' Disabled: UAT fixture replaced by real catalog.')
WHERE id LIKE 'uat-%'
   OR source = 'uat_fixture'
   OR source_name = 'uat_fixture';

UPDATE public.competitions
SET is_active = false,
    is_featured = false,
    status = 'disabled',
    updated_at = timezone('utc', now())
WHERE id LIKE 'uat-%'
   OR data_source = 'uat_fixture'
   OR lower(name) LIKE '%uat%';

UPDATE public.teams
SET is_active = false,
    is_featured = false,
    is_popular_pick = false,
    updated_at = timezone('utc', now())
WHERE id LIKE 'uat-%'
   OR lower(name) LIKE '%uat%';

-- Ensure the approved competition catalog stays active for app reads.
UPDATE public.competitions
SET is_active = true,
    is_featured = true,
    status = 'active',
    updated_at = timezone('utc', now())
WHERE id IN (
  'english_premier_league',
  'la_liga',
  'serie_a',
  'ligue_1',
  'bundesliga',
  'uefa_champions_league',
  'uefa_europa_league',
  'fifa_world_cup'
);

WITH team_seed (
  id,
  name,
  short_name,
  country,
  country_code,
  region,
  league_name,
  team_type,
  competition_ids,
  aliases,
  search_terms,
  is_featured,
  is_popular_pick,
  popular_pick_rank,
  popularity_score
) AS (
  VALUES
    ('arsenal', 'Arsenal', 'ARS', 'England', 'GB', 'europe', 'English Premier League', 'club', ARRAY['english_premier_league','uefa_champions_league'], ARRAY['Arsenal FC','Gunners'], ARRAY['arsenal','gunners','london'], true, true, 10, 950),
    ('atletico_madrid', 'Atletico de Madrid', 'ATM', 'Spain', 'ES', 'europe', 'La Liga', 'club', ARRAY['la_liga','uefa_champions_league'], ARRAY['Atleti','Atletico Madrid'], ARRAY['atletico','atleti','madrid'], true, true, 11, 900),
    ('bayern_munich', 'Bayern Munich', 'BAY', 'Germany', 'DE', 'europe', 'Bundesliga', 'club', ARRAY['bundesliga','uefa_champions_league'], ARRAY['FC Bayern','Bayern Munchen'], ARRAY['bayern','munich','munchen'], true, true, 12, 940),
    ('paris_saint_germain', 'Paris Saint-Germain', 'PSG', 'France', 'FR', 'europe', 'Ligue 1', 'club', ARRAY['ligue_1','uefa_champions_league'], ARRAY['Paris','PSG'], ARRAY['paris','psg','saint germain'], true, true, 13, 930),
    ('real_madrid', 'Real Madrid', 'RMA', 'Spain', 'ES', 'europe', 'La Liga', 'club', ARRAY['la_liga','uefa_champions_league'], ARRAY['Real Madrid CF','Los Blancos'], ARRAY['real madrid','madrid','los blancos'], true, true, 1, 1000),
    ('barcelona', 'Barcelona', 'BAR', 'Spain', 'ES', 'europe', 'La Liga', 'club', ARRAY['la_liga','uefa_champions_league'], ARRAY['FC Barcelona','Barca'], ARRAY['barcelona','barca'], true, true, 2, 990),
    ('manchester_city', 'Manchester City', 'MCI', 'England', 'GB', 'europe', 'English Premier League', 'club', ARRAY['english_premier_league','uefa_champions_league'], ARRAY['Man City','City'], ARRAY['manchester city','man city','city'], true, true, 3, 980),
    ('liverpool', 'Liverpool', 'LIV', 'England', 'GB', 'europe', 'English Premier League', 'club', ARRAY['english_premier_league','uefa_champions_league'], ARRAY['Liverpool FC','Reds'], ARRAY['liverpool','reds'], true, true, 4, 970),
    ('chelsea', 'Chelsea', 'CHE', 'England', 'GB', 'europe', 'English Premier League', 'club', ARRAY['english_premier_league'], ARRAY['Chelsea FC','Blues'], ARRAY['chelsea','blues'], true, true, 5, 920),
    ('manchester_united', 'Manchester United', 'MUN', 'England', 'GB', 'europe', 'English Premier League', 'club', ARRAY['english_premier_league'], ARRAY['Man United','United'], ARRAY['manchester united','man united','united'], true, true, 6, 910),
    ('borussia_dortmund', 'Borussia Dortmund', 'BVB', 'Germany', 'DE', 'europe', 'Bundesliga', 'club', ARRAY['bundesliga'], ARRAY['BVB','Dortmund'], ARRAY['borussia dortmund','dortmund','bvb'], true, true, 14, 870),
    ('inter_milan', 'Inter Milan', 'INT', 'Italy', 'IT', 'europe', 'Serie A', 'club', ARRAY['serie_a','uefa_champions_league'], ARRAY['Internazionale','Inter'], ARRAY['inter','inter milan','internazionale'], true, true, 15, 880),
    ('ac_milan', 'AC Milan', 'MIL', 'Italy', 'IT', 'europe', 'Serie A', 'club', ARRAY['serie_a','uefa_champions_league'], ARRAY['Milan','Rossoneri'], ARRAY['ac milan','milan','rossoneri'], true, true, 16, 860),
    ('juventus', 'Juventus', 'JUV', 'Italy', 'IT', 'europe', 'Serie A', 'club', ARRAY['serie_a'], ARRAY['Juve','Bianconeri'], ARRAY['juventus','juve'], true, true, 17, 850),
    ('napoli', 'Napoli', 'NAP', 'Italy', 'IT', 'europe', 'Serie A', 'club', ARRAY['serie_a'], ARRAY['SSC Napoli'], ARRAY['napoli','ssc napoli'], true, true, 18, 830),
    ('mexico', 'Mexico', 'MEX', 'Mexico', 'MX', 'americas', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Mexico national team','El Tri'], ARRAY['mexico','el tri'], true, true, 101, 760),
    ('south_africa', 'South Africa', 'RSA', 'South Africa', 'ZA', 'africa', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Bafana Bafana'], ARRAY['south africa','bafana'], true, true, 102, 700),
    ('united_states', 'USA', 'USA', 'United States', 'US', 'americas', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['United States','USMNT'], ARRAY['usa','united states','usmnt'], true, true, 103, 780),
    ('paraguay', 'Paraguay', 'PAR', 'Paraguay', 'PY', 'americas', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Paraguay national team'], ARRAY['paraguay'], true, true, 104, 710),
    ('brazil', 'Brazil', 'BRA', 'Brazil', 'BR', 'americas', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Brasil','Selecao'], ARRAY['brazil','brasil','selecao'], true, true, 105, 900),
    ('morocco', 'Morocco', 'MAR', 'Morocco', 'MA', 'africa', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Atlas Lions'], ARRAY['morocco','atlas lions'], true, true, 106, 790),
    ('haiti', 'Haiti', 'HAI', 'Haiti', 'HT', 'americas', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Les Grenadiers'], ARRAY['haiti','grenadiers'], true, true, 107, 660),
    ('scotland', 'Scotland', 'SCO', 'Scotland', 'GB', 'europe', 'FIFA World Cup', 'national', ARRAY['fifa_world_cup'], ARRAY['Scotland national team'], ARRAY['scotland'], true, true, 108, 720)
)
INSERT INTO public.teams (
  id,
  name,
  short_name,
  country,
  country_code,
  region,
  league_name,
  team_type,
  competition_ids,
  aliases,
  search_terms,
  is_active,
  is_featured,
  is_popular_pick,
  popular_pick_rank,
  popularity_score,
  updated_at
)
SELECT
  id,
  name,
  short_name,
  country,
  country_code,
  region,
  league_name,
  team_type,
  competition_ids,
  aliases,
  search_terms,
  true,
  is_featured,
  is_popular_pick,
  popular_pick_rank,
  popularity_score,
  timezone('utc', now())
FROM team_seed
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country = EXCLUDED.country,
    country_code = EXCLUDED.country_code,
    region = EXCLUDED.region,
    league_name = EXCLUDED.league_name,
    team_type = EXCLUDED.team_type,
    competition_ids = EXCLUDED.competition_ids,
    aliases = EXCLUDED.aliases,
    search_terms = EXCLUDED.search_terms,
    is_active = true,
    is_featured = EXCLUDED.is_featured,
    is_popular_pick = EXCLUDED.is_popular_pick,
    popular_pick_rank = EXCLUDED.popular_pick_rank,
    popularity_score = EXCLUDED.popularity_score,
    updated_at = timezone('utc', now());

WITH match_seed (
  id,
  competition_id,
  home_team_id,
  away_team_id,
  venue,
  stage,
  matchday_or_round,
  match_date,
  source_url,
  source_name,
  source,
  notes,
  priority_score,
  metadata
) AS (
  VALUES
    (
      'ucl-2026-sf2-arsenal-atletico',
      'uefa_champions_league',
      'arsenal',
      'atletico_madrid',
      'Arsenal Stadium',
      'Semi-final',
      'Semi-final second leg',
      '2026-05-05 19:00:00+00'::timestamptz,
      'https://www.uefa.com/uefachampionsleague/news/02a4-2063e22b19d9-14f7369cb6fd-1000--champions-league-semi-final-ties-and-dates-confirmed/',
      'UEFA',
      'uefa_manual_curated',
      'Official UEFA 2025/26 Champions League semi-final schedule.',
      120,
      '{"tags":["global","uefa","featured"],"source":"uefa"}'::jsonb
    ),
    (
      'ucl-2026-sf2-bayern-paris',
      'uefa_champions_league',
      'bayern_munich',
      'paris_saint_germain',
      'Allianz Arena',
      'Semi-final',
      'Semi-final second leg',
      '2026-05-06 19:00:00+00'::timestamptz,
      'https://www.uefa.com/uefachampionsleague/news/02a4-2063e22b19d9-14f7369cb6fd-1000--champions-league-semi-final-ties-and-dates-confirmed/',
      'UEFA',
      'uefa_manual_curated',
      'Official UEFA 2025/26 Champions League semi-final schedule.',
      119,
      '{"tags":["global","uefa","featured"],"source":"uefa"}'::jsonb
    ),
    (
      'wc2026-group-a-mexico-south-africa',
      'fifa_world_cup',
      'mexico',
      'south_africa',
      'Mexico City Stadium',
      'Group A',
      'Group stage',
      '2026-06-11 19:00:00+00'::timestamptz,
      'https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/fifa-world-cup-26-match-schedule-revealed',
      'FIFA',
      'fifa_manual_curated',
      'Official FIFA World Cup 26 opening fixture.',
      110,
      '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb
    ),
    (
      'wc2026-group-d-usa-paraguay',
      'fifa_world_cup',
      'united_states',
      'paraguay',
      'Los Angeles Stadium',
      'Group D',
      'Group stage',
      '2026-06-13 01:00:00+00'::timestamptz,
      'https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/usa-paraguay-preview-live-stream-team-news-tickets',
      'FIFA',
      'fifa_manual_curated',
      'Official FIFA World Cup 26 group-stage fixture.',
      109,
      '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb
    ),
    (
      'wc2026-group-c-brazil-morocco',
      'fifa_world_cup',
      'brazil',
      'morocco',
      'New York New Jersey Stadium',
      'Group C',
      'Group stage',
      '2026-06-13 22:00:00+00'::timestamptz,
      'https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/brazil-morocco-preview-live-stream-team-news-tickets',
      'FIFA',
      'fifa_manual_curated',
      'Official FIFA World Cup 26 group-stage fixture.',
      108,
      '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb
    )
)
INSERT INTO public.matches (
  id,
  competition_id,
  home_team_id,
  away_team_id,
  venue,
  stage,
  matchday_or_round,
  match_date,
  match_status,
  status,
  is_neutral,
  source_url,
  source_name,
  source,
  notes,
  is_curated,
  hide_from_home,
  is_home_featured,
  home_feature_rank,
  country_visibility,
  updated_at
)
SELECT
  id,
  competition_id,
  home_team_id,
  away_team_id,
  venue,
  stage,
  matchday_or_round,
  match_date,
  'scheduled',
  'scheduled',
  false,
  source_url,
  source_name,
  source,
  notes,
  true,
  false,
  true,
  priority_score,
  ARRAY['MT','RW','GB','US']::text[],
  timezone('utc', now())
FROM match_seed
ON CONFLICT (id) DO UPDATE
SET competition_id = EXCLUDED.competition_id,
    home_team_id = EXCLUDED.home_team_id,
    away_team_id = EXCLUDED.away_team_id,
    venue = EXCLUDED.venue,
    stage = EXCLUDED.stage,
    matchday_or_round = EXCLUDED.matchday_or_round,
    match_date = EXCLUDED.match_date,
    match_status = 'scheduled',
    status = 'scheduled',
    is_neutral = EXCLUDED.is_neutral,
    source_url = EXCLUDED.source_url,
    source_name = EXCLUDED.source_name,
    source = EXCLUDED.source,
    notes = EXCLUDED.notes,
    is_curated = true,
    hide_from_home = false,
    is_home_featured = true,
    home_feature_rank = EXCLUDED.home_feature_rank,
    country_visibility = EXCLUDED.country_visibility,
    updated_at = timezone('utc', now());

WITH match_seed (id, priority_score, metadata) AS (
  VALUES
    ('ucl-2026-sf2-arsenal-atletico', 120, '{"tags":["global","uefa","featured"],"source":"uefa"}'::jsonb),
    ('ucl-2026-sf2-bayern-paris', 119, '{"tags":["global","uefa","featured"],"source":"uefa"}'::jsonb),
    ('wc2026-group-a-mexico-south-africa', 110, '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb),
    ('wc2026-group-d-usa-paraguay', 109, '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb),
    ('wc2026-group-c-brazil-morocco', 108, '{"tags":["global","world_cup","featured"],"source":"fifa"}'::jsonb)
)
INSERT INTO public.curated_matches (
  match_id,
  country_code,
  venue_id,
  priority_score,
  reason,
  metadata,
  starts_at,
  expires_at,
  is_active,
  updated_at
)
SELECT
  id,
  NULL,
  NULL,
  priority_score,
  'Production sports catalog seed',
  metadata,
  NULL,
  NULL,
  true,
  timezone('utc', now())
FROM match_seed
ON CONFLICT (
  match_id,
  coalesce(country_code, ''::text),
  coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
) DO UPDATE
SET priority_score = EXCLUDED.priority_score,
    reason = EXCLUDED.reason,
    metadata = EXCLUDED.metadata,
    is_active = true,
    updated_at = timezone('utc', now());
