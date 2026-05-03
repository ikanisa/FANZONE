-- Adds product-aligned fan profile categories without replacing the existing
-- favorite-team table or profile summary flow.

ALTER TABLE public.user_favorite_teams
  DROP CONSTRAINT IF EXISTS user_favorite_teams_source_check;

ALTER TABLE public.user_favorite_teams
  ADD CONSTRAINT user_favorite_teams_source_check
  CHECK (
    source = ANY (
      ARRAY[
        'local'::text,
        'top_european'::text,
        'national'::text,
        'popular'::text,
        'settings'::text,
        'synced'::text
      ]
    )
  );

CREATE OR REPLACE FUNCTION public.enforce_user_favorite_team_limits()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  category_limit integer;
  existing_count integer;
BEGIN
  IF NEW.source = 'local' THEN
    category_limit := 1;
  ELSIF NEW.source IN ('top_european', 'national') THEN
    category_limit := 2;
  ELSE
    RETURN NEW;
  END IF;

  SELECT count(*)
    INTO existing_count
    FROM public.user_favorite_teams existing
   WHERE existing.user_id = NEW.user_id
     AND existing.source = NEW.source
     AND existing.id IS DISTINCT FROM NEW.id;

  IF existing_count >= category_limit THEN
    RAISE EXCEPTION
      'fan profile category % allows at most % team(s)',
      NEW.source,
      category_limit
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_user_favorite_team_limits
  ON public.user_favorite_teams;

CREATE TRIGGER trg_enforce_user_favorite_team_limits
  BEFORE INSERT OR UPDATE OF source, user_id ON public.user_favorite_teams
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_user_favorite_team_limits();
