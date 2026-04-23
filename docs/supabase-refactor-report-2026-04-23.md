# Supabase Refactor Report - 2026-04-23

Project ref: `kjuhheobmdvjwgnzlcwx`

Audit method:
- Supabase MCP was attempted first, but the connector failed with an account-connect error.
- The live project was therefore inspected and refactored through the real Supabase CLI plus a temporary internal-only audit Edge Function that queried Postgres catalogs directly.
- That temporary `schema-audit` function has now been removed from the live project and from the repo.

## 1. Current Supabase architecture summary

The FANZONE backend is now organized around a single app-facing `public` schema, with Supabase support schemas handling auth, storage, jobs, realtime, and secrets:

- Full project surface after cleanup: `97` tables, `21` views, `228` functions, `26` triggers, `80` policies, `1` storage bucket, `6` cron jobs.
- App-facing `public` surface after cleanup: `50` tables, `18` views, `109` functions/RPCs, `19` triggers, `77` policies, `27` public-to-public foreign keys, `133` public indexes.
- Supporting schemas in use: `auth`, `cron`, `extensions`, `graphql`, `graphql_public`, `net`, `public`, `realtime`, `storage`, `supabase_migrations`, `vault`.

The cleaned backend now breaks down into six coherent domains:

- Sports graph: `competitions`, `seasons`, `teams`, `team_aliases`, `matches`, `standings`, `team_form_features`, `predictions_engine_outputs`.
- User/auth foundation: `profiles`, `user_status`, `anonymous_upgrade_claims`, `whatsapp_auth_sessions`, `otp_verifications`, `phone_presets`, `account_deletion_requests`.
- Engagement and notifications: `user_predictions`, `leaderboard_seasons`, `match_alert_subscriptions`, `notification_log`, `notification_preferences`, `product_events`, `app_runtime_errors`.
- Wallet and rewards: `fet_wallets`, `fet_wallet_transactions`, `token_rewards`, `fan_levels`, `fan_badges`, `fan_earned_badges`.
- Platform control and config: `platform_features`, `platform_feature_rules`, `platform_feature_channels`, `platform_content_blocks`, `app_config_remote`, `feature_flags`, `launch_moments`, `featured_events`.
- Operations: vault-backed cron schedules, Edge Functions, cleanup RPCs, admin RPCs, audit logs.

## 2. Implemented inventory

### Tables

Sports and catalog:
- `competitions`
- `seasons`
- `teams`
- `team_aliases`
- `matches`
- `standings`
- `team_form_features`
- `predictions_engine_outputs`

User, auth, onboarding, and preferences:
- `profiles`
- `user_status`
- `anonymous_upgrade_claims`
- `whatsapp_auth_sessions`
- `otp_verifications`
- `phone_presets`
- `account_deletion_requests`
- `device_tokens`
- `user_market_preferences`
- `user_favorite_teams`
- `user_followed_competitions`

Predictions, leaderboard, and live engagement:
- `user_predictions`
- `leaderboard_seasons`
- `match_alert_subscriptions`
- `match_alert_dispatch_log`
- `notification_log`
- `notification_preferences`
- `featured_events`
- `launch_moments`
- `product_events`
- `app_runtime_errors`

Wallet and rewards:
- `fet_wallets`
- `fet_wallet_transactions`
- `token_rewards`
- `fan_levels`
- `fan_badges`
- `fan_earned_badges`

Platform control, content, and remote config:
- `platform_features`
- `platform_feature_rules`
- `platform_feature_channels`
- `platform_content_blocks`
- `feature_flags`
- `app_config_remote`
- `country_region_map`
- `country_currency_map`
- `currency_display_metadata`
- `currency_rates`

Admin and moderation:
- `admin_users`
- `admin_audit_logs`
- `moderation_reports`

Ops and support:
- `rate_limits`
- `cron_job_log`

### Relationships

