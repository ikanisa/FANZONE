# Backend

Backend source lives under `supabase/`.

## Supabase Responsibilities

- Auth and anonymous guest sessions.
- Venue, menu, table, order, payment status, and FET reward state.
- Match catalog, curation, pools, camps, entries, invites, and settlements.
- Wallet ledger and balance derivation.
- RLS isolation and audited mutation paths.
- Edge Functions for imports, orders, notifications, OTP, social cards, and settlement.

## Migration Policy

- Migrations are append-only for deployed environments.
- The clean sports-bar baseline is retained as the current schema baseline.
- Marker migrations are intentional no-op history alignment records after the baseline squash.
- Destructive changes require a backup, explicit rollback plan, and a release note.
- Every new RPC must include role checks, input validation, and audit logging when it mutates sensitive state.

## Migration Inventory

| Migration | Purpose |
| --- | --- |
| `20260423050000_sports_bar_clean_baseline.sql` | Clean baseline schema for sports-bar platform tables, RLS, RPCs, functions, triggers, storage, views, and grants. |
| `20260423083000_security_hardening_marker.sql` | No-op history marker for squashed security hardening. |
| `20260423110000_feature_registry_marker.sql` | No-op history marker for feature registry work. |
| `20260423120000_runtime_scheduler_marker.sql` | No-op history marker for runtime scheduler work. |
| `20260423123000_scheduler_surface_marker.sql` | No-op history marker for scheduler surface work. |
| `20260423130000_permission_hardening_marker.sql` | No-op history marker for permission hardening. |
| `20260423131000_notification_rpc_marker.sql` | No-op history marker for notification RPC fixes. |
| `20260423143000_feature_management_marker.sql` | No-op history marker for feature management controls. |
| `20260423143755_auth_phone_lookup_marker.sql` | No-op history marker for auth phone lookup fixes. |
| `20260423150000_feature_flag_source_marker.sql` | No-op history marker for feature flag source-of-truth cleanup. |
| `20260423163000_release_readiness_marker.sql` | No-op history marker for release readiness hardening. |
| `20260501000000_venue_order_schema_marker.sql` | No-op history marker for venue order schema merge. |
| `20260501010000_venue_order_rls_marker.sql` | No-op history marker for venue order RLS. |
| `20260501020000_venue_order_wallet_bridge_marker.sql` | No-op history marker for order wallet bridge. |
| `20260501030000_venue_pool_archive_marker.sql` | No-op history marker for venue pool archive work. |
| `20260501040000_order_wallet_support_marker.sql` | No-op history marker for order wallet support. |
| `20260501050000_extend_venues_schema_marker.sql` | No-op history marker for venue schema extension. |
| `20260501060000_security_audit_hardening_marker.sql` | No-op history marker for security/audit hardening. |
| `20260501070000_production_schema_delta_marker.sql` | No-op history marker for production schema delta. |
| `20260501080000_rls_policy_performance_marker.sql` | No-op history marker for RLS performance hardening. |
| `20260501090000_order_menu_ingest_marker.sql` | No-op history marker for order/menu ingest work. |
| `20260501100000_sports_bar_pool_engine_marker.sql` | No-op history marker for pool engine work. |
| `20260501110000_pool_invites_rewards_ops_marker.sql` | No-op history marker for invites, rewards, and operations. |
| `20260501120000_pool_observability_social_cards_marker.sql` | No-op history marker for observability and social cards. |
| `20260501121000_pool_abuse_payload_access_marker.sql` | No-op history marker for abuse and payload access controls. |
| `20260501122000_runtime_retirement_marker.sql` | No-op history marker for runtime retirement cleanup. |
| `20260501123000_pool_profile_notification_marker.sql` | No-op history marker for pool profile/notification work. |
| `20260501124000_retired_object_cleanup_marker.sql` | No-op history marker for retired object cleanup. |
| `20260501125000_order_runtime_helper_rename_marker.sql` | No-op history marker for runtime helper rename. |
| `20260501125500_non_product_surface_cleanup_marker.sql` | No-op history marker for non-product surface cleanup. |
| `20260501130000_wallet_reward_engine_marker.sql` | No-op history marker for wallet reward engine work. |
| `20260501131000_core_platform_normalization_marker.sql` | No-op history marker for core platform normalization. |
| `20260501131900_match_pool_live_status_compat.sql` | Remote compatibility shim adding the `live` pool status before dependent functions reference it. |
| `20260501131950_remote_sports_bar_schema_compat.sql` | Additive remote compatibility for country/reward catalogs, pool columns, match curation fields, admin helpers, and audit helpers after the baseline squash. |
| `20260501132000_pool_only_gameplay_controls.sql` | Enforces pool-only gameplay controls and removes retired gameplay surface assumptions from active runtime paths. |
| `20260501141000_venue_operational_console_controls.sql` | Adds audited venue payment status RPC, expanded FET reward config, and venue operational insights RPC. |
| `20260501142500_match_pool_settlement_remote_compat.sql` | Adds settlement match/error/reversal fields required by admin operations on older remote projects. |
| `20260501143000_admin_platform_control_center.sql` | Adds admin control-center RPCs for simplified sports-bar platform operations with audit logging. |
| `20260501144000_curated_match_platform.sql` | Adds curated match discovery, approved competition defaults, fixture-source registry, live-score updates, and curation RPCs. |
| `20260501150000_pool_sharing.sql` | Adds pool deep links, share-link normalization, public share payloads, invite links, and social-card payload support. |
| `20260501151000_remote_grant_and_social_card_hardening.sql` | Revokes broad legacy client grants, adds config metadata, and restores audited social-card URL RPCs. |
| `20260501152000_remote_restricted_function_grants.sql` | Removes anonymous execution from settlement/admin/social-card RPCs. |
| `20260501153000_remote_wallet_engine_compat.sql` | Aligns older remote wallet tables with the canonical ledger API for welcome FET, order rewards, pool stakes, creator rewards, and settlements. |
| `20260501154000_remote_lint_hardening.sql` | Adds compatibility wrappers for retired helper names and order FET summary fields so remote lint validates active routines. |
| `20260501154500_remote_payment_status_enum_compat.sql` | Adds manual-payment enum states used by the venue operational console. |
| `20260501155000_remote_audit_helper_lint_compat.sql` | Replaces the audit helper with a version compatible with both old and clean audit table shapes. |
| `20260501155500_remote_audit_helper_dynamic_sql.sql` | Avoids static lint failures on remote projects whose audit table still uses the old `details_json` shape. |

