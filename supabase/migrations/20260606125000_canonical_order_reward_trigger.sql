-- Route paid-order reward triggers through the canonical wallet helper.
-- Older remote deployments had an inline trigger body with a fixed conversion
-- rate; this keeps payment confirmation, ledger idempotency, and order
-- reconciliation on one audited server-side path.

CREATE OR REPLACE FUNCTION public.venue_credit_fet_from_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.credit_fet_for_order(NEW.id);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND (
       NEW.payment_status IS DISTINCT FROM OLD.payment_status
       OR NEW.status IS DISTINCT FROM OLD.status
     ) THEN
    PERFORM public.credit_fet_for_order(NEW.id);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'FET order reward skipped for order %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.venue_credit_fet_from_order() IS
  'Orders trigger wrapper that delegates paid-order reward crediting to credit_fet_for_order for canonical wallet ledger and orders.fet_earned reconciliation.';