Live public foreign keys:
- `admin_audit_logs.admin_user_id -> admin_users.id [NO ACTION]`
- `fan_earned_badges.badge_id -> fan_badges.id [NO ACTION]`
- `featured_events.competition_id -> competitions.id [NO ACTION]`
- `match_alert_dispatch_log.match_id -> matches.id [CASCADE]`
- `match_alert_subscriptions.match_id -> matches.id [CASCADE]`
- `matches.away_team_id -> teams.id [NO ACTION]`
- `matches.competition_id -> competitions.id [NO ACTION]`
- `matches.home_team_id -> teams.id [NO ACTION]`
- `matches.season_id -> seasons.id [SET NULL]`
- `moderation_reports.assigned_to -> admin_users.id [NO ACTION]`
- `platform_content_blocks.feature_key -> platform_features.feature_key [SET NULL]`
- `platform_feature_channels.feature_key -> platform_features.feature_key [CASCADE]`
- `platform_feature_rules.feature_key -> platform_features.feature_key [CASCADE]`
- `predictions_engine_outputs.match_id -> matches.id [CASCADE]`
- `profiles.favorite_team_id -> teams.id [SET NULL]`
- `seasons.competition_id -> competitions.id [CASCADE]`
- `standings.competition_id -> competitions.id [CASCADE]`
- `standings.season_id -> seasons.id [CASCADE]`
- `standings.team_id -> teams.id [CASCADE]`
- `team_aliases.team_id -> teams.id [CASCADE]`
- `team_form_features.match_id -> matches.id [CASCADE]`
- `team_form_features.team_id -> teams.id [CASCADE]`
- `token_rewards.match_id -> matches.id [CASCADE]`
- `token_rewards.user_prediction_id -> user_predictions.id [CASCADE]`
- `user_favorite_teams.team_id -> teams.id [CASCADE]`
- `user_followed_competitions.competition_id -> competitions.id [CASCADE]`
- `user_predictions.match_id -> matches.id [CASCADE]`

Additional audited soft references:
- `19` public tables with `user_id` references to `auth.users` were checked and all had `0` orphans.
- `4` admin-related references were checked and all had `0` orphans.
- These were verified in `.audit/runtime_checks_post.json`; not all of them are enforced yet as live foreign keys because delete semantics still need to be chosen table by table.

### Enums

- There are `13` enums in the full project, all in Supabase/system schemas.
- There are no custom app-facing enums in `public`.
- App-facing state is currently constrained primarily with `CHECK` constraints, for example on platform feature status and channel values.

### Views

Public views:
- `admin_audit_logs_enriched`
- `admin_feature_flags`
- `admin_platform_content_blocks`
- `admin_platform_features`
- `app_competitions`
- `app_competitions_ranked`
- `app_matches`
- `competition_standings`
- `fet_supply_overview`
- `fet_supply_overview_admin`
- `fet_transactions_admin`
- `match_prediction_consensus`
- `platform_feature_audit_logs`
- `prediction_leaderboard`
- `public_leaderboard`
- `user_profiles_admin`
- `wallet_overview`
- `wallet_overview_admin`

### Functions / RPCs

The raw full function inventory is captured in `.audit/schema_catalog_post.json`. The app-facing public function surface is grouped as follows.

Admin and security:
- `active_admin_record_id`
- `admin_ban_user`
- `admin_change_admin_role`
- `admin_competition_distribution`
- `admin_credit_fet`
- `admin_dashboard_kpis`
- `admin_debit_fet`
- `admin_engagement_daily`
- `admin_engagement_kpis`
- `admin_fet_flow_weekly`
- `admin_freeze_wallet`
- `admin_global_search`
- `admin_grant_access`
- `admin_log_action`
- `admin_query_daily_active_users`
- `admin_query_event_counts`
- `admin_query_screen_views`
- `admin_revoke_access`
- `admin_set_competition_featured`
- `admin_set_feature_flag`
- `admin_set_featured_event_active`
- `admin_trigger_currency_rate_refresh`
- `admin_unban_user`
- `admin_unfreeze_wallet`
- `admin_update_account_deletion_request`
- `admin_update_match_result`
- `admin_update_moderation_report_status`
- `current_user_has_admin_role`
- `get_admin_me`
- `is_active_admin_operator`
- `is_active_admin_user`
- `is_admin_manager`
- `is_service_role_request`
- `is_super_admin_user`
- `require_active_admin_user`
- `require_admin_manager_user`
- `require_super_admin_user`

