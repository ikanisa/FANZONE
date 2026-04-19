# FANZONE Scalability and Architecture Gap Report

Generated: 2026-04-19
Scope: Flutter app, admin app, Supabase schema/migrations, RLS/policies, RPCs/functions, Edge Functions, local Supabase setup, and database-driven architecture fit for Malta now and Europe later.

## Executive Summary

FANZONE already has a substantial Supabase foundation: 69 tables, 10 views, 1 materialized view, 121 SQL functions/RPCs, 99 RLS policies, 5 triggers, 6 Edge Functions, and 6 SQL verification/smoke tests. Core domains already exist for profiles, wallets, prediction pools, slips, daily challenges, team communities, marketplace, notifications, admin tooling, analytics, runtime telemetry, guest auth, and market preferences.

The repo is not yet fully Supabase-first in the places that matter most for scale and multi-market operations. The biggest gap is not missing tables; it is that important runtime behavior is still decided in Flutter code instead of being resolved from Supabase. Feature enablement, onboarding team discovery, market defaults, launch moment ranking, phone-country rules, and some event/challenge ordering are still app-embedded. The schema contains many of the right objects, but the mobile app often bypasses them.

The current implementation is strong enough for a controlled launch, but it is not yet truly dynamic, fully database-driven, or operationally scalable across multiple European markets. The fastest path to production readiness is:

- move runtime feature/config resolution to backend-readable config tables or RPCs
- normalize sports/event relationships that are currently stored as arrays
- replace high-frequency polling and whole-table reads with narrower views/RPCs and selective Realtime
- close a few integrity/security gaps in functions and foreign keys
- create backend-owned composition endpoints for home feed, event hub, search, and notification dispatch

## Highest-Priority Findings

1. `merge_anonymous_to_authenticated` is missing caller ownership checks.
The function in `supabase/migrations/20260420000000_guest_auth_and_onboarding_v2.sql` moves favorites/follows/profile data from any anonymous user id to any authenticated user id, but it does not verify `auth.uid()` against either id. Because it is `SECURITY DEFINER` and executable by `authenticated`, this is a real privilege boundary gap.

2. Runtime feature control is compile-time, not app-runtime, despite having backend feature-flag infrastructure.
`lib/config/app_config.dart` drives feature access with `bool.fromEnvironment(...)`. The admin app manages `admin_feature_flags` through `admin/src/features/settings/useSettings.ts`, but those flags are admin-only and are not consumed by Flutter. This means the app is not operationally controllable per market, cohort, or rollout window.

3. Core onboarding and market logic is still hardcoded in Flutter.
`lib/features/onboarding/data/team_search_catalog.dart`, `lib/core/market/launch_market.dart`, `lib/core/constants/phone_presets.dart`, and `_inferRegion()` in `lib/features/onboarding/data/onboarding_gateway.dart` still embed team catalogs, region mapping, phone formatting rules, and default launch moments in code.

4. Several data models use denormalized arrays where join tables should exist.
`public.teams.competition_ids` is a `TEXT[]` in `supabase/migrations/004_sports_foundation.sql`. `public.global_challenges.match_ids` is a `TEXT[]` in `supabase/migrations/017_global_launch_schema.sql`. These choices complicate indexing, joins, integrity, and multi-market curation.

5. Match, feed, and detail experiences are polling-heavy instead of Realtime- or RPC-driven.
`lib/features/home/data/matches_gateway_shared.dart` polls every 15 seconds. `lib/features/community/data/feed_gateway.dart` polls every 10 seconds. Detail tabs fetch `live_match_events`, `match_odds_cache`, `match_advanced_stats`, `match_player_stats`, and `match_events` separately. Realtime is enabled in `supabase/config.toml`, but the app is not using it.

6. Some important tables still miss foreign keys on ownership columns.
Confirmed examples: `public.team_supporters.user_id`, `public.team_contributions.user_id`, `public.daily_challenge_entries.user_id`, `public.notification_log.user_id`, `public.redemptions.user_id`, `public.moderation_reports.reporter_user_id`.

7. The custom WhatsApp OTP auth flow works, but the session model is brittle.
`supabase/functions/whatsapp-otp/index.ts` returns `refresh_token: null`, and `lib/features/auth/data/auth_gateway.dart` reuses the access token as a compatibility seed for `setSession`. This is workable short-term, but it is nonstandard and weakens session lifecycle, rotation, and future auth extensibility.

