# Supabase Critical Gap Analysis

Date: 2026-04-18

> Status note on 2026-04-18: this document is a point-in-time gap snapshot.
> Later repo migrations already close part of the critical path described here, including service-role-aware admin helpers in `20260418170000_fullstack_gap_closure.sql`, broader admin data-plane alignment in `20260418143000_admin_console_data_plane.sql`, and internal push-notify secret propagation in `20260418213100_internal_push_notify_secret_alignment.sql`.
> Re-validate against the latest migrations and deployed project state before treating any single finding below as current.

## Scope

This review covered:

- Flutter client usage under `lib/`
- Admin console usage under `admin/src/`
- Repo-local Supabase migrations under `supabase/migrations/`
- Repo-local edge functions under `supabase/functions/`
- Repo-local validation scripts under `tool/` and `supabase/tests/`

I also ran the repo's public release probe against the linked Supabase project. That probe passed, which means several objects missing from repo-local executable migrations do exist in the live linked project. The core problem is repo-to-project drift: the repo cannot reliably recreate the backend it assumes.

## Executive Summary

The Supabase layer is not self-contained. Eleven core tables/views used by the app and admin console are only documented or assumed, not provisioned by executable migrations in this repo. The linked project appears to contain them already, but a fresh environment built from this repo would not.

There are also multiple critical runtime and security gaps:

- the scheduled `auto-settle` edge function now calls admin-gated RPCs with a service-role client that has no `auth.uid()`, so settlement automation will fail;
- `push-notify` accepts any request whose `Authorization` header merely contains the word `Bearer`, which effectively disables authentication;
- `gemini-team-news` has no authorization check at all and writes to the database with a service-role client;
- several client-side writes and admin reads are blocked by current RLS or schema shape.

## Inventory Summary

### Objects referenced by code but not created by executable migrations in this repo

- `challenge_feed`
- `competition_standings`
- `fan_clubs`
- `fet_wallet_transactions`
- `fet_wallets`
- `prediction_challenge_entries`
- `prediction_challenges`
- `profiles`
- `public_leaderboard`
- `user_followed_competitions`
- `user_followed_teams`

### Additional backend dependencies referenced but not provisioned in this repo

- `public.resolve_auth_user_phone(...)`
- `public.app_preferences`
- `public.prediction_challenge_settlements`

## Critical Findings

### 1. Bootstrap drift: core backend objects are missing from executable migrations

Severity: Critical

Evidence:

- [supabase/migrations/001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:2) explicitly says the file is reference-only and must not be run.
- The same reference file documents `fet_wallets`, `fet_wallet_transactions`, `prediction_challenges`, `prediction_challenge_entries`, `challenge_feed`, `public_leaderboard`, `fan_clubs`, `user_followed_teams`, and `user_followed_competitions` at [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:12), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:19), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:33), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:54), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:66), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:73), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:79), [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:88), and [001_engagement_tables.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/001_engagement_tables.sql:94).
- App and tooling still depend on those objects:
  - [lib/services/pool_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/pool_service.dart:20) reads `challenge_feed`
  - [lib/services/leaderboard_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/leaderboard_service.dart:17) reads `public_leaderboard`
  - [lib/services/wallet_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/wallet_service.dart:225) reads `fan_clubs`
  - [lib/providers/standings_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/standings_provider.dart:33) reads `competition_standings`
  - [tool/supabase_release_probe.sh](/Volumes/PRO-G40/FANZONE/tool/supabase_release_probe.sh:26) through [tool/supabase_release_probe.sh](/Volumes/PRO-G40/FANZONE/tool/supabase_release_probe.sh:30) probe `public_leaderboard`, `fan_clubs`, `fet_wallets`, and `fet_wallet_transactions`

Impact:

- A fresh Supabase project cannot be provisioned from this repo alone.
- The live project can drift from repo state without any migration proving what exists.
- Every later migration that assumes these tables/views exist is unsafe on a clean install.

Recommendation:

- Convert the reference schema into executable baseline migrations or import the missing baseline from the real infra repo.
- Make repo-local migrations authoritative for every object the app, admin app, and scripts depend on.