Auth, onboarding, guest, and market resolution:
- `complete_user_onboarding`
- `ensure_user_foundation`
- `find_auth_user_by_phone`
- `generate_fan_id`
- `generate_profile_fan_id`
- `get_country_region`
- `guess_user_currency`
- `handle_new_auth_user`
- `issue_anonymous_upgrade_claim`
- `merge_anonymous_to_authenticated`
- `merge_anonymous_to_authenticated_secure`
- `phone_auth_email`
- `resolve_auth_user_phone`

Platform control and remote config:
- `app_config_bigint`
- `assert_platform_feature_available`
- `get_app_bootstrap_config`
- `platform_feature_status_is_live`
- `request_platform_channel`
- `resolve_platform_feature`
- `safe_catalog_key`
- `sync_legacy_feature_flags_from_platform`
- `sync_legacy_feature_flags_on_platform_write`
- `sync_public_feature_flags_from_admin`
- `upsert_vault_secret`

Sports, fixtures, predictions, and leaderboard:
- `app_competition_standings`
- `apply_match_result_code`
- `competition_catalog_rank`
- `compute_result_code`
- `generate_prediction_engine_output`
- `generate_predictions_for_matches`
- `generate_predictions_for_upcoming_matches`
- `generate_team_form_features_for_matches`
- `get_competition_current_season`
- `normalize_match_status`
- `refresh_competition_derived_fields`
- `refresh_global_leaderboard`
- `refresh_season_leaderboard`
- `refresh_team_derived_fields`
- `refresh_team_form_features_for_match`
- `score_finished_matches_with_pending_predictions`
- `score_user_predictions_for_match`
- `season_end_year`
- `season_sort_key`
- `season_start_year`
- `submit_user_prediction`
- `upsert_team_form_feature`

Wallet, rewards, and notifications:
- `assert_fet_mint_within_cap`
- `assert_wallet_available`
- `audit_wallet_bootstrap_gaps`
- `fet_supply_cap`
- `lock_fet_supply_cap`
- `mark_all_notifications_read`
- `mark_notification_read`
- `notify_wallet_credit`
- `repair_wallet_bootstrap_gaps`
- `send_push_to_user`
- `transfer_fet`
- `transfer_fet_by_fan_id`

Ops, cleanup, telemetry, and generic utilities:
- `assign_profile_fan_id`
- `check_rate_limit`
- `cleanup_expired_otps`
- `cleanup_rate_limits`
- `install_lean_runtime_schedules`
- `log_app_runtime_errors_batch`
- `log_platform_control_change`
- `log_product_event`
- `log_product_events_batch`
- `remove_lean_runtime_schedules`
- `rls_auto_enable`
- `set_row_updated_at`
- `set_updated_at`

### Triggers

Public triggers:
- `competitions.trg_competitions_updated_at -> set_updated_at`
- `fet_wallet_transactions.trg_notify_wallet_credit -> notify_wallet_credit`
- `fet_wallets.set_wallet_updated_at -> set_updated_at`
- `matches.trg_apply_match_result_code -> apply_match_result_code`
- `matches.trg_matches_updated_at -> set_updated_at`
- `platform_content_blocks.platform_content_blocks_audit_write -> log_platform_control_change`
- `platform_feature_channels.platform_feature_channels_audit_write -> log_platform_control_change`
- `platform_feature_channels.platform_feature_channels_sync_feature_flags_write -> sync_legacy_feature_flags_on_platform_write`
- `platform_feature_rules.platform_feature_rules_audit_write -> log_platform_control_change`
- `platform_feature_rules.platform_feature_rules_sync_feature_flags_write -> sync_legacy_feature_flags_on_platform_write`
- `platform_features.platform_features_audit_write -> log_platform_control_change`
- `platform_features.platform_features_sync_feature_flags_write -> sync_legacy_feature_flags_on_platform_write`
- `profiles.set_profiles_updated_at -> set_updated_at`
- `profiles.trg_profiles_assign_fan_id -> assign_profile_fan_id`
- `seasons.trg_seasons_updated_at -> set_updated_at`
- `standings.trg_standings_updated_at -> set_updated_at`
- `team_form_features.trg_team_form_features_updated_at -> set_updated_at`
- `teams.trg_teams_updated_at -> set_updated_at`
- `user_predictions.trg_user_predictions_updated_at -> set_updated_at`

