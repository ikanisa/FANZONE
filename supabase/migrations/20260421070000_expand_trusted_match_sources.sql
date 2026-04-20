BEGIN;

-- ============================================================
-- 20260421070000_expand_trusted_match_sources.sql
--
-- Expands trusted_match_sources from 10 → 40+ entries covering:
-- - Official federations (UEFA, FIFA, Malta FA, etc.)
-- - Official league match centres (EPL, La Liga, Serie A, etc.)
-- - Top live score platforms (Flashscore, Livescore, Sofascore, etc.)
-- - Top betting/odds platforms (bet365, FanDuel, DraftKings, etc.)
-- - Analytics & reference sites (FBref, WhoScored, Transfermarkt)
--
-- Uses Gemini Deep Research grounding to identify the most
-- reliable sources globally for live match data verification.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Step 1: Expand source_type CHECK to include new categories
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.trusted_match_sources
  DROP CONSTRAINT IF EXISTS trusted_match_sources_source_type_check;

ALTER TABLE public.trusted_match_sources
  ADD CONSTRAINT trusted_match_sources_source_type_check
  CHECK (source_type IN (
    'official_match_centre',
    'official_federation',
    'official_competition',
    'live_score_platform',
    'betting_odds_platform',
    'analytics_reference',
    'trusted_reference',
    'news_media',
    'unknown'
  ));

-- ──────────────────────────────────────────────────────────────
-- Step 2: Upsert all sources (ON CONFLICT updates existing)
-- ──────────────────────────────────────────────────────────────

