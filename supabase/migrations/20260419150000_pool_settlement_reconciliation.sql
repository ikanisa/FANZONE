-- ============================================================
-- 20260419150000_pool_settlement_reconciliation.sql
-- Admin-safe reconciliation surfaces for prediction pool settlement.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_pool_settlement_reconciliation(
  p_pool_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 200
)
RETURNS TABLE (
  pool_id uuid,
  match_id text,
  match_name text,
  pool_status text,
  settlement_at timestamptz,
  total_pool_fet bigint,
  total_participants integer,
  entry_count integer,
  winner_count integer,
  loser_count integer,
  won_entry_count integer,
  refunded_entry_count integer,
  cancelled_entry_count integer,
  payout_per_winner_fet bigint,
  remainder_distributed_fet bigint,
  entry_payout_total_fet bigint,
  wallet_credit_total_fet bigint,
  wallet_credit_tx_count integer,
  participant_count_reconciled boolean,
  entry_payout_reconciled boolean,
  wallet_credit_reconciled boolean,
  settlement_reconciled boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
  WITH pool_entries AS (
    SELECT
      pce.challenge_id,
      count(*)::integer AS entry_count,
      count(*) FILTER (WHERE pce.status = 'won')::integer AS won_entry_count,
      count(*) FILTER (WHERE pce.status = 'refunded')::integer AS refunded_entry_count,
      count(*) FILTER (WHERE pce.status = 'cancelled')::integer AS cancelled_entry_count,
      coalesce(sum(pce.payout_fet), 0)::bigint AS entry_payout_total_fet
    FROM public.prediction_challenge_entries pce
    GROUP BY pce.challenge_id
  ),
  wallet_credits AS (
    SELECT
      fwt.reference_id,
      count(*) FILTER (
        WHERE fwt.direction = 'credit'
          AND fwt.tx_type IN ('pool_payout', 'pool_refund')
      )::integer AS wallet_credit_tx_count,
      coalesce(
        sum(fwt.amount_fet) FILTER (
          WHERE fwt.direction = 'credit'
            AND fwt.tx_type IN ('pool_payout', 'pool_refund')
        ),
        0
      )::bigint AS wallet_credit_total_fet
    FROM public.fet_wallet_transactions fwt
    WHERE fwt.reference_type = 'prediction_challenge'
    GROUP BY fwt.reference_id
  )
  SELECT
    pc.id AS pool_id,
    pc.match_id,
    pc.match_name,
    pc.status AS pool_status,
    coalesce(pc.settled_at, pc.cancelled_at) AS settlement_at,
    coalesce(pc.total_pool_fet, 0)::bigint AS total_pool_fet,
    coalesce(pc.total_participants, 0)::integer AS total_participants,
    coalesce(pe.entry_count, 0)::integer AS entry_count,
    coalesce(pc.winner_count, 0)::integer AS winner_count,
    coalesce(pc.loser_count, 0)::integer AS loser_count,
    coalesce(pe.won_entry_count, 0)::integer AS won_entry_count,
    coalesce(pe.refunded_entry_count, 0)::integer AS refunded_entry_count,
    coalesce(pe.cancelled_entry_count, 0)::integer AS cancelled_entry_count,
    coalesce(pc.payout_per_winner_fet, 0)::bigint AS payout_per_winner_fet,
    CASE
      WHEN pc.status = 'settled' AND coalesce(pe.won_entry_count, 0) > 0 THEN
        greatest(
          coalesce(pe.entry_payout_total_fet, 0)
            - (coalesce(pc.payout_per_winner_fet, 0) * coalesce(pe.won_entry_count, 0)),
          0
        )::bigint
      ELSE 0::bigint
    END AS remainder_distributed_fet,
    coalesce(pe.entry_payout_total_fet, 0)::bigint AS entry_payout_total_fet,
    coalesce(wc.wallet_credit_total_fet, 0)::bigint AS wallet_credit_total_fet,
    coalesce(wc.wallet_credit_tx_count, 0)::integer AS wallet_credit_tx_count,
    (coalesce(pc.total_participants, 0) = coalesce(pe.entry_count, 0)) AS participant_count_reconciled,
    (coalesce(pe.entry_payout_total_fet, 0) = coalesce(pc.total_pool_fet, 0)) AS entry_payout_reconciled,
    (coalesce(wc.wallet_credit_total_fet, 0) = coalesce(pc.total_pool_fet, 0)) AS wallet_credit_reconciled,
    (
      coalesce(pc.total_participants, 0) = coalesce(pe.entry_count, 0)
      AND coalesce(pe.entry_payout_total_fet, 0) = coalesce(pc.total_pool_fet, 0)
      AND coalesce(wc.wallet_credit_total_fet, 0) = coalesce(pc.total_pool_fet, 0)
    ) AS settlement_reconciled
  FROM public.prediction_challenges pc
  LEFT JOIN pool_entries pe
    ON pe.challenge_id = pc.id
  LEFT JOIN wallet_credits wc
    ON wc.reference_id = pc.id::text
  WHERE (p_pool_id IS NULL OR pc.id = p_pool_id)
    AND pc.status IN ('settled', 'cancelled')
  ORDER BY coalesce(pc.settled_at, pc.cancelled_at, pc.updated_at, pc.created_at) DESC, pc.id DESC
  LIMIT greatest(coalesce(p_limit, 200), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pool_settlement_integrity_summary(
  p_since timestamptz DEFAULT (now() - interval '30 days')
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_summary jsonb;
BEGIN
  PERFORM public.require_active_admin_user();

  WITH pool_entries AS (
    SELECT
      pce.challenge_id,
      count(*)::integer AS entry_count,
      count(*) FILTER (WHERE pce.status = 'won')::integer AS won_entry_count,
      coalesce(sum(pce.payout_fet), 0)::bigint AS entry_payout_total_fet
    FROM public.prediction_challenge_entries pce
    GROUP BY pce.challenge_id
  ),
  wallet_credits AS (
    SELECT
      fwt.reference_id,
      coalesce(
        sum(fwt.amount_fet) FILTER (
          WHERE fwt.direction = 'credit'
            AND fwt.tx_type IN ('pool_payout', 'pool_refund')
        ),
        0
      )::bigint AS wallet_credit_total_fet
    FROM public.fet_wallet_transactions fwt
    WHERE fwt.reference_type = 'prediction_challenge'
    GROUP BY fwt.reference_id
  ),
  reconciliation AS (
    SELECT
      pc.id AS pool_id,
      coalesce(pc.settled_at, pc.cancelled_at, pc.updated_at, pc.created_at) AS settlement_at,
      coalesce(pc.total_pool_fet, 0)::bigint AS total_pool_fet,
      coalesce(pe.entry_payout_total_fet, 0)::bigint AS entry_payout_total_fet,
      coalesce(wc.wallet_credit_total_fet, 0)::bigint AS wallet_credit_total_fet,
      (
        coalesce(pc.total_participants, 0) = coalesce(pe.entry_count, 0)
        AND coalesce(pe.entry_payout_total_fet, 0) = coalesce(pc.total_pool_fet, 0)
        AND coalesce(wc.wallet_credit_total_fet, 0) = coalesce(pc.total_pool_fet, 0)
      ) AS settlement_reconciled
    FROM public.prediction_challenges pc
    LEFT JOIN pool_entries pe
      ON pe.challenge_id = pc.id
    LEFT JOIN wallet_credits wc
      ON wc.reference_id = pc.id::text
    WHERE pc.status IN ('settled', 'cancelled')
      AND coalesce(pc.settled_at, pc.cancelled_at, pc.updated_at, pc.created_at)
        >= coalesce(p_since, '-infinity'::timestamptz)
  ),
  unreconciled AS (
    SELECT pool_id::text AS pool_id
    FROM reconciliation
    WHERE NOT settlement_reconciled
    ORDER BY settlement_at DESC NULLS LAST, pool_id DESC
    LIMIT 20
  )
  SELECT jsonb_build_object(
    'checked_pool_count', coalesce((SELECT count(*) FROM reconciliation), 0),
    'reconciled_pool_count', coalesce((SELECT count(*) FROM reconciliation WHERE settlement_reconciled), 0),
    'unreconciled_pool_count', coalesce((SELECT count(*) FROM reconciliation WHERE NOT settlement_reconciled), 0),
    'total_expected_credit_fet', coalesce((SELECT sum(total_pool_fet) FROM reconciliation), 0),
    'total_entry_payout_fet', coalesce((SELECT sum(entry_payout_total_fet) FROM reconciliation), 0),
    'total_wallet_credit_fet', coalesce((SELECT sum(wallet_credit_total_fet) FROM reconciliation), 0),
    'sample_unreconciled_pool_ids', coalesce((SELECT jsonb_agg(pool_id) FROM unreconciled), '[]'::jsonb),
    'since', p_since
  )
  INTO v_summary;

  RETURN v_summary;
END;
$$;

REVOKE ALL ON FUNCTION public.get_pool_settlement_reconciliation(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_pool_settlement_integrity_summary(timestamptz) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_pool_settlement_reconciliation(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pool_settlement_integrity_summary(timestamptz) TO authenticated;

COMMIT;