### Policies

Public policy coverage now totals `77` policies across `41` public tables.

Policy counts by table:
- `account_deletion_requests: 4`
- `admin_users: 2`
- `app_config_remote: 2`
- `competitions: 2`
- `country_currency_map: 2`
- `country_region_map: 2`
- `currency_display_metadata: 2`
- `currency_rates: 1`
- `device_tokens: 1`
- `fan_badges: 1`
- `fan_levels: 1`
- `feature_flags: 2`
- `featured_events: 1`
- `fet_wallet_transactions: 3`
- `fet_wallets: 2`
- `launch_moments: 2`
- `leaderboard_seasons: 1`
- `match_alert_subscriptions: 1`
- `matches: 2`
- `moderation_reports: 2`
- `notification_log: 3`
- `notification_preferences: 1`
- `phone_presets: 2`
- `platform_content_blocks: 1`
- `platform_feature_channels: 1`
- `platform_feature_rules: 1`
- `platform_features: 1`
- `predictions_engine_outputs: 2`
- `product_events: 1`
- `profiles: 3`
- `seasons: 1`
- `standings: 2`
- `team_aliases: 2`
- `team_form_features: 2`
- `teams: 2`
- `token_rewards: 2`
- `user_favorite_teams: 4`
- `user_followed_competitions: 2`
- `user_market_preferences: 3`
- `user_predictions: 4`
- `user_status: 1`

The raw policy names are preserved in `.audit/schema_catalog_post.json`.

### Storage buckets

Active bucket inventory:
- `team-crests` (`public = true`)

### Edge Functions

Active live functions after cleanup:
- `push-notify`
- `whatsapp-otp`
- `dispatch-match-alerts`
- `import-football-data`
- `generate-predictions`
- `score-predictions`

### Cron jobs

Active live jobs after cleanup:
- `fanzone-import-football-data`
- `fanzone-generate-predictions`
- `fanzone-score-predictions`
- `fanzone-dispatch-match-alerts`
- `fanzone-cleanup-rate-limits`
- `fanzone-cleanup-expired-otps`

## 3. Deprecated, duplicate, and broken objects to remove

Removed live in this refactor:
- Duplicate trigger `public.matches.trg_matches_set_updated_at`
- Duplicate policies on `competitions`, `matches`, `teams`, `featured_events`, and `currency_rates`
- Broken legacy cron jobs:
  - `market-sync-openfootball`
  - `fanzone-currency-rates-daily`
  - `fanzone-team-news-hourly`
  - `cleanup-match-sync-log`
  - `cleanup-old-update-runs`
  - `daily-screenshot-odds`
- Temporary audit function `schema-audit`

Retired by the lean scheduler migrations already present in the repo:
- `public.install_openfootball_sync_schedule(...)`
- `public.remove_openfootball_sync_schedule(text)`
- `public.refresh_materialized_views()`

Still a candidate for removal after final client cutovers:
- `public.cron_job_log` if no active writer remains
- `public.send_push_to_user` if Edge-based push delivery is made canonical
- Direct client dependency on `public.feature_flags` once all surfaces read from the platform registry/bootstrap path

## 4. Consolidation plan

Canonical sources of truth going forward:

- Platform gating and UI composition:
  - `platform_features`
  - `platform_feature_rules`
  - `platform_feature_channels`
  - `platform_content_blocks`

- Compatibility bridge only:
  - `feature_flags`
  - The sync trigger/function pair keeps this populated for older clients while the platform registry becomes canonical.

- Runtime numeric and JSON configuration:
  - `app_config_remote`
  - Country and currency tables for region-aware display