### 2. `profiles` is a hard dependency but is not provisioned or policy-managed in this repo

Severity: Critical

Evidence:

- App code writes and reads `profiles` directly:
  - [lib/features/onboarding/providers/onboarding_service.dart](/Volumes/PRO-G40/FANZONE/lib/features/onboarding/providers/onboarding_service.dart:301)
  - [lib/features/auth/screens/splash_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/auth/screens/splash_screen.dart:68)
  - [lib/providers/currency_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/currency_provider.dart:100)
- Repo-local migrations only alter and attach triggers to `public.profiles`; they never create it:
  - [supabase/migrations/016_onboarding_currency_fanid.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/016_onboarding_currency_fanid.sql:278)
  - [supabase/migrations/016_onboarding_currency_fanid.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/016_onboarding_currency_fanid.sql:354)
- `ensure_user_foundation` also inserts into `public.profiles` and `public.app_preferences`, but neither object is created in this repo:
  - [supabase/migrations/002b_live_backend_hotfixes.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/002b_live_backend_hotfixes.sql:18)
  - [supabase/migrations/002b_live_backend_hotfixes.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/002b_live_backend_hotfixes.sql:24)

Impact:

- Fresh bootstrap cannot support onboarding, fan ID assignment, or currency inference.
- Policy posture for `profiles` is undefined in the repo. If the live table has weak or missing RLS, the repo gives no warning.

Recommendation:

- Add executable DDL for `profiles` and `app_preferences`.
- Add explicit RLS and grants for all app-required `profiles` reads and writes.

### 3. Scheduled settlement is broken: `auto-settle` edge function calls admin-only RPCs with a service-role client

Severity: Critical

Evidence:

- `auto-settle` creates a service-role client and invokes admin-gated RPCs:
  - [supabase/functions/auto-settle/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/auto-settle/index.ts:63)
  - [supabase/functions/auto-settle/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/auto-settle/index.ts:124)
  - [supabase/functions/auto-settle/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/auto-settle/index.ts:143)
- The RPCs now require `auth.uid()` to resolve to an active admin:
  - [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:65)
  - [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:73)
  - [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:1016)
  - [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:1055)
- Supabase’s own docs state that API keys like `service_role` do not carry a `sub` claim, while `auth.uid()` depends on user identity, and that service-role clients bypass RLS rather than impersonating an end user:
  - https://supabase.com/docs/guides/troubleshooting/auth-error-401-invalid-claim-missing-sub--AFwMR
  - https://supabase.com/docs/guides/troubleshooting/why-is-my-service-role-key-client-getting-rls-errors-or-not-returning-data-7_1K9z

Impact:

- Automatic pool settlement, prediction-slip settlement, and daily-challenge settlement will fail in the scheduled edge path.
- The repo currently has no alternate machine identity path for those jobs.

Recommendation:

- Split these RPCs into operator-facing and machine-facing entry points, or add an explicit service-role/secret-based machine authorization branch that does not depend on `auth.uid()`.

### 4. `push-notify` is effectively unauthenticated

Severity: Critical

Evidence:

- `push-notify` accepts the request if the header contains the literal substring `Bearer`, regardless of token value:
  - [supabase/functions/push-notify/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/push-notify/index.ts:172)
  - [supabase/functions/push-notify/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/push-notify/index.ts:175)
- The database helper that reaches this edge function is `SECURITY DEFINER`:
  - [supabase/migrations/20260418040000_push_notification_triggers.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418040000_push_notification_triggers.sql:21)
- That helper is also explicitly granted to every authenticated user:
  - [supabase/migrations/20260418040000_push_notification_triggers.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418040000_push_notification_triggers.sql:220)

Impact:

- Any caller that can hit the edge endpoint with `Authorization: Bearer anything` can trigger outbound notifications.
- Any authenticated database user can invoke `send_push_to_user(...)` directly and target arbitrary recipients.
- This is both a spam vector and a cost vector.

Recommendation:

- Require either a verified service-role JWT or a dedicated shared secret header.
- Remove `GRANT EXECUTE ... TO authenticated` from `send_push_to_user`, `notify_pool_settled`, and `notify_daily_challenge_winners`, then expose only narrower admin/system wrappers.

### 5. `gemini-team-news` has no authorization check and no publish path

Severity: Critical

Evidence:

- The handler parses input and immediately creates a service-role client; there is no authorization gate between request receipt and database writes:
  - [supabase/functions/gemini-team-news/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/gemini-team-news/index.ts:281)
  - [supabase/functions/gemini-team-news/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/gemini-team-news/index.ts:320)
- It writes generated articles as `draft`:
  - [supabase/functions/gemini-team-news/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/gemini-team-news/index.ts:397)
  - [supabase/functions/gemini-team-news/index.ts](/Volumes/PRO-G40/FANZONE/supabase/functions/gemini-team-news/index.ts:410)
- The mobile app only reads `status = 'published'`:
  - [lib/services/team_community_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/team_community_service.dart:251)
  - [lib/services/team_community_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/team_community_service.dart:277)
- Repo search found no admin console workflow for reviewing or publishing `team_news`, and no scheduler or caller for `gemini-team-news`.

Impact:

- Anyone who can reach the edge function can spend Gemini quota and create draft news rows.
- Even valid generated articles will not surface in the app because there is no publish workflow in this repo.

Recommendation:

- Add the same kind of secret/service-role authorization gate used by the other edge functions.
- Add an admin review/publish workflow for `team_news`, or store directly as published only if that is acceptable.
- Add a scheduler or explicit trigger path if automatic team-news refresh is a requirement.

## High Findings

### 6. Admin fixture updates are blocked by RLS

Severity: High

Evidence:

- The admin app uses the anon-key client and updates `matches` directly:
  - [admin/src/lib/supabase.ts](/Volumes/PRO-G40/FANZONE/admin/src/lib/supabase.ts:5)
  - [admin/src/features/fixtures/useFixtures.ts](/Volumes/PRO-G40/FANZONE/admin/src/features/fixtures/useFixtures.ts:45)
- The repo only defines public `SELECT` on `matches`:
  - [supabase/migrations/004_sports_foundation.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/004_sports_foundation.sql:95)
  - [supabase/migrations/004_sports_foundation.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/004_sports_foundation.sql:105)

Impact:

- Admin “record result” writes will fail unless the live project has out-of-repo policies.

Recommendation:

- Add an admin-only `UPDATE` policy on `matches`, or switch the admin UI to an audited RPC.

### 7. Admin competition updates are blocked by RLS and target a column not created in the repo

Severity: High

Evidence:

- The admin app updates `competitions.is_featured` directly:
  - [admin/src/features/competitions/useCompetitions.ts](/Volumes/PRO-G40/FANZONE/admin/src/features/competitions/useCompetitions.ts:45)
- The repo-local `competitions` table definition has no `is_featured` column:
  - [supabase/migrations/004_sports_foundation.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/004_sports_foundation.sql:10)
- The only local policy on `competitions` is public `SELECT`:
  - [supabase/migrations/004_sports_foundation.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/004_sports_foundation.sql:103)

Impact:

- The admin “feature competition” action is broken on repo-local schema.
- This is both a schema drift issue and a policy gap.

Recommendation:

- Either add `is_featured` plus admin write policy, or remove the admin toggle until backed by real schema.

### 8. Notification read-state writes are blocked by RLS

Severity: High

Evidence:

- The mobile app updates `notification_log.read_at` directly:
  - [lib/services/notification_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/notification_service.dart:116)
  - [lib/services/notification_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/notification_service.dart:133)
- The repo-local policy only permits `SELECT`:
  - [supabase/migrations/20260418031500_fullstack_hardening.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418031500_fullstack_hardening.sql:1189)

Impact:

- Users can read notifications but cannot mark them as read through the current policy set.

Recommendation:

- Add an authenticated `UPDATE` policy constrained to `auth.uid() = user_id`, or move the read-state mutation into an RPC.

### 9. Admin challenge-entry visibility is blocked by RLS

