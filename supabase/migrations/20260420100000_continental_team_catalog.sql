-- ============================================================
-- 20260420100000_continental_team_catalog.sql
-- Canonical top-flight catalog for Europe, Africa, and the full
-- Americas. Seeds the country/league coverage table used by the
-- grounded Gemini team-ingestion pipeline and keeps UK/GBP intact.
-- ============================================================

BEGIN;

ALTER TABLE public.country_region_map
  DROP CONSTRAINT IF EXISTS country_region_map_region_check;

ALTER TABLE public.country_region_map
  ADD CONSTRAINT country_region_map_region_check
  CHECK (region IN ('africa', 'europe', 'americas', 'north_america', 'global'));

ALTER TABLE public.launch_moments
  DROP CONSTRAINT IF EXISTS launch_moments_region_check;

ALTER TABLE public.launch_moments
  ADD CONSTRAINT launch_moments_region_check
  CHECK (region_key IN ('africa', 'europe', 'americas', 'north_america', 'global'));

CREATE TABLE IF NOT EXISTS public.country_league_catalog (
  country_code TEXT PRIMARY KEY,
  country_name TEXT NOT NULL,
  region TEXT NOT NULL,
  league_name_hint TEXT,
  expected_team_count INTEGER NOT NULL,
  flag_emoji TEXT NOT NULL DEFAULT '🌍',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT country_league_catalog_code_format CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT country_league_catalog_region_check
    CHECK (region IN ('africa', 'europe', 'americas')),
  CONSTRAINT country_league_catalog_expected_check CHECK (expected_team_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_country_league_catalog_region
  ON public.country_league_catalog (region, country_name);

ALTER TABLE public.country_league_catalog ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'country_league_catalog'
      AND policyname = 'Public read country league catalog'
  ) THEN
    CREATE POLICY "Public read country league catalog"
      ON public.country_league_catalog
      FOR SELECT
      USING (true);
  END IF;
END $$;

GRANT SELECT ON public.country_league_catalog TO anon, authenticated;

CREATE TEMP TABLE temp_country_league_catalog_seed
ON COMMIT DROP
AS
SELECT *
FROM jsonb_to_recordset(
  $json$[{"country_code":"GB","country_name":"England","region":"europe","league_name_hint":"Premier League","expected_team_count":20,"flag_emoji":"🇬🇧"},{"country_code":"XS","country_name":"Scotland","region":"europe","league_name_hint":"Scottish Premiership","expected_team_count":12,"flag_emoji":"🏴"},{"country_code":"XW","country_name":"Wales","region":"europe","league_name_hint":"Cymru Premier","expected_team_count":12,"flag_emoji":"🏴"},{"country_code":"XI","country_name":"Northern Ireland","region":"europe","league_name_hint":"NIFL Premiership","expected_team_count":12,"flag_emoji":"🇬🇧"},{"country_code":"ES","country_name":"Spain","region":"europe","league_name_hint":"La Liga","expected_team_count":20,"flag_emoji":"🇪🇸"},{"country_code":"DE","country_name":"Germany","region":"europe","league_name_hint":"Bundesliga","expected_team_count":18,"flag_emoji":"🇩🇪"},{"country_code":"FR","country_name":"France","region":"europe","league_name_hint":"Ligue 1","expected_team_count":18,"flag_emoji":"🇫🇷"},{"country_code":"IT","country_name":"Italy","region":"europe","league_name_hint":"Serie A","expected_team_count":20,"flag_emoji":"🇮🇹"},{"country_code":"PT","country_name":"Portugal","region":"europe","league_name_hint":"Primeira Liga","expected_team_count":18,"flag_emoji":"🇵🇹"},{"country_code":"NL","country_name":"Netherlands","region":"europe","league_name_hint":"Eredivisie","expected_team_count":18,"flag_emoji":"🇳🇱"},{"country_code":"BE","country_name":"Belgium","region":"europe","league_name_hint":"Pro League","expected_team_count":16,"flag_emoji":"🇧🇪"},{"country_code":"TR","country_name":"Turkey","region":"europe","league_name_hint":"Süper Lig","expected_team_count":19,"flag_emoji":"🇹🇷"},{"country_code":"GR","country_name":"Greece","region":"europe","league_name_hint":"Super League","expected_team_count":14,"flag_emoji":"🇬🇷"},{"country_code":"AT","country_name":"Austria","region":"europe","league_name_hint":"Austrian Bundesliga","expected_team_count":12,"flag_emoji":"🇦🇹"},{"country_code":"CH","country_name":"Switzerland","region":"europe","league_name_hint":"Super League","expected_team_count":12,"flag_emoji":"🇨🇭"},{"country_code":"SE","country_name":"Sweden","region":"europe","league_name_hint":"Allsvenskan","expected_team_count":16,"flag_emoji":"🇸🇪"},{"country_code":"NO","country_name":"Norway","region":"europe","league_name_hint":"Eliteserien","expected_team_count":16,"flag_emoji":"🇳🇴"},{"country_code":"DK","country_name":"Denmark","region":"europe","league_name_hint":"Superliga","expected_team_count":12,"flag_emoji":"🇩🇰"},{"country_code":"FI","country_name":"Finland","region":"europe","league_name_hint":"Veikkausliiga","expected_team_count":12,"flag_emoji":"🇫🇮"},{"country_code":"IE","country_name":"Ireland","region":"europe","league_name_hint":"League of Ireland Premier Division","expected_team_count":10,"flag_emoji":"🇮🇪"},{"country_code":"IS","country_name":"Iceland","region":"europe","league_name_hint":"Úrvalsdeild","expected_team_count":12,"flag_emoji":"🇮🇸"},{"country_code":"PL","country_name":"Poland","region":"europe","league_name_hint":"Ekstraklasa","expected_team_count":18,"flag_emoji":"🇵🇱"},{"country_code":"CZ","country_name":"Czech Republic","region":"europe","league_name_hint":"Czech First League","expected_team_count":16,"flag_emoji":"🇨🇿"},{"country_code":"HU","country_name":"Hungary","region":"europe","league_name_hint":"NB I","expected_team_count":12,"flag_emoji":"🇭🇺"},{"country_code":"RO","country_name":"Romania","region":"europe","league_name_hint":"SuperLiga","expected_team_count":16,"flag_emoji":"🇷🇴"},{"country_code":"BG","country_name":"Bulgaria","region":"europe","league_name_hint":"First Professional Football League","expected_team_count":16,"flag_emoji":"🇧🇬"},{"country_code":"HR","country_name":"Croatia","region":"europe","league_name_hint":"HNL","expected_team_count":10,"flag_emoji":"🇭🇷"},{"country_code":"RS","country_name":"Serbia","region":"europe","league_name_hint":"SuperLiga","expected_team_count":16,"flag_emoji":"🇷🇸"},{"country_code":"SK","country_name":"Slovakia","region":"europe","league_name_hint":"Fortuna Liga","expected_team_count":12,"flag_emoji":"🇸🇰"},{"country_code":"SI","country_name":"Slovenia","region":"europe","league_name_hint":"PrvaLiga","expected_team_count":10,"flag_emoji":"🇸🇮"},{"country_code":"UA","country_name":"Ukraine","region":"europe","league_name_hint":"Ukrainian Premier League","expected_team_count":16,"flag_emoji":"🇺🇦"},{"country_code":"RU","country_name":"Russia","region":"europe","league_name_hint":"Russian Premier League","expected_team_count":16,"flag_emoji":"🇷🇺"},{"country_code":"CY","country_name":"Cyprus","region":"europe","league_name_hint":"Cypriot First Division","expected_team_count":14,"flag_emoji":"🇨🇾"},{"country_code":"MT","country_name":"Malta","region":"europe","league_name_hint":"Maltese Premier League","expected_team_count":16,"flag_emoji":"🇲🇹"},{"country_code":"LU","country_name":"Luxembourg","region":"europe","league_name_hint":"National Division","expected_team_count":14,"flag_emoji":"🇱🇺"},{"country_code":"EE","country_name":"Estonia","region":"europe","league_name_hint":"Meistriliiga","expected_team_count":10,"flag_emoji":"🇪🇪"},{"country_code":"LV","country_name":"Latvia","region":"europe","league_name_hint":"Virsliga","expected_team_count":10,"flag_emoji":"🇱🇻"},{"country_code":"LT","country_name":"Lithuania","region":"europe","league_name_hint":"A Lyga","expected_team_count":10,"flag_emoji":"🇱🇹"},{"country_code":"AL","country_name":"Albania","region":"europe","league_name_hint":"Kategoria Superiore","expected_team_count":10,"flag_emoji":"🇦🇱"},{"country_code":"BA","country_name":"Bosnia and Herzegovina","region":"europe","league_name_hint":"Premier League of Bosnia and Herzegovina","expected_team_count":12,"flag_emoji":"🇧🇦"},{"country_code":"MK","country_name":"North Macedonia","region":"europe","league_name_hint":"Prva Liga","expected_team_count":10,"flag_emoji":"🇲🇰"},{"country_code":"ME","country_name":"Montenegro","region":"europe","league_name_hint":"Montenegrin First League","expected_team_count":10,"flag_emoji":"🇲🇪"},{"country_code":"XK","country_name":"Kosovo","region":"europe","league_name_hint":"Football Superleague of Kosovo","expected_team_count":10,"flag_emoji":"🇽🇰"},{"country_code":"MD","country_name":"Moldova","region":"europe","league_name_hint":"Moldovan Super Liga","expected_team_count":8,"flag_emoji":"🇲🇩"},{"country_code":"GE","country_name":"Georgia","region":"europe","league_name_hint":"Erovnuli Liga","expected_team_count":10,"flag_emoji":"🇬🇪"},{"country_code":"AM","country_name":"Armenia","region":"europe","league_name_hint":"Armenian Premier League","expected_team_count":10,"flag_emoji":"🇦🇲"},{"country_code":"AZ","country_name":"Azerbaijan","region":"europe","league_name_hint":"Azerbaijan Premier League","expected_team_count":10,"flag_emoji":"🇦🇿"},{"country_code":"BY","country_name":"Belarus","region":"europe","league_name_hint":"Belarusian Premier League","expected_team_count":16,"flag_emoji":"🇧🇾"},{"country_code":"KZ","country_name":"Kazakhstan","region":"europe","league_name_hint":"Kazakhstan Premier League","expected_team_count":14,"flag_emoji":"🇰🇿"},{"country_code":"AD","country_name":"Andorra","region":"europe","league_name_hint":null,"expected_team_count":8,"flag_emoji":"🇦🇩"},{"country_code":"FO","country_name":"Faroe Islands","region":"europe","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇫🇴"},{"country_code":"GI","country_name":"Gibraltar","region":"europe","league_name_hint":null,"expected_team_count":11,"flag_emoji":"🇬🇮"},{"country_code":"SM","country_name":"San Marino","region":"europe","league_name_hint":null,"expected_team_count":15,"flag_emoji":"🇸🇲"},{"country_code":"NG","country_name":"Nigeria","region":"africa","league_name_hint":"Nigeria Professional Football League","expected_team_count":20,"flag_emoji":"🇳🇬"},{"country_code":"EG","country_name":"Egypt","region":"africa","league_name_hint":"Egyptian Premier League","expected_team_count":18,"flag_emoji":"🇪🇬"},{"country_code":"ZA","country_name":"South Africa","region":"africa","league_name_hint":"DStv Premiership","expected_team_count":16,"flag_emoji":"🇿🇦"},{"country_code":"MA","country_name":"Morocco","region":"africa","league_name_hint":"Botola Pro","expected_team_count":16,"flag_emoji":"🇲🇦"},{"country_code":"TN","country_name":"Tunisia","region":"africa","league_name_hint":"Ligue Professionnelle 1","expected_team_count":14,"flag_emoji":"🇹🇳"},{"country_code":"DZ","country_name":"Algeria","region":"africa","league_name_hint":"Ligue Professionnelle 1","expected_team_count":16,"flag_emoji":"🇩🇿"},{"country_code":"GH","country_name":"Ghana","region":"africa","league_name_hint":"Ghana Premier League","expected_team_count":18,"flag_emoji":"🇬🇭"},{"country_code":"KE","country_name":"Kenya","region":"africa","league_name_hint":"Kenyan Premier League","expected_team_count":18,"flag_emoji":"🇰🇪"},{"country_code":"RW","country_name":"Rwanda","region":"africa","league_name_hint":"Rwanda Premier League","expected_team_count":16,"flag_emoji":"🇷🇼"},{"country_code":"TZ","country_name":"Tanzania","region":"africa","league_name_hint":"NBC Premier League","expected_team_count":16,"flag_emoji":"🇹🇿"},{"country_code":"UG","country_name":"Uganda","region":"africa","league_name_hint":"Uganda Premier League","expected_team_count":16,"flag_emoji":"🇺🇬"},{"country_code":"CD","country_name":"DR Congo","region":"africa","league_name_hint":"Linafoot","expected_team_count":20,"flag_emoji":"🇨🇩"},{"country_code":"SN","country_name":"Senegal","region":"africa","league_name_hint":"Ligue 1 Sénégalaise","expected_team_count":14,"flag_emoji":"🇸🇳"},{"country_code":"CI","country_name":"Côte d'Ivoire","region":"africa","league_name_hint":"Ligue 1 Ivoirienne","expected_team_count":14,"flag_emoji":"🇨🇮"},{"country_code":"CM","country_name":"Cameroon","region":"africa","league_name_hint":"Elite One","expected_team_count":16,"flag_emoji":"🇨🇲"},{"country_code":"ML","country_name":"Mali","region":"africa","league_name_hint":"Première Division du Mali","expected_team_count":18,"flag_emoji":"🇲🇱"},{"country_code":"BF","country_name":"Burkina Faso","region":"africa","league_name_hint":"Première Division du Burkina Faso","expected_team_count":16,"flag_emoji":"🇧🇫"},{"country_code":"ET","country_name":"Ethiopia","region":"africa","league_name_hint":"Ethiopian Premier League","expected_team_count":16,"flag_emoji":"🇪🇹"},{"country_code":"ZM","country_name":"Zambia","region":"africa","league_name_hint":"Zambia Super League","expected_team_count":18,"flag_emoji":"🇿🇲"},{"country_code":"ZW","country_name":"Zimbabwe","region":"africa","league_name_hint":"Zimbabwe Premier Soccer League","expected_team_count":18,"flag_emoji":"🇿🇼"},{"country_code":"MZ","country_name":"Mozambique","region":"africa","league_name_hint":"Moçambola","expected_team_count":14,"flag_emoji":"🇲🇿"},{"country_code":"AO","country_name":"Angola","region":"africa","league_name_hint":"Girabola","expected_team_count":16,"flag_emoji":"🇦🇴"},{"country_code":"GN","country_name":"Guinea","region":"africa","league_name_hint":"Ligue 1 Guinéenne","expected_team_count":14,"flag_emoji":"🇬🇳"},{"country_code":"NE","country_name":"Niger","region":"africa","league_name_hint":"Ligue 1 du Niger","expected_team_count":14,"flag_emoji":"🇳🇪"},{"country_code":"TG","country_name":"Togo","region":"africa","league_name_hint":"Championnat National du Togo","expected_team_count":14,"flag_emoji":"🇹🇬"},{"country_code":"BJ","country_name":"Benin","region":"africa","league_name_hint":"Championnat National du Bénin","expected_team_count":12,"flag_emoji":"🇧🇯"},{"country_code":"GA","country_name":"Gabon","region":"africa","league_name_hint":"Championnat National D1 du Gabon","expected_team_count":14,"flag_emoji":"🇬🇦"},{"country_code":"CG","country_name":"Congo","region":"africa","league_name_hint":"Ligue 1 du Congo","expected_team_count":14,"flag_emoji":"🇨🇬"},{"country_code":"MG","country_name":"Madagascar","region":"africa","league_name_hint":"Pro League Malgache","expected_team_count":12,"flag_emoji":"🇲🇬"},{"country_code":"SD","country_name":"Sudan","region":"africa","league_name_hint":"Sudan Premier League","expected_team_count":18,"flag_emoji":"🇸🇩"},{"country_code":"LY","country_name":"Libya","region":"africa","league_name_hint":"Libyan Premier League","expected_team_count":18,"flag_emoji":"🇱🇾"},{"country_code":"NA","country_name":"Namibia","region":"africa","league_name_hint":"Namibia Premier League","expected_team_count":12,"flag_emoji":"🇳🇦"},{"country_code":"BW","country_name":"Botswana","region":"africa","league_name_hint":"BTC Premiership","expected_team_count":16,"flag_emoji":"🇧🇼"},{"country_code":"MW","country_name":"Malawi","region":"africa","league_name_hint":"Super League of Malawi","expected_team_count":16,"flag_emoji":"🇲🇼"},{"country_code":"SL","country_name":"Sierra Leone","region":"africa","league_name_hint":"Sierra Leone Premier League","expected_team_count":14,"flag_emoji":"🇸🇱"},{"country_code":"LR","country_name":"Liberia","region":"africa","league_name_hint":"LFA First Division","expected_team_count":14,"flag_emoji":"🇱🇷"},{"country_code":"GM","country_name":"Gambia","region":"africa","league_name_hint":"GFF League First Division","expected_team_count":12,"flag_emoji":"🇬🇲"},{"country_code":"BI","country_name":"Burundi","region":"africa","league_name_hint":"Burundi Premier League","expected_team_count":16,"flag_emoji":"🇧🇮"},{"country_code":"LS","country_name":"Lesotho","region":"africa","league_name_hint":"Lesotho Premier League","expected_team_count":12,"flag_emoji":"🇱🇸"},{"country_code":"SZ","country_name":"Eswatini","region":"africa","league_name_hint":"Eswatini Premier League","expected_team_count":12,"flag_emoji":"🇸🇿"},{"country_code":"GW","country_name":"Guinea-Bissau","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇬🇼"},{"country_code":"CV","country_name":"Cape Verde","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇨🇻"},{"country_code":"GQ","country_name":"Equatorial Guinea","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇬🇶"},{"country_code":"MU","country_name":"Mauritius","region":"africa","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇲🇺"},{"country_code":"SC","country_name":"Seychelles","region":"africa","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇸🇨"},{"country_code":"DJ","country_name":"Djibouti","region":"africa","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇩🇯"},{"country_code":"ER","country_name":"Eritrea","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇪🇷"},{"country_code":"SO","country_name":"Somalia","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇸🇴"},{"country_code":"MR","country_name":"Mauritania","region":"africa","league_name_hint":null,"expected_team_count":16,"flag_emoji":"🇲🇷"},{"country_code":"TD","country_name":"Chad","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇹🇩"},{"country_code":"CF","country_name":"Central African Republic","region":"africa","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇨🇫"},{"country_code":"SS","country_name":"South Sudan","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇸🇸"},{"country_code":"ST","country_name":"Sao Tome and Principe","region":"africa","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇸🇹"},{"country_code":"KM","country_name":"Comoros","region":"africa","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇰🇲"},{"country_code":"US","country_name":"United States","region":"americas","league_name_hint":"Major League Soccer","expected_team_count":29,"flag_emoji":"🇺🇸"},{"country_code":"MX","country_name":"Mexico","region":"americas","league_name_hint":"Liga MX","expected_team_count":18,"flag_emoji":"🇲🇽"},{"country_code":"CA","country_name":"Canada","region":"americas","league_name_hint":"Canadian Premier League","expected_team_count":8,"flag_emoji":"🇨🇦"},{"country_code":"BR","country_name":"Brazil","region":"americas","league_name_hint":"Brasileirão Série A","expected_team_count":20,"flag_emoji":"🇧🇷"},{"country_code":"AR","country_name":"Argentina","region":"americas","league_name_hint":"Liga Profesional de Fútbol","expected_team_count":28,"flag_emoji":"🇦🇷"},{"country_code":"CO","country_name":"Colombia","region":"americas","league_name_hint":"Categoría Primera A","expected_team_count":20,"flag_emoji":"🇨🇴"},{"country_code":"CL","country_name":"Chile","region":"americas","league_name_hint":"Primera División de Chile","expected_team_count":16,"flag_emoji":"🇨🇱"},{"country_code":"PE","country_name":"Peru","region":"americas","league_name_hint":"Liga 1","expected_team_count":19,"flag_emoji":"🇵🇪"},{"country_code":"EC","country_name":"Ecuador","region":"americas","league_name_hint":"Liga Pro","expected_team_count":16,"flag_emoji":"🇪🇨"},{"country_code":"UY","country_name":"Uruguay","region":"americas","league_name_hint":"Primera División de Uruguay","expected_team_count":16,"flag_emoji":"🇺🇾"},{"country_code":"PY","country_name":"Paraguay","region":"americas","league_name_hint":"División de Honor","expected_team_count":12,"flag_emoji":"🇵🇾"},{"country_code":"BO","country_name":"Bolivia","region":"americas","league_name_hint":"División Profesional","expected_team_count":16,"flag_emoji":"🇧🇴"},{"country_code":"VE","country_name":"Venezuela","region":"americas","league_name_hint":"Liga FUTVE","expected_team_count":18,"flag_emoji":"🇻🇪"},{"country_code":"CR","country_name":"Costa Rica","region":"americas","league_name_hint":"Liga FPD","expected_team_count":12,"flag_emoji":"🇨🇷"},{"country_code":"PA","country_name":"Panama","region":"americas","league_name_hint":"Liga Panameña de Fútbol","expected_team_count":10,"flag_emoji":"🇵🇦"},{"country_code":"HN","country_name":"Honduras","region":"americas","league_name_hint":"Liga Nacional de Honduras","expected_team_count":10,"flag_emoji":"🇭🇳"},{"country_code":"SV","country_name":"El Salvador","region":"americas","league_name_hint":"Primera División de Fútbol","expected_team_count":12,"flag_emoji":"🇸🇻"},{"country_code":"GT","country_name":"Guatemala","region":"americas","league_name_hint":"Liga Nacional de Guatemala","expected_team_count":12,"flag_emoji":"🇬🇹"},{"country_code":"JM","country_name":"Jamaica","region":"americas","league_name_hint":"Jamaica Premier League","expected_team_count":12,"flag_emoji":"🇯🇲"},{"country_code":"TT","country_name":"Trinidad and Tobago","region":"americas","league_name_hint":"TT Pro League","expected_team_count":10,"flag_emoji":"🇹🇹"},{"country_code":"DO","country_name":"Dominican Republic","region":"americas","league_name_hint":"Liga Dominicana de Fútbol","expected_team_count":10,"flag_emoji":"🇩🇴"},{"country_code":"HT","country_name":"Haiti","region":"americas","league_name_hint":"Ligue Haïtienne","expected_team_count":14,"flag_emoji":"🇭🇹"},{"country_code":"CU","country_name":"Cuba","region":"americas","league_name_hint":"Campeonato Nacional de Fútbol de Cuba","expected_team_count":16,"flag_emoji":"🇨🇺"},{"country_code":"NI","country_name":"Nicaragua","region":"americas","league_name_hint":"Liga Primera de Nicaragua","expected_team_count":10,"flag_emoji":"🇳🇮"},{"country_code":"BZ","country_name":"Belize","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇧🇿"},{"country_code":"SR","country_name":"Suriname","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇸🇷"},{"country_code":"GY","country_name":"Guyana","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇬🇾"},{"country_code":"BB","country_name":"Barbados","region":"americas","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇧🇧"},{"country_code":"AG","country_name":"Antigua and Barbuda","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇦🇬"},{"country_code":"DM","country_name":"Dominica","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇩🇲"},{"country_code":"GD","country_name":"Grenada","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇬🇩"},{"country_code":"KN","country_name":"Saint Kitts and Nevis","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇰🇳"},{"country_code":"LC","country_name":"Saint Lucia","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇱🇨"},{"country_code":"VC","country_name":"Saint Vincent and the Grenadines","region":"americas","league_name_hint":null,"expected_team_count":8,"flag_emoji":"🇻🇨"},{"country_code":"BS","country_name":"Bahamas","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇧🇸"},{"country_code":"AW","country_name":"Aruba","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇦🇼"},{"country_code":"CW","country_name":"Curaçao","region":"americas","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇨🇼"},{"country_code":"PR","country_name":"Puerto Rico","region":"americas","league_name_hint":null,"expected_team_count":12,"flag_emoji":"🇵🇷"},{"country_code":"BM","country_name":"Bermuda","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇧🇲"},{"country_code":"KY","country_name":"Cayman Islands","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇰🇾"},{"country_code":"VG","country_name":"British Virgin Islands","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇻🇬"},{"country_code":"VI","country_name":"US Virgin Islands","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇻🇮"},{"country_code":"TC","country_name":"Turks and Caicos Islands","region":"americas","league_name_hint":null,"expected_team_count":10,"flag_emoji":"🇹🇨"},{"country_code":"GP","country_name":"Guadeloupe","region":"americas","league_name_hint":null,"expected_team_count":14,"flag_emoji":"🇬🇵"},{"country_code":"MQ","country_name":"Martinique","region":"americas","league_name_hint":null,"expected_team_count":14,"flag_emoji":"🇲🇶"},{"country_code":"SX","country_name":"Sint Maarten","region":"americas","league_name_hint":null,"expected_team_count":8,"flag_emoji":"🇸🇽"}]$json$::jsonb
) AS seed(
  country_code TEXT,
  country_name TEXT,
  region TEXT,
  league_name_hint TEXT,
  expected_team_count INTEGER,
  flag_emoji TEXT
);

INSERT INTO public.country_league_catalog (
  country_code,
  country_name,
  region,
  league_name_hint,
  expected_team_count,
  flag_emoji
)
SELECT
  country_code,
  country_name,
  region,
  league_name_hint,
  expected_team_count,
  flag_emoji
FROM temp_country_league_catalog_seed
ON CONFLICT (country_code) DO UPDATE
SET country_name = EXCLUDED.country_name,
    region = EXCLUDED.region,
    league_name_hint = EXCLUDED.league_name_hint,
    expected_team_count = EXCLUDED.expected_team_count,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

INSERT INTO public.country_region_map (
  country_code,
  region,
  country_name,
  flag_emoji
)
SELECT
  country_code,
  region,
  CASE
    WHEN country_code = 'GB' THEN 'United Kingdom'
    ELSE country_name
  END,
  flag_emoji
FROM temp_country_league_catalog_seed
ON CONFLICT (country_code) DO UPDATE
SET region = EXCLUDED.region,
    country_name = EXCLUDED.country_name,
    flag_emoji = EXCLUDED.flag_emoji,
    updated_at = now();

INSERT INTO public.country_currency_map (
  country_code,
  currency_code,
  country_name
)
VALUES
  ('GB', 'GBP', 'United Kingdom'),
  ('XS', 'GBP', 'Scotland'),
  ('XW', 'GBP', 'Wales'),
  ('XI', 'GBP', 'Northern Ireland')
ON CONFLICT (country_code) DO UPDATE
SET currency_code = EXCLUDED.currency_code,
    country_name = EXCLUDED.country_name,
    updated_at = now();

INSERT INTO public.currency_display_metadata (
  currency_code,
  symbol,
  decimals,
  space_separated
)
VALUES ('GBP', '£', 2, false)
ON CONFLICT (currency_code) DO UPDATE
SET symbol = EXCLUDED.symbol,
    decimals = EXCLUDED.decimals,
    space_separated = EXCLUDED.space_separated,
    updated_at = now();

INSERT INTO public.phone_presets (
  country_code,
  dial_code,
  hint,
  min_digits
)
VALUES
  ('GB', '+44', '7XXX XXX XXX', 10),
  ('XS', '+44', '7XXX XXX XXX', 10),
  ('XW', '+44', '7XXX XXX XXX', 10),
  ('XI', '+44', '7XXX XXX XXX', 10)
ON CONFLICT (country_code) DO UPDATE
SET dial_code = EXCLUDED.dial_code,
    hint = EXCLUDED.hint,
    min_digits = EXCLUDED.min_digits,
    updated_at = now();

CREATE OR REPLACE VIEW public.team_ingestion_coverage AS
SELECT
  catalog.country_code,
  catalog.country_name,
  catalog.region,
  catalog.league_name_hint,
  catalog.expected_team_count,
  COALESCE(teams.active_team_count, 0) AS active_team_count,
  GREATEST(catalog.expected_team_count - COALESCE(teams.active_team_count, 0), 0)
    AS missing_team_count
FROM public.country_league_catalog AS catalog
LEFT JOIN (
  SELECT country_code, COUNT(*)::INTEGER AS active_team_count
  FROM public.teams
  WHERE is_active = true
  GROUP BY country_code
) AS teams
  ON teams.country_code = catalog.country_code
ORDER BY catalog.region, catalog.country_name;

GRANT SELECT ON public.team_ingestion_coverage TO anon, authenticated;

COMMIT;
