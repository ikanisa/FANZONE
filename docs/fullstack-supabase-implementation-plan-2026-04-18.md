# FANZONE Supabase Fullstack Implementation Plan

Date: 2026-04-18

## Goal

Make the Supabase layer reproducible, secure, and operable from this repo alone, without depending on undocumented live-project state.

Success means:

- a clean project can replay repo migrations and expose every table, view, function, and policy the app/admin depend on;
- browser clients use only `anon` + user JWTs;
- machine jobs use explicit machine authorization, not `auth.uid()`-based admin gates;
- admin flows work through admin-aware RLS and admin RPCs;
- release validation catches schema drift, broken policies, and dead edge-function paths before production.

## Recommended Architecture

Use one privilege model across the stack:

- Flutter app and admin app stay browser clients with `anon` keys plus authenticated user JWTs.
- Admin authorization is derived from `public.admin_users` and helper functions such as `public.is_active_admin_operator()` and `public.require_active_admin_user()`.
- `service_role` is used only inside Edge Functions and internal machine jobs.
- Scheduled and machine-triggered jobs authenticate with explicit shared secrets or DB-internal execution paths.
- Repo migrations become the single source of truth for schema, RLS, grants, cron setup, and required secrets.

Do not put a `service_role` key in the browser admin app. The current admin app in [admin/src/lib/supabase.ts](/Volumes/PRO-G40/FANZONE/admin/src/lib/supabase.ts:1) is already built for browser auth, so the backend should be aligned to that model instead of bypassing it.

## Delivery Sequence

### Phase 0: Freeze and Extract Live Truth

Target: 0.5 to 1 day

Work:

- Export the live DDL for every object currently missing from repo-local executable migrations.
- Capture live definitions for:
  - `challenge_feed`
  - `competition_standings`
  - `fan_clubs`
  - `fet_wallets`
  - `fet_wallet_transactions`
  - `prediction_challenges`
  - `prediction_challenge_entries`
  - `profiles`
  - `public_leaderboard`
  - `user_followed_teams`
  - `user_followed_competitions`
  - `public.resolve_auth_user_phone(...)`
  - `public.app_preferences`
- Capture live grants, RLS policies, indexes, constraints, cron jobs, and vault/secret dependencies for:
  - `auto-settle`
  - `push-notify`
  - `gemini-team-news`
  - `gemini-currency-rates`

Deliverables:

- A schema manifest checked into `docs/` or `supabase/` listing required objects and their owning migration.
- A mapping from code reference to backend object and authoritative migration source.

Acceptance:

- There is no remaining “assumed to exist in production” object without a concrete repo plan to create it.

### Phase 1: Make Bootstrap Authoritative

Target: 2 to 3 days

Work:

- Add one or more new additive migrations that backfill all missing baseline objects with `IF NOT EXISTS` / guarded DDL.
- Do not rewrite historical migrations already likely applied in production.
- Convert the current reference-only schema in [supabase/migrations/001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:2) into executable, additive backfill migrations.
- Add executable definitions for:
  - `profiles`
  - `app_preferences`
  - `resolve_auth_user_phone`
  - `challenge_feed`
  - `public_leaderboard`
  - `fan_clubs`
  - `fet_wallets`
  - `fet_wallet_transactions`
  - `prediction_challenges`
  - `prediction_challenge_entries`
  - `user_followed_teams`
  - `user_followed_competitions`
  - `competition_standings` or its authoritative upstream dependency
- Remove or guard stale DDL that targets absent objects, including `prediction_challenge_settlements` in [supabase/migrations/003_backend_audit_fixes.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/003_backend_audit_fixes.sql:21).

Recommended migration split:

- `*_authoritative_schema_backfill.sql`
- `*_profiles_and_preferences_foundation.sql`
- `*_competition_standings_bootstrap.sql`
- `*_stale_policy_cleanup.sql`

Acceptance:

- A clean migration replay succeeds.
- The required object inventory in the gap report exists after replay.
- `tool/supabase_release_probe.sh` passes on a freshly bootstrapped environment.

### Phase 2: Repair Machine Auth and Edge-Function Trust Boundaries

Target: 1.5 to 2 days

Work:

- Standardize machine auth across edge functions.
- Reuse the secreted machine-dispatch pattern already used by match-sync runtime in [supabase/migrations/20260418103000_match_sync_async_runtime.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418103000_match_sync_async_runtime.sql:245) instead of ad hoc header checks.

`auto-settle`:

- Stop using admin-gated RPCs that depend on `auth.uid()` from a `service_role` client.
- Introduce machine-safe settlement functions such as:
  - `public.run_auto_settlement_cycle(...)`
  - `public.run_prediction_slip_settlement(...)`
  - `public.run_daily_challenge_settlement(...)`
- Make those functions `SECURITY DEFINER` with explicit internal authorization or invoke them directly from `pg_cron`.
- Keep the Edge Function as an orchestrator/fallback entrypoint only.
- Fix the match-score null check bug in [supabase/functions/auto-settle/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/auto-settle/index.ts:96).

`push-notify`:

- Replace the current substring auth check in [supabase/functions/push-notify/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/push-notify/index.ts:155) with exact validation:
  - either verified JWTs for user/admin initiated calls;
  - or a dedicated machine secret for internal job calls.
- Do not treat any header containing `Bearer` as authorized.
- Add structured request logging and reject unknown callers.

`gemini-team-news`:

- Require either:
  - an authenticated active admin user for manual runs; or
  - a dedicated machine secret for scheduled runs.
- Split draft generation from publish.
- Add an explicit admin publish RPC or table workflow.

`gemini-currency-rates`:

- Add the same machine-auth model.
- Add a scheduler or admin-triggered refresh path.

Acceptance:

- Unauthorized requests to `push-notify`, `gemini-team-news`, and `auto-settle` return `401/403`.
- Scheduled settlement succeeds without depending on `auth.uid()`.
- GitHub fallback cron in [.github/workflows/cron-settle.yml](/Volumes/PRO-G40/FANZONE/.github/workflows/cron-settle.yml:1) still works with the new secret model.

### Phase 3: Align Admin Data Plane to Browser Auth

Target: 2 days

Work:

- Keep the admin app on browser auth and extend the existing admin policy model from [supabase/migrations/20260418143000_admin_console_data_plane.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418143000_admin_console_data_plane.sql:12).
- For domain tables that the admin app edits directly, add admin-aware RLS policies using:
  - `public.is_active_admin_operator(auth.uid())`
  - `public.is_admin_manager(auth.uid())`
- For higher-risk operations, expose admin RPCs guarded by `public.require_active_admin_user()`.

Concrete work items:

- Add admin write policies or admin RPCs for `matches`.
- Add admin write policies or admin RPCs for `competitions`.
- Add admin read policy or admin view/RPC for `prediction_challenge_entries`.
- Add admin-safe access pattern for `fet_wallet_transactions`.
- Add admin-safe read/update path for `notification_log`.
- Ensure every admin mutation writes to `admin_audit_logs`.

Schema cleanup:

- Add `competitions.is_featured` if the UI will keep using it, or remove the field from [admin/src/features/competitions/useCompetitions.ts](/Volumes/PRO-G40/FANZONE/admin/src/features/competitions/useCompetitions.ts:45).

Recommended pattern:

- Direct browser-table writes for low-risk editorial objects.
- RPCs for cross-user, monetary, settlement, and moderation operations.

Acceptance:

- Admin sign-in via [admin/src/hooks/useAuth.tsx](/Volumes/PRO-G40/FANZONE/admin/src/hooks/useAuth.tsx:1) can read `admin_users` and perform intended actions without service-role exposure.
- Admin fixture edits, competition edits, analytics, and campaign send flows work in a real authenticated session.

### Phase 4: Fix App-Side Write Paths and Contracts

Target: 1 day

Work:

- Ensure mobile app writes are consistent with the final RLS model.
- Add explicit own-row policy coverage for `notification_log.read_at`.
- Confirm `profiles` upsert path in [lib/features/onboarding/providers/onboarding_service.dart](/Volumes/PRO-G40/FANZONE/lib/features/onboarding/providers/onboarding_service.dart:301) is supported by final schema and policy.
- Confirm splash/profile reads in [lib/features/auth/screens/splash_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/auth/screens/splash_screen.dart:68) are supported.
- Add stale-data handling for `currency_rates` if refresh jobs are delayed.
- Generate and check in fresh typed contracts for the admin app and Flutter app if you rely on generated types.