INSERT INTO public.trusted_match_sources (
  domain_pattern,
  source_name,
  source_type,
  trust_score,
  notes
)
VALUES

  -- ═══════════════════════════════════════════════════════════
  -- TIER 1: Official Federations (trust_score: 1.0)
  -- These are the governing bodies; their data is law.
  -- ═══════════════════════════════════════════════════════════

  ('uefa.com', 'UEFA', 'official_federation', 1.0000,
   'Official UEFA; covers UCL, UEL, UECL, Nations League. Canonical source for European competitions.'),

  ('fifa.com', 'FIFA', 'official_federation', 1.0000,
   'Official FIFA; covers World Cup, Club World Cup, intl friendlies. Canonical source for global competitions.'),

  ('mfa.com.mt', 'Malta Football Association', 'official_federation', 1.0000,
   'Official Malta FA; primary source for Malta Premier League fixtures, results, and standings.'),

  ('new.mfa.com.mt', 'Malta FA (new site)', 'official_federation', 1.0000,
   'Rebranded Malta FA website. Same authority as mfa.com.mt.'),

  ('live.mfa.com.mt', 'Malta FA Live', 'official_match_centre', 1.0000,
   'Official live match centre on Malta FA infrastructure. Real-time scores for Maltese league.'),

  ('thefa.com', 'The Football Association (England)', 'official_federation', 1.0000,
   'Official English FA; covers FA Cup, Community Shield.'),

  ('rfef.es', 'Real Federación Española de Fútbol', 'official_federation', 1.0000,
   'Official Spanish FA; covers Copa del Rey, Spanish Super Cup.'),

  ('figc.it', 'Federazione Italiana Giuoco Calcio', 'official_federation', 1.0000,
   'Official Italian FA; covers Coppa Italia.'),

  ('dfb.de', 'Deutscher Fußball-Bund', 'official_federation', 1.0000,
   'Official German FA; covers DFB-Pokal.'),

  ('fff.fr', 'Fédération Française de Football', 'official_federation', 1.0000,
   'Official French FA; covers Coupe de France.'),

  -- ═══════════════════════════════════════════════════════════
  -- TIER 2: Official League Match Centres (trust_score: 0.97–0.99)
  -- Official league websites with live match centres.
  -- ═══════════════════════════════════════════════════════════

  ('premierleague.com', 'Premier League', 'official_match_centre', 0.9900,
   'Official EPL match centre. Live scores, stats, lineups. Canonical for English top flight.'),

  ('laliga.com', 'La Liga', 'official_match_centre', 0.9900,
   'Official La Liga match centre. Canonical for Spanish top flight.'),

  ('legaseriea.it', 'Lega Serie A', 'official_match_centre', 0.9900,
   'Official Serie A match centre. Canonical for Italian top flight.'),

  ('bundesliga.com', 'Bundesliga', 'official_match_centre', 0.9900,
   'Official Bundesliga match centre. Canonical for German top flight.'),

  ('ligue1.com', 'Ligue 1', 'official_match_centre', 0.9900,
   'Official Ligue 1 match centre. Canonical for French top flight.'),

  ('eredivisie.nl', 'Eredivisie', 'official_match_centre', 0.9800,
   'Official Eredivisie match centre. Canonical for Dutch top flight.'),

  ('ligaportugal.pt', 'Liga Portugal', 'official_match_centre', 0.9800,
   'Official Portuguese league. Canonical for Primeira Liga.'),

  -- ═══════════════════════════════════════════════════════════
  -- TIER 3: Top Live Score Platforms (trust_score: 0.82–0.92)
  -- These are the most widely-used, reliable live score
  -- platforms globally. Used for cross-verification.
  -- ═══════════════════════════════════════════════════════════

  ('flashscore.com', 'Flashscore', 'live_score_platform', 0.9200,
   'World #1 live score platform. Fastest updates, broadest coverage (1000+ leagues). Primary fallback source.'),

  ('livescore.com', 'LiveScore', 'live_score_platform', 0.9100,
   'One of the oldest live score platforms. Excellent reliability and clean data feed.'),

  ('sofascore.com', 'Sofascore', 'live_score_platform', 0.9100,
   'Known for deep in-game stats, player ratings, heatmaps. Top-tier data quality.'),

  ('fotmob.com', 'FotMob', 'live_score_platform', 0.9000,
   'Highly-rated mobile-first live scores. Excellent match insights and xG data.'),

  ('soccerway.com', 'Soccerway', 'live_score_platform', 0.8800,
   'Comprehensive stats and historical data. Opta-powered. Strong structured data.'),

  ('besoccer.com', 'BeSoccer', 'live_score_platform', 0.8600,
   'Massive coverage including lower leagues, youth, and women''s football.'),

  ('livescore.in', 'LiveScore.in', 'live_score_platform', 0.8400,
   'Popular in Asia/India. Fast live updates.'),

  ('goal.com', 'Goal.com', 'live_score_platform', 0.8400,
   'Major football media with live scores section. Good for match results and context.'),

  ('livegoals.com', 'LiveGoals', 'live_score_platform', 0.8200,
   'Specialized live tracking platform favored by betting community. Fast goal alerts.'),

  ('worldfootball.net', 'worldfootball.net', 'live_score_platform', 0.8000,
   'Historical and live reference. Good for obscure leagues.'),

  -- ═══════════════════════════════════════════════════════════
  -- TIER 4: Top Betting/Odds Platforms (trust_score: 0.78–0.88)
  -- Major licensed sportsbooks with live match data.
  -- Used for odds verification and live score cross-check.
  -- ═══════════════════════════════════════════════════════════

  ('bet365.com', 'bet365', 'betting_odds_platform', 0.8800,
   'World''s largest online sportsbook. Best in-play odds variety. Live streaming available.'),

  ('fanduel.com', 'FanDuel', 'betting_odds_platform', 0.8600,
   'Top US sportsbook. User-friendly live betting with fast score updates.'),

  ('draftkings.com', 'DraftKings', 'betting_odds_platform', 0.8600,
   'Major US sportsbook. First-to-market odds, extensive prop options.'),

  ('betmgm.com', 'BetMGM', 'betting_odds_platform', 0.8400,
   'Leading US sportsbook. Comprehensive live menus and in-play markets.'),

  ('williamhill.com', 'William Hill', 'betting_odds_platform', 0.8400,
   'UK''s #1 traditional bookmaker. Decades of reliability. Strong odds data.'),

  ('paddypower.com', 'Paddy Power', 'betting_odds_platform', 0.8200,
   'Major UK/Ireland bookmaker. Strong football coverage.'),

  ('betfair.com', 'Betfair', 'betting_odds_platform', 0.8200,
   'Exchange-based betting platform. Most liquid in-play markets. Odds are market-driven.'),

  ('unibet.com', 'Unibet', 'betting_odds_platform', 0.8100,
   'European sportsbook with strong live betting coverage across all major leagues.'),

  ('bwin.com', 'bwin', 'betting_odds_platform', 0.8000,
   'Major European sportsbook. Long-established with reliable odds data.'),

  ('ladbrokes.com', 'Ladbrokes', 'betting_odds_platform', 0.8000,
   'Historic UK bookmaker (est. 1886). Strong football in-play markets.'),

  ('betway.com', 'Betway', 'betting_odds_platform', 0.7900,
   'Global sportsbook with EPL and La Liga partnerships. Good African market coverage.'),

  ('1xbet.com', '1xBet', 'betting_odds_platform', 0.7800,
   'Global sportsbook with extensive match coverage. Popular in Africa and CIS markets.'),

  -- ═══════════════════════════════════════════════════════════
  -- TIER 5: Analytics & Reference Sites (trust_score: 0.75–0.85)
  -- These provide deep stats, not always real-time, but
  -- excellent for verification and historical accuracy.
  -- ═══════════════════════════════════════════════════════════

  ('fbref.com', 'FBref (Sports Reference)', 'analytics_reference', 0.8500,
   'Gold standard for advanced football analytics. xG, passing networks, player data. StatsBomb powered.'),

  ('whoscored.com', 'WhoScored', 'analytics_reference', 0.8400,
   'Opta-powered player stats and tactical analysis. Strong match ratings.'),

  ('transfermarkt.com', 'Transfermarkt', 'analytics_reference', 0.8200,
   'Definitive source for transfer values, squad data, and career stats.'),

  ('understat.com', 'Understat', 'analytics_reference', 0.7800,
   'Advanced stats (xG, xA) for top 5 leagues. Open data model.'),

  -- ═══════════════════════════════════════════════════════════
  -- TIER 6: News/Media Sources (trust_score: 0.72–0.80)
  -- Major sports media with reliable match reporting.
  -- ═══════════════════════════════════════════════════════════

  ('bbc.co.uk', 'BBC Sport', 'news_media', 0.8000,
   'BBC Sport football section. Highly reliable for EPL results and goal updates.'),

  ('espn.com', 'ESPN', 'news_media', 0.7800,
   'ESPN FC. Global sports media with live score tracker.'),

  ('skysports.com', 'Sky Sports', 'news_media', 0.7600,
   'UK premier sports broadcaster. Live match blog and score updates for EPL.'),

  ('theguardian.com', 'The Guardian', 'news_media', 0.7400,
   'The Guardian football section. Reliable match reports and minute-by-minute coverage.'),

  ('marca.com', 'Marca', 'news_media', 0.7400,
   'Spain''s #1 sports daily. Canonical for La Liga reporting.'),

  ('gazzetta.it', 'La Gazzetta dello Sport', 'news_media', 0.7400,
   'Italy''s #1 sports daily. Canonical for Serie A reporting.'),

  ('kicker.de', 'Kicker', 'news_media', 0.7400,
   'Germany''s #1 football magazine. Canonical for Bundesliga reporting.'),

  ('lequipe.fr', 'L''Équipe', 'news_media', 0.7400,
   'France''s #1 sports daily. Canonical for Ligue 1 reporting.')

ON CONFLICT (domain_pattern) DO UPDATE
SET
  source_name  = EXCLUDED.source_name,
  source_type  = EXCLUDED.source_type,
  trust_score  = EXCLUDED.trust_score,
  notes        = EXCLUDED.notes,
  updated_at   = timezone('utc', now());

-- ──────────────────────────────────────────────────────────────
-- Step 3: Log final count
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.trusted_match_sources
  WHERE active = true;

  RAISE NOTICE 'Active trusted match sources: %', v_count;
END $$;

COMMIT;
