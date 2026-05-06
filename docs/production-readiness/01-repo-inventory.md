# Production Readiness Repo Inventory

Audit date: 2026-05-06

## Repository State

- Current branch at audit start: `main`
- Latest commit at audit start: `c2fdd73 test: account for managed supabase defaults`
- Worktree at audit start: clean.
- Worktree after implementation: modified only by the documented production-readiness pass.
- No repo-level `AGENTS.md` was found outside dependencies.

## Application Boundaries

- Flutter mobile app:
  - `lib/` application code
  - `test/` unit/widget tests
  - `integration_test/` smoke/integration tests
  - `android/` and `ios/` native projects
  - `pubspec.yaml` and `pubspec.lock`
- Web/admin apps:
  - `apps/admin`: React/Vite admin PWA
  - `apps/website`: React/Vite public website
  - `apps/venue-portal`: React/Vite venue portal
  - `apps/tv-display`: React/Vite display surface
  - `packages/core`: shared TypeScript package
- Supabase backend:
  - `supabase/config.toml`
  - `supabase/migrations`
  - `supabase/functions`
  - `supabase/tests`
  - `supabase/seed.sql`
- Release, CI, and operations:
  - `.github/workflows`
  - `tool/`
  - `scripts/`
  - `docs/`
  - app-level `_headers`, manifests, and Wrangler configs

## Architecture Observed

- Flutter is feature-oriented, with reusable core services under `lib/core`, feature repositories/providers under `lib/features`, and Supabase initialization/config in shared app layers.
- Custom WhatsApp auth creates a Supabase client with an `accessToken` callback in `RuntimeAuthSessionManager`. Some repositories still need review for direct `client.auth.currentUser` usage during custom sessions.
- Web apps are independent Vite workspaces. Admin and venue use custom browser session helpers; website uses the standard Supabase browser client.
- Supabase Edge Functions share helpers under `supabase/functions/_shared` for auth, CORS, logging, errors, and Supabase clients.
- Postgres authorization is intended to be enforced through RLS, grants, and trusted Edge/RPC paths. This remains the main backend security boundary.
- Deployment tooling favors static Cloudflare Pages deployments for web apps and Supabase CLI/scripts for backend probes and jobs.

## Runtime And Tool Versions

Validated locally:

- Flutter `3.38.9`
- Dart `3.10.8`
- Node `v22.22.2`
- npm `11.8.0`
- Deno `2.7.5`
- Supabase CLI `2.90.0` (`2.98.2` available)
- Docker server `28.4.0`

Unavailable locally:

- `gitleaks`
- `trufflehog`

## Package Managers And Scripts

- Flutter/Dart: `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, Flutter build commands.
- npm workspaces: root `package.json` coordinates app/package scripts with per-app lockfiles where present.
- Web validation: `npm run typecheck --workspaces --if-present`, `npm run lint --workspaces --if-present`, `npm run test --workspaces --if-present`, `npm run build --workspaces --if-present`.
- Deno/Supabase validation: `deno fmt --check supabase/functions`, `deno check`, `deno test --allow-env supabase/functions`, `supabase db lint`.
- Release/security tooling: `tool/validate_release_env.sh`, `tool/validate_web_release_env.sh`, `tool/preflight_build_check.sh`, `tool/supabase_release_probe.sh`, `tool/supabase_rls_audit.sh`, `tool/run_supabase_cron_job.sh`, `.github/workflows/secret-regex-scan.yml`.

## Environment Strategy

- Tracked env examples are sanitized placeholders.
- `.env`, `.env.*`, production env JSON files, signing files, Firebase configs, and Supabase env files are ignored.
- Local ignored env files exist and were not printed.
- Supabase anon/publishable keys are treated as public only when RLS is correct; service-role and secret keys must remain server-side.
- Release docs still identify prior credential disclosure as a blocker requiring external rotation proof.

## Database And Supabase Inventory

- Migrations are versioned under `supabase/migrations`.
- RLS/grant audit SQL exists under `supabase/tests`.
- Edge Functions are TypeScript/Deno functions under `supabase/functions`.
- Local Supabase was not running during this audit, so migrations, grants, policies, advisors, and storage policies were not validated against a live local database.
- A new migration, `20260506130000_audit_helper_grant_hardening.sql`, revokes direct client execution of `sports_bar_write_audit(...)`.

## CI/CD Summary

- Main CI exists in `.github/workflows/ci.yml` and covers Flutter, web, Supabase/Deno, dependency audits, release probes, and secret regex checks where secrets are present.
- Secret regex scanning exists in `.github/workflows/secret-regex-scan.yml`.
- Cron workflows are manual-only fallbacks; docs defer production scheduling to Supabase/platform cron or local scheduled jobs.
- Web deploy workflows are manual and use Cloudflare secrets; repo-visible GitHub Environment gates are not yet configured in code.
- Branch protection and required checks cannot be proven from static repo files.

## What Must Be Preserved

- Existing product behavior and off-platform/manual payment rules.
- Supabase/RLS as the backend authorization layer.
- Service-role usage only in trusted server/Edge Function contexts.
- Feature-oriented Flutter boundaries and independent web workspace boundaries.
- Versioned migrations over dashboard-only schema changes.
- Ignored-secret strategy for local credentials, signing material, and production env files.

## Risky Or Unclear Areas

- External credential rotation cannot be proven from the repo.
- Live Supabase state may differ from migrations if dashboard changes exist.
- Privileged sessions still reside in client-readable storage on mobile/web.
- Admin role/permission granularity needs server-side enforcement beyond active-admin checks.
- Scheduled jobs, alerting, branch protection, deployment approvals, backups, and restore drills require provider-side verification.
