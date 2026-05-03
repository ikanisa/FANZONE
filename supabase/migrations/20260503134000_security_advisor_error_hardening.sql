-- Address linked Supabase security-advisor ERROR findings without exposing
-- auth.users through public views.

CREATE OR REPLACE VIEW public.user_profiles_admin
WITH (security_invoker = true)
AS
SELECT
  p.user_id AS id,
  NULL::varchar(255) AS email,
  NULLIF(p.phone_number, '') AS phone,
  jsonb_strip_nulls(jsonb_build_object(
    'display_name', COALESCE(NULLIF(trim(p.display_name), ''), NULLIF(trim(p.favorite_team_name), ''), p.fan_id, p.user_id::text),
    'fan_id', p.fan_id,
    'favorite_team_name', p.favorite_team_name,
    'is_banned', COALESCE(us.is_banned, false),
    'is_suspended', COALESCE(us.is_suspended, false),
    'wallet_frozen', COALESCE(us.wallet_frozen, false),
    'ban_reason', us.ban_reason,
    'suspend_reason', us.suspend_reason,
    'wallet_freeze_reason', us.wallet_freeze_reason
  )) AS raw_user_meta_data,
  p.created_at,
  NULL::timestamptz AS last_sign_in_at,
  COALESCE(fw.available_balance_fet, 0::bigint) AS available_balance_fet,
  COALESCE(fw.locked_balance_fet, 0::bigint) AS locked_balance_fet,
  COALESCE(NULLIF(trim(p.display_name), ''), NULLIF(trim(p.favorite_team_name), ''), p.fan_id, p.user_id::text) AS display_name,
  CASE
    WHEN COALESCE(us.wallet_frozen, false) THEN 'frozen'
    WHEN COALESCE(us.is_banned, false)
      AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now())) THEN 'banned'
    WHEN COALESCE(us.is_suspended, false)
      AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now())) THEN 'suspended'
    ELSE 'active'
  END AS status,
  us.ban_reason,
  us.suspend_reason,
  us.wallet_freeze_reason
FROM public.profiles p
LEFT JOIN public.fet_wallets fw ON fw.user_id = p.user_id
LEFT JOIN public.user_status us ON us.user_id = p.user_id
WHERE public.is_active_admin_operator(auth.uid());

CREATE OR REPLACE VIEW public.wallet_overview_admin
WITH (security_invoker = true)
AS
SELECT
  fw.user_id,
  COALESCE(NULLIF(trim(p.display_name), ''), NULLIF(trim(p.favorite_team_name), ''), p.fan_id, fw.user_id::text) AS display_name,
  NULL::varchar(255) AS email,
  NULLIF(p.phone_number, '') AS phone,
  CASE
    WHEN COALESCE(us.wallet_frozen, false) THEN 'frozen'
    WHEN COALESCE(us.is_banned, false)
      AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now())) THEN 'banned'
    WHEN COALESCE(us.is_suspended, false)
      AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now())) THEN 'suspended'
    ELSE 'active'
  END AS status,
  us.wallet_freeze_reason,
  fw.available_balance_fet,
  fw.locked_balance_fet,
  fw.updated_at,
  fw.created_at,
  COALESCE(fw.staked_balance_fet, 0::bigint) AS staked_balance_fet,
  COALESCE(fw.pending_balance_fet, 0::bigint) AS pending_balance_fet,
  COALESCE(b.spent_fet, 0::bigint) AS spent_fet,
  COALESCE(b.earned_fet, 0::bigint) AS earned_fet
FROM public.fet_wallets fw
LEFT JOIN public.profiles p ON p.user_id = fw.user_id
LEFT JOIN public.user_status us ON us.user_id = fw.user_id
LEFT JOIN LATERAL public.wallet_balance_from_ledger(fw.user_id) b(
  available_fet,
  staked_fet,
  pending_fet,
  spent_fet,
  earned_fet
) ON true
WHERE public.is_active_admin_operator(auth.uid());

CREATE OR REPLACE VIEW public.fet_transactions_admin
WITH (security_invoker = true)
AS
SELECT
  tx.id,
  tx.user_id,
  tx.tx_type,
  tx.direction,
  tx.amount_fet,
  tx.balance_before_fet,
  tx.balance_after_fet,
  tx.reference_type,
  tx.reference_id,
  tx.metadata,
  tx.created_at,
  tx.title,
  COALESCE(NULLIF(trim(p.display_name), ''), NULLIF(trim(p.favorite_team_name), ''), p.fan_id, tx.user_id::text) AS display_name,
  COALESCE((tx.metadata ->> 'flagged')::boolean, false) AS flagged,
  COALESCE(tx.transaction_type, tx.tx_type) AS transaction_type,
  tx.balance_bucket,
  tx.status,
  tx.idempotency_key,
  tx.source,
  tx.match_id,
  tx.pool_id,
  tx.order_id,
  tx.entry_id,
  tx.settlement_id,
  tx.venue_id,
  tx.created_by
FROM public.fet_wallet_transactions tx
LEFT JOIN public.profiles p ON p.user_id = tx.user_id
WHERE public.is_active_admin_operator(auth.uid());

ALTER VIEW public.admin_feature_flags SET (security_invoker = true);
ALTER VIEW public.app_competitions_ranked SET (security_invoker = true);
ALTER VIEW public.competition_standings SET (security_invoker = true);
ALTER VIEW public.admin_platform_features SET (security_invoker = true);
ALTER VIEW public.admin_platform_content_blocks SET (security_invoker = true);
ALTER VIEW public.app_competitions SET (security_invoker = true);
ALTER VIEW public.curated_active_matches SET (security_invoker = true);
ALTER VIEW public.platform_feature_audit_logs SET (security_invoker = true);
ALTER VIEW public.match_pool_stats SET (security_invoker = true);
ALTER VIEW public.app_matches SET (security_invoker = true);
ALTER VIEW public.fet_supply_overview SET (security_invoker = true);
ALTER VIEW public.wallet_overview SET (security_invoker = true);
ALTER VIEW public.admin_audit_logs_enriched SET (security_invoker = true);
ALTER VIEW public.fet_supply_overview_admin SET (security_invoker = true);

REVOKE ALL ON TABLE
  public.user_profiles_admin,
  public.wallet_overview_admin,
  public.fet_transactions_admin,
  public.admin_platform_features,
  public.admin_platform_content_blocks,
  public.admin_audit_logs_enriched,
  public.fet_supply_overview_admin
FROM anon;

GRANT SELECT ON TABLE
  public.user_profiles_admin,
  public.wallet_overview_admin,
  public.fet_transactions_admin,
  public.admin_platform_features,
  public.admin_platform_content_blocks,
  public.admin_audit_logs_enriched,
  public.fet_supply_overview_admin
TO authenticated, service_role;

ALTER TABLE public.fixture_sources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fixture_sources_select_public ON public.fixture_sources;
CREATE POLICY fixture_sources_select_public
ON public.fixture_sources
FOR SELECT
TO anon, authenticated
USING (true);

REVOKE INSERT, UPDATE, DELETE ON TABLE public.fixture_sources
FROM anon, authenticated;