## Edge Function Inventory

| Function | Purpose | Auth model |
| --- | --- | --- |
| `admin_approve_onboarding` | Admin approval for venue onboarding. | Admin/session checked in function and DB policies. |
| `admin_user_management` | Admin user lifecycle and role operations. | Admin-only. |
| `approve_claim` | Approves venue ownership/claim requests. | Admin/operator. |
| `bar_onboarding_submit` | Submits venue onboarding payload. | Public/authenticated with validation. |
| `bar_search` | Searches venue/bar records. | Client-safe read with validation. |
| `dispatch-match-alerts` | Scheduled kickoff/result alert dispatch. | `x-cron-secret`; calls push pipeline. |
| `generate-pool-social-card` | Generates or stores pool social share card data. | Authenticated pool/venue/admin checks plus service role write. |
| `import-football-data` | Imports curated football data. | Cron/admin secret protected. |
| `menu_ingest_create` | Creates persistent menu image import jobs. | Authenticated venue member. |
| `menu_ingest_worker` | Processes menu OCR jobs and writes review payloads. | Service role or cron secret. |
| `menu_ocr_parse` | Stateless menu OCR parse endpoint. | Authenticated venue member. |
| `order_create` | Creates orders from guest/venue context. | Client auth plus RLS/validation. |
| `order_mark_paid` | Legacy/manual order-paid endpoint. | Venue role checked; prefer current payment RPC for console. |
| `order_update_status` | Updates order service status. | Venue role checked; transition validated. |
| `payment-hub` | Off-platform payment guidance/status helper. | Validated request; no provider API execution. |
| `push-notify` | Sends push notifications. | `x-push-notify-secret`. |
| `ring_bell` | Table assistance/bell request. | Authenticated venue/table context. |
| `settle-match-pools` | Runs idempotent pool settlement. | `x-cron-secret` or service role. |
| `submit_claim` | Submits venue claim. | Public/authenticated with validation. |
| `tables_generate` | Generates table QR records. | Venue owner/manager. |
| `venue_claim` | Venue claim workflow endpoint. | Validated request and policy checks. |
| `whatsapp-otp` | WhatsApp OTP send/verify and custom session issuance. | Public action endpoint with rate limits and secrets. |

## Database Verification

Run after migrations:

```bash
supabase db push --dry-run
supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error
psql "$SUPABASE_DB_URL" -f supabase/tests/bootstrap_required_objects.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/admin_platform_control_center.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/curated_match_platform.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/fet_wallet_reward_engine.sql
```

If `SUPABASE_DB_URL` is not available, use the Supabase CLI-linked database plus `SUPABASE_DB_PASSWORD` as documented by the smoke scripts in `tool/`.