8. Local Supabase reset is misconfigured.
`supabase/config.toml` enables `[db.seed]` with `sql_paths = ["./seed.sql"]`, but `supabase/seed.sql` does not exist. `supabase db reset` will not reproduce a complete environment.

## Current Implementation Summary

The Flutter app is already wired to Supabase for the main user flows. It reads directly from sports, prediction, wallet, notification, event, and community tables and uses RPCs for wallet transfers, team support, pool creation/joining, predictions, feed messaging, marketplace redemption, runtime logging, and anonymous-account merge. The admin app is also Supabase-backed: it reads tables/views directly through generic query hooks and uses mutation RPCs for privileged actions.

The backend side is broader than the mobile side currently exploits. Supabase already contains structures for:

- profile, wallet, fan identity, seasonal leaderboard, community contest, team support, team contribution, team news, marketplace, notifications, admin operations, account deletion, analytics, runtime error telemetry, market preferences, featured events, global challenges, guest auth, and match sync scheduling
- RPCs for settlement, transfers, admin mutations, analytics, telemetry, search, currency inference, fan id generation, and match sync orchestration
- Edge Functions for OTP auth, sports ingestion, currency refresh, team news ingestion, push delivery, and auto settlement

The main architectural gap is therefore not “no backend”; it is “backend exists, but too much product behavior still lives in app code.”

## Implemented vs Missing Matrix

| Area | Implemented | Missing / Gap |
| --- | --- | --- |
| Auth | Anonymous auth, WhatsApp OTP, guest upgrade schema, profile flags | safer merge authorization, proper refresh-token/session lifecycle |
| Profiles / onboarding | profiles, user_favorite_teams, user_market_preferences, fan id generation, currency inference | backend-driven team search, market defaults, phone presets, region inference |
| Sports core | competitions, teams, matches, live events, stats, odds cache, match sync runtime | normalized competition-team mapping, backend-composed match center/home feed |
| Predictions | pools, entries, slips, selections, daily challenges, settlement RPCs | event/global challenge participation tables and settlement model |
| Community | supporters, contributions, news, contests, feed messages | Realtime feed delivery, backend-owned ranking/composition, stronger integrity FKs |
| Wallet / rewards | wallet ledger, transfers, admin credit/debit, marketplace redemption | configurable FET pricing/peg governance surface if peg must become dynamic |
| Notifications | preferences, device tokens, notification log, push Edge Function, match_alert_subscriptions table | actual match-alert dispatcher tied to match events and subscriptions |
| Admin | admin users, audit, feature flags, campaigns, partner/reward/redemption moderation, analytics RPCs | user-app consumable runtime config layer derived from admin flags |
| Content / market | featured_events, global_challenges, content_banners, campaigns, market preferences | backend ranking, market directory, content slots, market-aware feature resolution |
| Analytics / ops | product_events, app_runtime_errors, SQL tests, job/audit tables | reproducible seed setup, generalized job run monitoring, alerting hooks |

## Full Implemented Inventory

### Supabase Setup

- Migrations: 50 SQL migration files under `supabase/migrations`
- Tests: `bootstrap_required_objects.sql`, `fet_supply_cap_smoke.sql`, `rls_hardening_audit.sql`, `rls_verification.sql`, `admin_data_plane_verification.sql`, `whatsapp_auth_verification.sql`
- Local config: `supabase/config.toml`
- Realtime: enabled in local config
- Seed config: enabled, but points to missing `supabase/seed.sql`
- Explicit Postgres enums: none found; statuses are modeled mostly as `TEXT` plus `CHECK`

### Edge Functions

- `whatsapp-otp`
- `auto-settle`
- `push-notify`
- `gemini-team-news`
- `gemini-currency-rates`
- `gemini-sports-data`

### Tables

Sports and catalog:

- `public.competitions`
- `public.teams`
- `public.matches`
- `public.live_match_events`
- `public.competition_standings`
- `public.news`
- `public.match_advanced_stats`
- `public.match_player_stats`
- `public.match_events`
- `public.match_ai_analysis`
- `public.match_odds_cache`
- `public.match_sync_state`
- `public.match_sync_request_log`

Auth, profile, onboarding, preferences:

- `public.profiles`
- `public.app_preferences`
- `public.user_followed_teams`
- `public.user_followed_competitions`
- `public.user_favorite_teams`
- `public.user_market_preferences`
- `public.user_status`
- `public.otp_verifications`

Wallet, transfers, marketplace, rewards:

- `public.fet_wallets`
- `public.fet_wallet_transactions`
- `public.marketplace_partners`
- `public.marketplace_offers`
- `public.marketplace_redemptions`
- `public.partners`
- `public.rewards`
- `public.redemptions`

Predictions and leaderboards:

- `public.prediction_challenges`
- `public.prediction_challenge_entries`
- `prediction_slips`
- `prediction_slip_selections`
- `public.daily_challenges`
- `public.daily_challenge_entries`
- `public.leaderboard_seasons`
- `public.leaderboard_entries`
- `public.community_contests`
- `public.community_contest_entries`
- `public.global_challenges`
- `public.featured_events`

Community and social:

- `public.team_supporters`
- `public.team_contributions`
- `public.team_news`
- `public.team_news_ingestion_runs`
- `public.feed_messages`
- `public.feed_rate_limits`
- `public.fan_profiles`
- `public.fan_levels`
- `public.fan_badges`
- `public.fan_earned_badges`
- `public.fan_xp_log`

Notifications and campaigns:

- `public.device_tokens`
- `public.notification_preferences`
- `public.notification_log`
- `public.match_alert_subscriptions`
- `public.content_banners`
- `public.campaigns`

Admin and moderation:

- `public.admin_users`
- `public.admin_audit_logs`
- `public.admin_feature_flags`
- `public.admin_notes`
- `public.moderation_reports`
- `public.account_deletion_requests`

Analytics and telemetry:

- `public.product_events`
- `public.app_runtime_errors`
- `public.rate_limits`
- `public.country_currency_map`
- `public.currency_rates`

### Views and Materialized Views

- `public.public_leaderboard`
- `public.team_community_stats`
- `public.fet_supply_overview`
- `public.user_profiles_admin`
- `public.wallet_overview_admin`
- `public.fet_transactions_admin`
- `public.admin_audit_logs_enriched`
- `public.challenge_feed`
- `public.fan_clubs`
- `public.fet_supply_overview_admin`
- `public.mv_season_leaderboard` (materialized)

### Triggers

- `trg_prediction_slips_updated_at`
- `trg_auto_community_contest`
- `trg_profiles_assign_fan_id`
- `trg_notify_wallet_credit`
- `normalize_match_status_before_write`

### Functions / RPCs

Auth, profile, onboarding, utilities:

- `public.resolve_auth_user_phone`
- `public.generate_profile_fan_id`
- `public.generate_fan_id`
- `public.assign_profile_fan_id`
- `public.guess_user_currency`
- `public.find_auth_user_by_phone`
- `public.merge_anonymous_to_authenticated`
- `generate_anonymous_fan_id`

Team community:

- `support_team`
- `unsupport_team`
- `contribute_fet_to_team`
- `get_team_anonymous_fans`
- `auto_create_community_contest`

Predictions, pools, slips, settlements:

- `create_pool`
- `join_pool`
- `submit_prediction_slip`
- `settle_pool`
- `void_pool`
- `auto_settle_pools`
- `settle_prediction_slips_for_match`
- `submit_daily_prediction`
- `settle_daily_challenge`
- `create_pool_rate_limited`
- `transfer_fet_rate_limited`
- `check_rate_limit`
- `cleanup_rate_limits`

Wallet and FET:

- `transfer_fet`
- `public.transfer_fet`
- `public.transfer_fet_by_fan_id`
- `public.fet_supply_cap`
- `public.lock_fet_supply_cap`
- `public.assert_fet_mint_within_cap`
- `public.ensure_user_foundation`
- `admin_credit_fet`
- `admin_debit_fet`
- `admin_freeze_wallet`
- `admin_unfreeze_wallet`
- `public.admin_credit_fet`

Social feed:

- `send_feed_message`
- `react_to_message`

Marketplace:

- `redeem_offer`

Fan identity and seasonal leaderboard:

- `award_xp`
- `refresh_season_leaderboard`

Push and notification helpers:

- `send_push_to_user`
- `notify_pool_settled`
- `notify_daily_challenge_winners`
- `notify_wallet_credit`
- `public.send_push_to_user`

