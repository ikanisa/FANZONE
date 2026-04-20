BEGIN;

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS aliases text[] NOT NULL DEFAULT '{}'::text[];

UPDATE public.teams
SET aliases = COALESCE(search_terms, '{}'::text[])
WHERE aliases IS NULL OR aliases = '{}'::text[];

CREATE TABLE IF NOT EXISTS public.onboarding_popular_teams (
  id text PRIMARY KEY REFERENCES public.teams(id) ON DELETE CASCADE,
  name text NOT NULL,
  short_name text,
  country text,
  country_code text,
  league_name text,
  region text NOT NULL DEFAULT 'europe',
  logo_url text,
  crest_url text,
  aliases text[] NOT NULL DEFAULT '{}'::text[],
  search_terms text[] NOT NULL DEFAULT '{}'::text[],
  is_popular_pick boolean NOT NULL DEFAULT true,
  popular_pick_rank integer NOT NULL,
  is_featured boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT onboarding_popular_teams_rank_check
    CHECK (popular_pick_rank > 0),
  CONSTRAINT onboarding_popular_teams_region_check
    CHECK (region IN ('europe', 'africa', 'americas', 'global'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_onboarding_popular_teams_rank
  ON public.onboarding_popular_teams (popular_pick_rank)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_onboarding_popular_teams_active_region
  ON public.onboarding_popular_teams (is_active, region, popular_pick_rank);

ALTER TABLE public.onboarding_popular_teams ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'onboarding_popular_teams'
      AND policyname = 'Public read onboarding popular teams'
  ) THEN
    CREATE POLICY "Public read onboarding popular teams"
      ON public.onboarding_popular_teams
      FOR SELECT
      USING (true);
  END IF;
END $$;

GRANT SELECT ON public.onboarding_popular_teams TO anon, authenticated;

CREATE TEMP TABLE temp_onboarding_popular_team_seed (
  team_id text PRIMARY KEY,
  popular_pick_rank integer NOT NULL,
  display_name text NOT NULL,
  crest_url text NOT NULL,
  aliases text[] NOT NULL DEFAULT '{}'::text[]
) ON COMMIT DROP;

INSERT INTO temp_onboarding_popular_team_seed (
  team_id,
  popular_pick_rank,
  display_name,
  crest_url,
  aliases
)
VALUES
  ('es-real-madrid', 1, 'Real Madrid', 'https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg', '{}'::text[]),
  ('es-barcelona', 2, 'Barcelona', 'https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg', ARRAY['Barca']),
  ('gb-arsenal', 3, 'Arsenal', 'https://upload.wikimedia.org/wikipedia/en/5/53/Arsenal_FC.svg', '{}'::text[]),
  ('gb-manchester-city', 4, 'Manchester City', 'https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg', ARRAY['Man City']),
  ('gb-manchester-united', 5, 'Manchester United', 'https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg', ARRAY['Man United']),
  ('gb-liverpool', 6, 'Liverpool', 'https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg', '{}'::text[]),
  ('gb-chelsea', 7, 'Chelsea', 'https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg', '{}'::text[]),
  ('gb-tottenham-hotspur', 8, 'Tottenham Hotspur', 'https://upload.wikimedia.org/wikipedia/en/b/b4/Tottenham_Hotspur.svg', ARRAY['Tottenham', 'Spurs']),
  ('de-bayern-munich', 9, 'Bayern Munich', 'https://upload.wikimedia.org/wikipedia/commons/8/8d/FC_Bayern_M%C3%BCnchen_logo_%282024%29.svg', ARRAY['Bayern']),
  ('de-borussia-dortmund', 10, 'Borussia Dortmund', 'https://upload.wikimedia.org/wikipedia/commons/6/67/Borussia_Dortmund_logo.svg', ARRAY['Dortmund', 'BVB']),
  ('fr-paris-saint-germain', 11, 'PSG', 'https://upload.wikimedia.org/wikipedia/en/a/a7/Paris_Saint-Germain_F.C..svg', ARRAY['Paris Saint-Germain']),
  ('it-juventus', 12, 'Juventus', 'https://upload.wikimedia.org/wikipedia/commons/b/bc/Juventus_FC_2017_icon_%28black%29.svg', '{}'::text[]),
  ('it-ac-milan', 13, 'AC Milan', 'https://upload.wikimedia.org/wikipedia/commons/d/da/Associazione_Calcio_Milan.svg', '{}'::text[]),
  ('it-inter-milan', 14, 'Inter Milan', 'https://upload.wikimedia.org/wikipedia/commons/0/05/FC_Internazionale_Milano_2021.svg', '{}'::text[]),
  ('it-ssc-napoli', 15, 'Napoli', 'https://upload.wikimedia.org/wikipedia/commons/2/2d/SSC_Neapel.svg', ARRAY['SSC Napoli']),
  ('es-atletico-madrid', 16, 'Atletico Madrid', 'https://upload.wikimedia.org/wikipedia/en/f/f9/Atletico_Madrid_Logo_2024.svg', ARRAY['Atleti']),
  ('nl-ajax', 17, 'Ajax', 'https://upload.wikimedia.org/wikipedia/en/7/79/Ajax_Amsterdam.svg', '{}'::text[]),
  ('pt-fc-porto', 18, 'Porto', 'https://upload.wikimedia.org/wikipedia/en/f/f1/FC_Porto.svg', ARRAY['FC Porto']),
  ('pt-sl-benfica', 19, 'Benfica', 'https://upload.wikimedia.org/wikipedia/en/a/a2/SL_Benfica_logo.svg', ARRAY['SL Benfica']),
  ('pt-sporting-cp', 20, 'Sporting CP', 'https://upload.wikimedia.org/wikipedia/commons/3/33/Sporting_Clube_de_Portugal.svg', ARRAY['Sporting']);

UPDATE public.teams
SET
  is_popular_pick = false,
  popular_pick_rank = null,
  updated_at = now()
WHERE is_active = true;

UPDATE public.teams AS teams
SET
  is_popular_pick = true,
  popular_pick_rank = seed.popular_pick_rank,
  updated_at = now()
FROM temp_onboarding_popular_team_seed AS seed
WHERE teams.id = seed.team_id;

UPDATE public.onboarding_popular_teams
SET
  is_active = false,
  updated_at = now()
WHERE is_active = true;

INSERT INTO public.onboarding_popular_teams (
  id,
  name,
  short_name,
  country,
  country_code,
  league_name,
  region,
  logo_url,
  crest_url,
  aliases,
  search_terms,
  is_popular_pick,
  popular_pick_rank,
  is_featured,
  is_active,
  updated_at
)
SELECT
  teams.id,
  seed.display_name,
  teams.short_name,
  teams.country,
  teams.country_code,
  teams.league_name,
  'europe' AS region,
  COALESCE(NULLIF(teams.logo_url, ''), NULLIF(teams.crest_url, ''), seed.crest_url) AS logo_url,
  COALESCE(NULLIF(teams.crest_url, ''), NULLIF(teams.logo_url, ''), seed.crest_url) AS crest_url,
  ARRAY(
    SELECT DISTINCT trimmed_alias
    FROM (
      SELECT NULLIF(btrim(alias), '') AS trimmed_alias
      FROM unnest(
        ARRAY[
          seed.display_name,
          teams.name,
          teams.short_name
        ]::text[]
        || COALESCE(seed.aliases, '{}'::text[])
        || COALESCE(teams.aliases, '{}'::text[])
        || COALESCE(teams.search_terms, '{}'::text[])
      ) AS alias
    ) AS normalized_aliases
    WHERE trimmed_alias IS NOT NULL
  ) AS aliases,
  ARRAY(
    SELECT DISTINCT trimmed_alias
    FROM (
      SELECT NULLIF(btrim(alias), '') AS trimmed_alias
      FROM unnest(
        ARRAY[
          seed.display_name,
          teams.name,
          teams.short_name
        ]::text[]
        || COALESCE(seed.aliases, '{}'::text[])
        || COALESCE(teams.aliases, '{}'::text[])
        || COALESCE(teams.search_terms, '{}'::text[])
      ) AS alias
    ) AS normalized_aliases
    WHERE trimmed_alias IS NOT NULL
  ) AS search_terms,
  true AS is_popular_pick,
  seed.popular_pick_rank,
  false AS is_featured,
  true AS is_active,
  now() AS updated_at
FROM temp_onboarding_popular_team_seed AS seed
JOIN public.teams AS teams
  ON teams.id = seed.team_id
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  country = EXCLUDED.country,
  country_code = EXCLUDED.country_code,
  league_name = EXCLUDED.league_name,
  region = EXCLUDED.region,
  logo_url = EXCLUDED.logo_url,
  crest_url = EXCLUDED.crest_url,
  aliases = EXCLUDED.aliases,
  search_terms = EXCLUDED.search_terms,
  is_popular_pick = EXCLUDED.is_popular_pick,
  popular_pick_rank = EXCLUDED.popular_pick_rank,
  is_featured = EXCLUDED.is_featured,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

COMMIT;