- Sports graph:
  - `competitions -> seasons -> matches`
  - `teams` and `team_aliases`
  - `standings`
  - `team_form_features`
  - `predictions_engine_outputs`

- User state:
  - `profiles`
  - `user_status`
  - `user_favorite_teams`
  - `user_followed_competitions`
  - `user_market_preferences`

- Prediction and reward loop:
  - `user_predictions`
  - `predictions_engine_outputs`
  - `leaderboard_seasons`
  - `token_rewards`
  - `fet_wallets`
  - `fet_wallet_transactions`

- Auth, guest, and WhatsApp OTP:
  - `auth.users`
  - `profiles`
  - `anonymous_upgrade_claims`
  - `whatsapp_auth_sessions`
  - `otp_verifications`
  - `phone_presets`

This leaves one coherent backend model: the platform registry drives what surfaces appear, the sports graph drives all match data, the prediction loop drives gameplay, and the wallet/reward system remains ledger-based.

## 5. Schema and relationship fixes needed

Completed in this refactor:
- Repaired orphaned `profiles.favorite_team_id` values through `team_aliases`
- Null-cleared any unresolved favorites before adding the FK
- Added live foreign keys for:
  - `matches.season_id -> seasons.id`
  - `profiles.favorite_team_id -> teams.id`
  - `user_favorite_teams.team_id -> teams.id`
- Verified `0` orphans on all audited domain and auth references in `.audit/runtime_checks_post.json`

Still needed:
- Add explicit `auth.users` foreign keys for the `19` audited `user_id` references once delete behavior is chosen per table.
- Decide whether those references should use `CASCADE`, `SET NULL`, or `RESTRICT` by data domain rather than applying one blanket rule.
- Review `cron_job_log` ownership and either wire it to active jobs or archive/drop it.
- Treat `feature_flags` as compatibility only; do not add new product logic there.
- No obvious catalog-level FK or index emergency remains, but query-level index tuning should still be done with `EXPLAIN ANALYZE` against production read/write patterns.

## 6. Policy, RLS, and security fixes needed

Implemented now:
- Duplicate public/admin policies removed
- `PUBLIC` and `anon` access revoked from all `admin_*` functions
- `PUBLIC` and non-service execution revoked from `cleanup_expired_otps`, `cleanup_rate_limits`, `notify_wallet_credit`, and `send_push_to_user`
- `mark_all_notifications_read()` and `mark_notification_read(uuid)` repaired to target `notification_log` instead of the dead `user_notifications` table
- Release and auth smoke probes re-ran successfully after the live cleanup

Still needed:
- Several user-owned tables still rely on `TO public` RLS policies with `auth.uid()` predicates. They are not currently leaking data, but they are broader than necessary. The next hardening pass should move these to `TO authenticated` after guest/anonymous-auth flows are confirmed:
  - `profiles`
  - `fet_wallets`
  - `fet_wallet_transactions`
  - `user_favorite_teams`
  - `user_followed_competitions`
  - `user_market_preferences`
  - `notification_log`
  - `notification_preferences`
  - `user_predictions`
  - `token_rewards`
- Consider `FORCE ROW LEVEL SECURITY` on the most sensitive user-financial tables once the admin/service execution paths are fully validated.
- `send_push_to_user` still depends on old DB runtime settings that do not exist anymore:
  - `app.settings.supabase_url`
  - `app.settings.service_role_key`
  - `app.settings.push_notify_secret`
- If strict anon denial semantics are required for notification RPCs, re-check grants again after the next auth hardening pass.

## 7. Missing tables, functions, views, and config structures needed

The core domain model is present. The biggest gaps are operational and cleanup-related, not missing business entities.

Recommended additions:
- An explicit auth-FK hardening migration pack covering the `19` audited `user_id` references.
- A real ops reporting surface for scheduled jobs if `cron_job_log` is kept, either as a view over `cron.job` and job outcomes or as a clearly-owned write path.
- A vault-backed push dispatch standardization path so the system uses one notification delivery mechanism instead of a legacy DB helper plus Edge Functions.
- A richer bootstrap projection, either by extending `get_app_bootstrap_config()` or adding a dedicated `app_platform_bootstrap` view/RPC that returns:
  - platform feature registry status
  - content blocks
  - config values
  - market/currency metadata
  - phone presets