Match sync and sports runtime:

- `public.normalize_match_status_value`
- `public.normalize_match_status_before_write`
- `public.dispatch_match_sync_jobs`
- `public.reconcile_match_sync_responses`
- `public.enqueue_match_sync_jobs`
- `public.run_match_sync_cycle`

Admin auth and role helpers:

- `public.is_service_role_request`
- `public.is_active_admin_user`
- `public.require_active_admin_user`
- `public.require_super_admin_user`
- `public.require_admin_manager_user`
- `public.is_active_admin_operator`
- `public.is_admin_manager`
- `public.is_super_admin_user`
- `public.active_admin_record_id`

Admin analytics and search:

- `public.admin_dashboard_kpis`
- `public.admin_engagement_kpis`
- `public.admin_engagement_daily`
- `public.admin_fet_flow_weekly`
- `public.admin_competition_distribution`
- `public.admin_query_event_counts`
- `public.admin_query_daily_active_users`
- `public.admin_query_screen_views`
- `public.admin_global_search`
- `public.get_pool_settlement_reconciliation`
- `public.get_pool_settlement_integrity_summary`

Admin content and ops mutations:

- `public.admin_set_feature_flag`
- `public.admin_set_reward_active`
- `public.admin_set_reward_featured`
- `public.admin_set_banner_active`
- `public.admin_delete_banner`
- `public.admin_create_campaign`
- `public.admin_update_campaign_status`
- `public.admin_delete_campaign`
- `public.admin_send_campaign`
- `public.admin_publish_team_news`
- `public.admin_trigger_currency_rate_refresh`
- `public.admin_trigger_team_news_ingestion`
- `public.admin_set_competition_featured`
- `public.admin_update_match_result`
- `public.admin_auto_settle_match`
- `public.admin_set_partner_featured`
- `public.admin_set_featured_event_active`
- `public.admin_update_moderation_report_status`
- `public.admin_update_account_deletion_request`
- `public.admin_approve_partner`
- `public.admin_reject_partner`
- `public.admin_approve_redemption`
- `public.admin_reject_redemption`
- `public.admin_fulfill_redemption`
- `public.admin_log_action`
- `public.admin_grant_access`
- `public.admin_change_admin_role`
- `public.admin_revoke_access`

Telemetry:

- `public.log_product_event`
- `public.log_product_events_batch`
- `public.log_app_runtime_errors_batch`

### RLS / Policy Coverage

Public-read tables and views already exist for most catalogue surfaces:

- competitions, teams, matches, live_match_events, news
- featured_events, global_challenges
- daily_challenges, match_odds_cache
- team_news where `status = 'published'`
- rewards and banners where active
- seasonal leaderboard tables/views

User-scoped RLS already exists for:

- profiles, app_preferences
- wallets and wallet transactions
- prediction entries, slips, slip selections
- team follows and competition follows
- user_favorite_teams
- user_market_preferences
- notification_preferences, notification_log, device_tokens, match_alert_subscriptions
- account_deletion_requests
- fan profile / earned badges / XP log

Admin-only RLS already exists for:

- admin_users, admin_audit_logs, admin_feature_flags, admin_notes
- partners, rewards, redemptions
- campaigns, moderation_reports
- admin read access to wallet transactions, challenge entries, notifications

### Seed and Config Structures

- `supabase/config.toml` sets `api.max_rows = 1000`
- `supabase/config.toml` enables Realtime locally
- `supabase/config.toml` enables seed loading from missing `./seed.sql`
- Flutter uses build-time config in `lib/config/app_config.dart`
- Flutter loads onboarding/static team data from `lib/features/onboarding/data/team_search_catalog.dart` and `assets/data/team_search_database.json`

## Table-by-Table Review

Core identity and onboarding:

- `profiles`: good central profile table, but identity is duplicated across `id` and `user_id`; app upserts both. It also now carries onboarding, country, currency, region, fan id, and anonymous-auth state. Recommendation: converge on one canonical user key.
- `user_favorite_teams`: correct ownership model and RLS; however it duplicates team display fields instead of referencing `teams` as the source of truth. Good for snapshotting, but onboarding search should still be DB-driven.
- `user_market_preferences`: good start for market personalization; current shape is user preference storage, not global market configuration. It should not be responsible for defaulting logic that belongs to backend config.
- `app_preferences`: minimal; fine.
- `otp_verifications`: service-role-only and appropriate for OTP flow.