Acceptance:

- Onboarding, wallet, favorites, standings, and notifications work against a fresh project with no manual DB fixes.

### Phase 5: Tests, Probes, and CI Release Gates

Target: 1.5 to 2 days

Work:

- Expand SQL verification under `supabase/tests/`.
- Add:
  - `bootstrap_required_objects.sql`
  - `admin_data_plane_verification.sql`
  - `edge_job_auth_verification.sql`
  - `profiles_preferences_verification.sql`
- Extend existing tests:
  - [supabase/tests/rls_verification.sql](/Volumes/PRO-G40/FANZONE/supabase/tests/rls_verification.sql)
  - [supabase/tests/rls_hardening_audit.sql](/Volumes/PRO-G40/FANZONE/supabase/tests/rls_hardening_audit.sql)
  - [supabase/tests/fet_supply_cap_smoke.sql](/Volumes/PRO-G40/FANZONE/supabase/tests/fet_supply_cap_smoke.sql)

Tooling:

- Extend [tool/supabase_release_probe.sh](/Volumes/PRO-G40/FANZONE/tool/supabase_release_probe.sh) to probe all required public objects.
- Add `tool/supabase_bootstrap_smoke.sh` to validate clean-project replay.
- Add `tool/supabase_edge_job_smoke.sh` to validate machine-authenticated edge flows.

CI:

- Add a disposable-project or local replay job that runs all migrations and SQL verification.
- Keep the GitHub cron fallback for settlement and add explicit failure alerting.
- Fail CI when required objects are missing or when policy checks regress.

Acceptance:

- Schema replay, RLS verification, and edge auth smoke all run automatically before release.

### Phase 6: Staging Rollout and Production Cutover

Target: 1 day

Work:

- Create or refresh a staging Supabase project from repo migrations only.
- Deploy migrations first, then Edge Functions, then admin app, then mobile app.
- Seed at least one real admin user in `admin_users`.
- Configure and verify secrets:
  - `CRON_SECRET`
  - machine secret for internal edge calls if separate
  - `SUPABASE_SERVICE_ROLE_KEY`
  - FCM service account secret
  - any Gemini/news/rates secrets
- Validate:
  - onboarding
  - wallet reads/writes
  - favorites
  - standings
  - admin fixture edit
  - admin competition edit
  - campaign send
  - auto-settlement
  - push notification delivery

Rollback strategy:

- Edge Functions can be rolled back independently of schema.
- Cron jobs can be disabled independently.
- Use additive migrations only; do not perform destructive schema drops in the first remediation pass.
- Feature-flag new admin flows if needed.

Acceptance:

- Staging passes the full smoke checklist.
- Production rollout requires no manual SQL hotfixes.

## PR Plan

### PR 1: Schema Authority

- Add authoritative backfill migrations for missing baseline objects.
- Add bootstrap verification tests.
- Remove or guard stale policy DDL.

### PR 2: Machine Jobs and Edge Security

- Refactor `auto-settle`.
- Lock down `push-notify`.
- Add machine-auth standard for `gemini-team-news` and `gemini-currency-rates`.
- Add edge auth smoke tests.

### PR 3: Admin Data Plane

- Extend admin RLS/RPC coverage to sports, notifications, and ledger reads.
- Align admin UI code to final schema and RPC usage.
- Add audit-log coverage.

### PR 4: App Contract and Release Gates

- Align Flutter write paths and stale-data handling.
- Expand release probe and CI checks.
- Add staging smoke documentation.

## Highest-Risk Items to Do First

1. Lock down `push-notify`.
2. Stop `auto-settle` from calling `auth.uid()`-gated admin RPCs through `service_role`.
3. Backfill the missing baseline schema into executable migrations.
4. Repair admin edits for `matches` and `competitions`.
5. Add explicit publish/invocation paths for `gemini-team-news` and `gemini-currency-rates`.

## Non-Negotiable Acceptance Criteria

- Fresh-project bootstrap works from repo only.
- No browser code has access to `service_role`.
- No machine path depends on `auth.uid()`.
- Every admin action is either RLS-authorized or routed through an admin RPC.
- Every privileged mutation is auditable.
- Release probes fail fast on missing tables, views, RPCs, policies, or edge-function auth regressions.