Severity: High

Evidence:

- The admin challenge page reads `prediction_challenge_entries` directly:
  - [admin/src/features/challenges/useChallenges.ts](/Volumes/PRO-G40/FANZONE/admin/src/features/challenges/useChallenges.ts:48)
- The repo-local policy only allows users to read their own entries:
  - [supabase/migrations/20260418031500_fullstack_hardening.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418031500_fullstack_hardening.sql:1098)
  - [supabase/migrations/20260418031500_fullstack_hardening.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418031500_fullstack_hardening.sql:1105)

Impact:

- Admin users cannot inspect full pool participation unless the live project has extra out-of-repo policies or the view is empty by chance.

Recommendation:

- Add an admin-only `SELECT` policy or expose an admin view/RPC.

### 10. Admin token analytics read from a user-scoped ledger table

Severity: High

Evidence:

- The admin token dashboard directly queries `fet_wallet_transactions`:
  - [admin/src/features/tokens/useTokenOps.ts](/Volumes/PRO-G40/FANZONE/admin/src/features/tokens/useTokenOps.ts:70)
- The repo-local policy allows authenticated users to read only their own transactions:
  - [supabase/migrations/20260418031500_fullstack_hardening.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418031500_fullstack_hardening.sql:1071)

Impact:

- `totalRedeemed` and `totalTransferred7d` will be wrong for admins unless the live project has separate overrides.

Recommendation:

- Replace these direct reads with `fet_transactions_admin`, an admin-only aggregate RPC, or a dedicated analytics function.

## Medium Findings

### 11. `competition_standings` is an out-of-band dependency

Severity: Medium

Evidence:

- The app queries `competition_standings`:
  - [lib/providers/standings_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/standings_provider.dart:33)
- The migration explicitly says the view is “already defined as a remote view in the db”:
  - [supabase/migrations/004_sports_foundation.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/004_sports_foundation.sql:77)

Impact:

- New environments cannot reproduce standings without manual out-of-band work.

Recommendation:

- Add executable DDL for `competition_standings` or document the external migration source and make it part of bootstrap.

### 12. Stale migration references still target objects not provisioned in this repo

Severity: Medium

Evidence:

- `003_backend_audit_fixes.sql` creates policy on `prediction_challenge_settlements`, which is not created anywhere in repo-local executable migrations:
  - [supabase/migrations/003_backend_audit_fixes.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/003_backend_audit_fixes.sql:21)

Impact:

- Clean migration runs are brittle and can fail depending on actual database state.

Recommendation:

- Remove or guard stale policy DDL against absent tables, or add the missing table migration.

### 13. Currency-rate refresh has no repo-local invocation path

Severity: Medium

Evidence:

- The app depends on `currency_rates`:
  - [lib/providers/currency_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/currency_provider.dart:16)
- The edge function exists, but repo search found no cron, admin trigger, or caller for `gemini-currency-rates`.

Impact:

- Rates can go stale indefinitely even though the read path is live.

Recommendation:

- Add a scheduler or admin-triggered refresh flow for `gemini-currency-rates`.

## Live Project vs Repo

The linked live project appears to contain several baseline objects that this repo does not create. The repo’s own public probe succeeded, and ad-hoc REST checks returned `200` for:

- `challenge_feed`
- `public_leaderboard`
- `fan_clubs`
- `competition_standings`
- `fet_wallets`
- `fet_wallet_transactions`
- `prediction_challenges`
- `prediction_challenge_entries`
- `profiles`
- `user_followed_teams`
- `user_followed_competitions`

That reduces immediate production blast radius, but it confirms the core maintainability problem: production behavior depends on out-of-repo state.

## Recommended Remediation Order

1. Lock down `push-notify` and `gemini-team-news`.
2. Fix machine authorization for automated settlement RPCs.
3. Make the missing baseline schema executable in-repo.
4. Add/repair admin write and read policies for `matches`, `competitions`, `prediction_challenge_entries`, `notification_log`, and admin analytics sources.
5. Add explicit invocation/publish workflows for `gemini-currency-rates` and `gemini-team-news`.