Sports domain:

- `competitions`: fine base table, but lightweight. Regional/event metadata was added later.
- `teams`: `competition_ids TEXT[]` is a scalability shortcut. Replace with a join table if team-to-competition affiliation needs filtering, indexing, and future historical validity.
- `matches`: good central fixture/result table; powers several product areas. This should remain the source of truth for fixtures and results.
- `live_match_events`, `match_events`, `match_advanced_stats`, `match_player_stats`, `match_ai_analysis`, `match_odds_cache`: solid event/stats satellites, but the app fetches them one by one on timers instead of through a composed backend surface.
- `competition_standings`: good read-only competition surface.
- `match_sync_state`, `match_sync_request_log`: useful operational runtime tables for ingestion and retries.

Prediction domain:

- `prediction_challenges` and `prediction_challenge_entries`: strong pool/challenge core for match-based pools.
- `prediction_slips` and `prediction_slip_selections`: useful for accumulator/slip-style predictions; backed by settlement logic and trigger-updated timestamps.
- `daily_challenges` and `daily_challenge_entries`: already implemented and backend-settled, but `daily_challenge_entries.user_id` should be a FK to `auth.users`.
- `global_challenges`: currently acts more like event marketing metadata than a complete gameplay model. It lacks an entry table, participation ledger, settlement model, and reward issuance path.
- `leaderboard_seasons`, `leaderboard_entries`, `public_leaderboard`, `mv_season_leaderboard`: good foundation for seasonal and public leaderboard use cases.

Community domain:

- `team_supporters`: good concept, but `user_id` should be FK-backed. Reads/writes are correctly forced through RPCs rather than direct DML.
- `team_contributions`: same integrity issue on `user_id`. Otherwise a useful contribution ledger.
- `team_news` and `team_news_ingestion_runs`: good pattern for grounded AI ingestion plus audit trail.
- `community_contests` and `community_contest_entries`: implemented and trigger-driven from matches; good foundation.
- `feed_messages` and `feed_rate_limits`: reasonable schema for public/team/pool/match chats, but the app still polls instead of using Realtime subscriptions.

Wallet and rewards:

- `fet_wallets` and `fet_wallet_transactions`: strong foundation. Wallet transactions are the right place for immutable ledger history.
- `marketplace_partners`, `marketplace_offers`, `marketplace_redemptions`: well-shaped marketplace domain with atomic redemption RPC.
- `partners`, `rewards`, `redemptions`: admin/reward stack is present, but `redemptions.user_id` is not FK-backed.

Notifications and campaigns:

- `device_tokens` and `notification_preferences`: implemented and correctly user-scoped.
- `notification_log`: implemented, but `user_id` lacks FK integrity.
- `match_alert_subscriptions`: schema and app write path exist, but there is no actual dispatcher that reads this table from live match events or status transitions.
- `content_banners` and `campaigns`: useful admin/content primitives; they can become part of a runtime config/content composition layer.

Admin, moderation, analytics:

- `admin_users`, `admin_audit_logs`, `admin_feature_flags`, `admin_notes`: solid admin plane.
- `moderation_reports`: useful, but `reporter_user_id` lacks FK integrity.
- `product_events` and `app_runtime_errors`: good telemetry start and already backed by batch RPCs.
- `account_deletion_requests`: production-minded and properly scoped.

Fan identity:

- `fan_profiles`, `fan_levels`, `fan_badges`, `fan_earned_badges`, `fan_xp_log`: already sufficient for a badge/level system, though some app experiences still fall back to seeded data in development.

## Hardcoded / Static Logic Report

### Already in backend, but still hardcoded in Flutter

- Feature gating: `lib/config/app_config.dart`
- Region labels, descriptions, focus tags, launch moments, country buckets: `lib/core/market/launch_market.dart`
- Phone-country dial code and format rules: `lib/core/constants/phone_presets.dart`
- Onboarding team catalog defaults and aliases: `lib/features/onboarding/data/team_search_catalog.dart`
- Onboarding profile region inference: `_inferRegion()` in `lib/features/onboarding/data/onboarding_gateway.dart`
- Event and challenge ranking weights: `lib/providers/market_preferences_provider.dart`
- Event-hub challenge visibility: `AppConfig.enableGlobalChallenges` in `lib/features/home/screens/event_hub_screen.dart`

