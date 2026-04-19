\echo 'Checking FET supply cap helpers and view'

SELECT public.fet_supply_cap() AS configured_supply_cap;

SELECT
  total_supply,
  supply_cap,
  remaining_mintable
FROM public.fet_supply_overview;

DO $$
DECLARE
  v_total_supply bigint;
  v_supply_cap bigint;
BEGIN
  SELECT total_supply, supply_cap
  INTO v_total_supply, v_supply_cap
  FROM public.fet_supply_overview;

  IF v_total_supply > v_supply_cap THEN
    RAISE EXCEPTION 'Current total supply already exceeds configured cap (% > %)',
      v_total_supply,
      v_supply_cap;
  END IF;

  BEGIN
    PERFORM public.assert_fet_mint_within_cap(
      (v_supply_cap - v_total_supply) + 1,
      'fet_supply_cap_smoke'
    );
    RAISE EXCEPTION 'Expected over-cap mint to fail';
  EXCEPTION
    WHEN others THEN
      IF position('supply cap' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;
END;
$$;

\echo 'FET supply cap smoke checks passed'