## 8. Final cleaned Supabase architecture linked to Flutter, admin, and web

Flutter mobile app:
- Reads bootstrap/config through `get_app_bootstrap_config()`
- Reads dynamic surface rules from the platform registry
- Uses `app_matches`, `app_competitions`, `competition_standings`, `public_leaderboard`, wallet views, notifications, and OTP/guest-upgrade flows

Admin panel:
- Uses `admin_*` RPCs as the primary privileged plane
- Reads `admin_feature_flags`, `admin_platform_features`, `admin_platform_content_blocks`, `admin_audit_logs_enriched`, `user_profiles_admin`, `wallet_overview_admin`, `fet_transactions_admin`
- Operates against the same underlying public tables, not a second backend

Website and landing pages:
- Uses the same read models as mobile where possible: `app_matches`, `app_competitions_ranked`, `featured_events`, `public_leaderboard`
- Can be driven from `platform_content_blocks` and `platform_features` instead of hardcoded landing-page logic

Edge Functions and background jobs:
- `import-football-data`, `generate-predictions`, `score-predictions`, and `dispatch-match-alerts` are the scheduled operational plane
- Cron is now vault-backed and points only to the lean production jobs
- DB functions remain responsible for scoring, leaderboard refresh, derived team/competition values, cleanup, and admin operations

Auth and onboarding:
- `auth.users` is the identity root
- `profiles` and `user_status` hold user-facing state
- guest upgrade, WhatsApp OTP, and account transition flows stay database-driven through the existing auth/merge RPCs

This is the cleaned target state: one Supabase project, one app-facing schema, one feature-registry model, one sports graph, one wallet ledger, and one scheduled runtime plane shared by Flutter, admin, website, and background jobs.

## 9. Migration and refactor plan

Implemented and captured in repo migrations:
- `supabase/migrations/20260423083000_supabase_hardening_cleanup.sql`
- `supabase/migrations/20260423110000_platform_feature_registry.sql`
- `supabase/migrations/20260423120000_lean_production_scheduler_and_runtime_freeze.sql`
- `supabase/migrations/20260423123000_finalize_lean_scheduler_surface.sql`
- `supabase/migrations/20260423130000_permission_hardening_followup.sql`
- `supabase/migrations/20260423131000_notification_rpc_fix.sql`

Recommended next sequence:
1. Ship an auth-reference FK migration pack with explicit delete semantics per table.
2. Tighten user-owned policies from `TO public` to `TO authenticated`.
3. Refactor or retire `send_push_to_user` so all delivery flows use one vault-backed path.
4. Cut app/web/admin surfaces fully onto the platform registry/bootstrap path and then retire `feature_flags` as a first-class source of truth.
5. Archive or remove `cron_job_log` if it remains unwired.

## 10. Remaining risks

- `send_push_to_user` still points at missing DB runtime settings and remains the main functional leftover.
- `cron_job_log` looks stale and may mislead operators unless it is either wired up or removed.
- Some RLS policies are still broader than necessary because they use `TO public` with `auth.uid()` filters.
- `feature_flags` is still present as a compatibility mirror; that dual-surface state should not be kept indefinitely.
- Catalog cleanup is complete enough for production use, but workload-specific index tuning still requires query-plan review under real traffic.
- Supabase MCP could not be used because the connector failed; the live project was audited and changed through the CLI and direct catalog inspection instead.

## Evidence files

Generated audit artifacts kept in the repo for traceability:
- `.audit/schema_summary.json`
- `.audit/schema_catalog.json`
- `.audit/schema_catalog_post.json`
- `.audit/runtime_checks.json`
- `.audit/runtime_checks_post.json`
- `.audit/app_rpc_definitions.json`
- `.audit/config_samples.json`
- `.audit/ops_samples.json`
- `.audit/profiles_with_favorites.json`
- `.audit/teams_min.json`