### Static / seeded fallback data that still exists in app code

- fallback competitions, teams, standings, featured events, global challenges: `lib/features/home/data/catalog_gateway_shared.dart`
- fallback matches and odds: `lib/features/home/data/matches_gateway_shared.dart`
- fallback leaderboard / daily challenge: `lib/features/predict/data/predict_gateway_shared.dart`
- fallback fan levels, badges, profile XP history, contests: `lib/features/profile/data/engagement_gateway_shared.dart`
- fallback team news and anonymous fan id helpers: `lib/features/community/data/community_gateway_shared.dart`
- fallback fan clubs, wallet balance, wallet transactions, marketplace offers, currency rates: `lib/features/wallet/data/wallet_gateway.dart`

### Business logic currently living in app code that should move server-side

- market-aware event ranking
- challenge ranking and visibility
- launch defaults per country/region
- team onboarding search/popularity
- phone-country input rules if markets are expected to expand
- home screen composition and per-market ordering
- match center composition and partial aggregation
- notification subscription dispatch resolution

## What Exists but Is Not Fully Used

- `admin_feature_flags` exists, but mobile cannot use it today because the app reads compile-time flags and RLS only exposes that table to admins.
- `featured_events` and `global_challenges` exist and are read by the app, but ranking and visibility are still resolved in Flutter.
- `user_market_preferences` exists and is read/written by the app, but defaults, market definitions, and focus tags are still derived in code.
- `match_alert_subscriptions` exists and the app writes to it, but delivery logic is not wired end-to-end.
- Realtime is enabled locally, but mobile/community/match streams are still polling-based.

## Gaps and Missing Pieces

### Missing data model pieces

- no `competition_teams` / `team_competitions` join table
- no `global_challenge_entries` table
- no `global_challenge_rewards` / `global_challenge_settlements` model
- no explicit `markets` or `country_directory` table for runtime country/market metadata
- no backend-readable runtime config surface for the user app
- no search alias/search document layer for team and competition discovery
- no notification template registry
- no generalized job run / scheduler monitoring table for Edge Function operational runs

### Missing backend composition surfaces

- no RPC/view that resolves mobile feature flags for a user or market
- no RPC/view that resolves the home feed in one backend-owned response
- no RPC/view that resolves event-hub sections and ranking
- no RPC/view that resolves match-center data as a single payload
- no server-side search RPC for teams/competitions with ranking

## What Should Move Where

### Move to database tables

- launch market catalog, country metadata, dial-code presets, region labels, default focus tags
- mobile runtime feature flags and rollout rules
- team aliases and search synonyms
- event/challenge ranking weights if they need operator control
- notification templates and campaign targeting defaults
- competition-team membership
- global challenge participation and settlement tables

### Move to database functions / RPCs

- `resolve_app_runtime_config(p_user_id, p_country_code, p_platform)`
- `get_home_feed(p_user_id, p_region, p_country_code)`
- `search_teams(p_query, p_region, p_limit)`
- `search_competitions(p_query, p_region, p_limit)`
- `get_event_hub(p_event_tag, p_user_id)`
- `get_match_center(p_match_id, p_user_id)`
- `join_global_challenge(...)`
- `settle_global_challenge(...)`
- `dispatch_match_alerts(p_match_id, p_event_type)`

### Move to Edge Functions

- actual dispatch of kickoff/goal/result alerts from `match_alert_subscriptions`
- scheduled recomputation/refresh of curated home feed caches if needed
- campaign send orchestration where push, in-app, and external providers need fan-out
- optional search index refresh if a denormalized search table is introduced

### Move to config / feature tables

- everything currently under `AppConfig.enable*`
- market launch moment definitions
- market focus-tag defaults
- phone preset coverage by country
- FET peg or valuation inputs if governance ever needs operator control

## Recommended Missing Tables

