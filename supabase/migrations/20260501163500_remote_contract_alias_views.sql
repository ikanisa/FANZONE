-- Restore canonical compatibility views required by the simplified
-- sports-bar contract on remote projects that predate the baseline squash.
-- This migration is additive: it does not drop or rewrite underlying data.

CREATE OR REPLACE VIEW public.venue_tables
WITH (security_invoker='true') AS
SELECT
  t.id,
  t.venue_id,
  t.table_number,
  t.is_active,
  t.created_at,
  t.updated_at
FROM public.tables t;

COMMENT ON VIEW public.venue_tables IS
  'Canonical table surface over public.tables.';

CREATE OR REPLACE VIEW public.pool_camps
WITH (security_invoker='true') AS
SELECT
  c.id,
  c.pool_id,
  COALESCE(c.camp_key, c.code) AS camp_key,
  c.label,
  c.team_id,
  c.member_count AS total_members,
  c.total_staked_fet AS total_staked,
  c.is_winning_camp,
  c.created_at,
  c.updated_at
FROM public.match_pool_camps c;

COMMENT ON VIEW public.pool_camps IS
  'Canonical pool camp API over public.match_pool_camps.';

CREATE OR REPLACE VIEW public.pool_entries
WITH (security_invoker='true') AS
SELECT
  e.id,
  e.pool_id,
  e.camp_id,
  e.user_id,
  e.amount_fet AS stake_amount,
  e.status::text AS status,
  COALESCE(NULLIF(e.metadata ->> 'source', ''), 'direct') AS source,
  CASE
    WHEN (e.metadata ->> 'invited_by_user_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN (e.metadata ->> 'invited_by_user_id')::uuid
    ELSE NULL::uuid
  END AS invited_by_user_id,
  e.created_at,
  e.updated_at
FROM public.match_pool_entries e;

COMMENT ON VIEW public.pool_entries IS
  'Canonical pool entry API over public.match_pool_entries. Wallet mutation must use backend functions.';

CREATE OR REPLACE VIEW public.fet_ledger
WITH (security_invoker='true') AS
SELECT
  tx.id,
  tx.wallet_id,
  tx.user_id,
  CASE COALESCE(tx.transaction_type, tx.tx_type)
    WHEN 'wallet_welcome_bonus' THEN 'welcome_credit'
    WHEN 'welcome_bonus' THEN 'welcome_credit'
    WHEN 'order_reward' THEN 'order_earn'
    WHEN 'order_earn' THEN 'order_earn'
    WHEN 'order_spend' THEN 'order_spend'
    WHEN 'match_pool_entry' THEN 'pool_stake'
    WHEN 'pool_stake' THEN 'pool_stake'
    WHEN 'match_pool_settlement' THEN 'pool_win'
    WHEN 'pool_win' THEN 'pool_win'
    WHEN 'match_pool_refund' THEN 'pool_refund'
    WHEN 'pool_refund' THEN 'pool_refund'
    WHEN 'creator_reward' THEN 'creator_reward'
    WHEN 'settlement_fee' THEN 'settlement_fee'
    WHEN 'admin_credit' THEN 'admin_adjustment'
    WHEN 'admin_debit' THEN 'admin_adjustment'
    ELSE COALESCE(tx.transaction_type, tx.tx_type)
  END AS transaction_type,
  tx.amount_fet AS amount,
  tx.direction,
  tx.status,
  tx.order_id,
  tx.pool_id,
  tx.pool_entry_id,
  tx.match_id,
  tx.venue_id,
  tx.metadata AS metadata_json,
  tx.created_at
FROM public.fet_wallet_transactions tx;

COMMENT ON VIEW public.fet_ledger IS
  'Canonical FET wallet ledger over public.fet_wallet_transactions.';

CREATE OR REPLACE VIEW public.settlement_runs
WITH (security_invoker='true') AS
SELECT
  s.id,
  s.match_id,
  s.pool_id,
  s.status::text AS status,
  s.idempotency_key,
  s.started_at,
  s.completed_at,
  s.error_message,
  s.metadata AS metadata_json
FROM public.match_pool_settlements s;

COMMENT ON VIEW public.settlement_runs IS
  'Canonical settlement-run API over public.match_pool_settlements with idempotency keys.';

GRANT SELECT ON public.venue_tables TO anon, authenticated, service_role;
GRANT SELECT ON public.pool_camps TO anon, authenticated, service_role;
GRANT SELECT ON public.pool_entries TO authenticated, service_role;
GRANT SELECT ON public.fet_ledger TO authenticated, service_role;
GRANT SELECT ON public.settlement_runs TO authenticated, service_role;
