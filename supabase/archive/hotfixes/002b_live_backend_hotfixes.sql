-- Live backend hotfixes applied on 2026-04-17.
-- This repo is not the source of truth for infrastructure, but this file
-- records the SQL that was applied to production so the infra repo can adopt it.

BEGIN;

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  phone_value text;
BEGIN
  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = COALESCE(EXCLUDED.phone_number, profiles.phone_number);

  INSERT INTO public.app_preferences (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_user_id, 5000, 0)
  ON CONFLICT (user_id) DO NOTHING;
END;
$function$;

DROP TRIGGER IF EXISTS on_auth_user_created_wallet ON auth.users;
DROP FUNCTION IF EXISTS public.create_user_wallet();

DROP POLICY IF EXISTS "Users can create own challenges" ON public.prediction_challenges;
CREATE POLICY "Users can create own challenges"
ON public.prediction_challenges
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = creator_user_id);

DROP POLICY IF EXISTS "Users can add own challenge entries" ON public.prediction_challenge_entries;
CREATE POLICY "Users can add own challenge entries"
ON public.prediction_challenge_entries
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated can view entries" ON public.prediction_challenge_entries;
DROP POLICY IF EXISTS "Authenticated can view own entries only" ON public.prediction_challenge_entries;
CREATE POLICY "Authenticated can view own entries only"
ON public.prediction_challenge_entries
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.sync_prediction_challenge_totals()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_challenge_id uuid := COALESCE(NEW.challenge_id, OLD.challenge_id);
BEGIN
  UPDATE public.prediction_challenges AS c
  SET total_participants = COALESCE(s.participants, 0),
      total_pool_fet = COALESCE(s.total_pool_fet, 0),
      updated_at = now()
  FROM (
    SELECT challenge_id,
           COUNT(*)::integer AS participants,
           COALESCE(SUM(stake_fet), 0)::bigint AS total_pool_fet
    FROM public.prediction_challenge_entries
    WHERE challenge_id = v_challenge_id
      AND status <> 'cancelled'
    GROUP BY challenge_id
  ) AS s
  WHERE c.id = v_challenge_id
    AND c.id = s.challenge_id;

  UPDATE public.prediction_challenges
  SET total_participants = 0,
      total_pool_fet = 0,
      updated_at = now()
  WHERE id = v_challenge_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.prediction_challenge_entries
      WHERE challenge_id = v_challenge_id
        AND status <> 'cancelled'
    );

  RETURN COALESCE(NEW, OLD);
END;
$function$;

DROP TRIGGER IF EXISTS sync_prediction_challenge_totals ON public.prediction_challenge_entries;
CREATE TRIGGER sync_prediction_challenge_totals
AFTER INSERT OR UPDATE OR DELETE ON public.prediction_challenge_entries
FOR EACH ROW EXECUTE FUNCTION public.sync_prediction_challenge_totals();

COMMIT;