- `public.markets`: market code, region, launch status, default currency, default language, default focus tags, rollout status
- `public.country_directory`: country code, market code, currency code, dial code, phone hint, min digits, region
- `public.mobile_feature_flags`: key, default state, platform, audience regions, audience countries, rollout percentage, dependencies, config json
- `public.team_aliases`: team_id, alias, locale, weight
- `public.team_competitions`: team_id, competition_id, season, is_primary
- `public.global_challenge_entries`: challenge_id, user_id, entry state, picks, score, payout, settled_at
- `public.global_challenge_settlements`: challenge_id, run_id, totals, winner_count, payout_summary
- `public.notification_templates`: type, title template, body template, default data contract, locale
- `public.edge_job_runs`: job_name, trigger_source, status, started_at, finished_at, payload, result_summary, error_text

## Recommended Missing Functions

- `public.resolve_runtime_flags(...)`
- `public.resolve_market_defaults(...)`
- `public.search_teams(...)`
- `public.search_competitions(...)`
- `public.get_home_feed(...)`
- `public.get_event_hub(...)`
- `public.get_match_center(...)`
- `public.join_global_challenge(...)`
- `public.settle_global_challenge(...)`
- `public.dispatch_match_alerts(...)`
- `public.mark_notifications_read_batch(...)`
- `public.register_device_token(...)`

## Recommended Missing Policies and Security Controls

- add caller validation to `public.merge_anonymous_to_authenticated` so only the current authenticated user can upgrade their own anonymous profile
- add missing FK constraints on user ownership columns noted above
- create a user-app readable config surface through a dedicated view or RPC, not by exposing `admin_feature_flags` directly
- explicitly review grants/RLS posture for internal runtime tables such as `match_sync_state`, `match_sync_request_log`, `rate_limits`, and `otp_verifications`
- ensure any future runtime config views expose only resolved flags/config, not raw admin metadata

## Recommended Indexes and Scalability Optimizations

- add GIN indexes if array columns remain temporarily on `teams.competition_ids`, `global_challenges.match_ids`, `user_market_preferences.selected_regions`, and `focus_event_tags`
- prefer replacing array lookup patterns with normalized join tables rather than doubling down on array indexing
- add text search/trigram indexes if search remains in Postgres for teams and competitions
- add indexes for `featured_events (audience_regions, is_active, priority_score)` and `global_challenges (audience_regions, status, priority_score)` if array-based audience filtering remains
- consider partial indexes for unread notification counts and active device tokens by platform
- replace full-table `.select()` reads in Flutter because `api.max_rows = 1000` will become a hard cap as tables grow

## Final Scalable Supabase-First Target Architecture

The target architecture should make the app a thin client over resolved backend state:

- raw domain tables remain authoritative for sports, profiles, wallets, challenges, community, rewards, notifications
- operator-managed runtime config lives in dedicated config tables, not in app constants
- client reads mostly come from views/RPCs that already apply market, feature, and ranking logic
- mutation-heavy or privileged flows stay in RPCs and Edge Functions
- Realtime is used for live match events, feed messages, unread notification counts, and possibly match state changes
- background Edge Functions handle ingestion, settlement, campaign fan-out, and alert delivery

Concretely, the home screen should not join and rank events in Flutter. It should call one backend composition RPC. The onboarding flow should not ship its own team catalog. It should query a backend search surface seeded from `teams`, `team_aliases`, and popularity metadata. Match alerts should not stop at a subscription row. They should be delivered by a dispatcher driven from match state changes and live events.

## Prioritized Action Plan

P0:

- lock down `merge_anonymous_to_authenticated`
- fix missing `supabase/seed.sql` or disable seeding in local config
- add missing ownership FKs
- design a user-readable runtime config surface and stop treating `admin_feature_flags` as admin-only operational metadata

P1:

- replace `teams.competition_ids` with a normalized join table
- replace `global_challenges.match_ids` with normalized challenge-match and challenge-entry tables
- move onboarding team search, region defaults, and phone presets into backend tables
- introduce backend composition RPCs for home feed and event hub

P2:

- shift high-frequency polling surfaces to Realtime or server-composed read models
- wire `match_alert_subscriptions` into actual delivery logic
- formalize notification templates and campaign dispatch primitives
- review whether FET peg config should remain hardcoded governance or move to an operator-controlled config object

## Bottom Line

FANZONE is already backend-capable, but not yet backend-governed. The schema and functions are broad enough to support a serious product, yet too many operator decisions and ranking rules still live in Flutter. The next iteration should focus less on adding more tables and more on making the existing platform the single source of runtime truth.
