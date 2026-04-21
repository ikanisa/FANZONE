BEGIN;

-- Production auth signup drift fix:
-- 1. app_preferences was removed in a later consolidation migration, but
--    ensure_user_foundation still writes to it.
-- 2. user_notifications was dropped, but the auth.users insert trigger still
--    writes a welcome notification into that removed table.
--
-- Both issues cause auth.admin.createUser() to fail with a database error.

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  phone_value text;
  v_foundation_grant bigint := 50;
  v_current_supply bigint := 0;
  v_wallet_created boolean := false;
BEGIN
  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  IF to_regclass('public.app_preferences') IS NOT NULL THEN
    INSERT INTO public.app_preferences (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  PERFORM public.lock_fet_supply_cap();

  IF NOT EXISTS (
    SELECT 1
    FROM public.fet_wallets
    WHERE user_id = p_user_id
  ) THEN
    SELECT coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
    INTO v_current_supply
    FROM public.fet_wallets;

    IF v_current_supply + v_foundation_grant > public.fet_supply_cap() THEN
      RAISE EXCEPTION 'ensure_user_foundation would exceed FET supply cap (% + % > %)',
        v_current_supply,
        v_foundation_grant,
        public.fet_supply_cap();
    END IF;

    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (p_user_id, v_foundation_grant, 0)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING true INTO v_wallet_created;

    IF coalesce(v_wallet_created, false) THEN
      INSERT INTO public.fet_wallet_transactions (
        user_id,
        tx_type,
        direction,
        amount_fet,
        balance_before_fet,
        balance_after_fet,
        reference_type,
        reference_id,
        title
      )
      VALUES (
        p_user_id,
        'foundation_grant',
        'credit',
        v_foundation_grant,
        0,
        v_foundation_grant,
        'foundation_grant',
        p_user_id,
        'Foundation grant - welcome bonus'
      );
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.ensure_user_foundation(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

DROP FUNCTION IF EXISTS public.handle_new_user();

COMMIT;
