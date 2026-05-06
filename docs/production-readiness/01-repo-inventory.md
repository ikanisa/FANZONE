# Production Readiness Repo Inventory

Audit date: 2026-05-06

## Repository State

- Current branch: `main`
- Latest commit at audit start: `e21b2c2 chore(repo): config, docs, env examples, QA reports, remaining tests`
- Worktree state at audit start/end: dirty. Several Flutter files and untracked `assets/data/`/temporary screenshots were already present and were not reverted.
- No `AGENTS.md` file was found in the repo.

## Top-Level Boundaries

- Flutter mobile app: `lib/`, `test/`, `integration_test/`, `android/`, `ios/`, `pubspec.yaml`.
- Web/admin apps:
  - `apps/admin`: React/Vite admin PWA.
  - `apps/venue-portal`: React/Vite venue portal.
  - `apps/website`: React/Vite public website.
  - `apps/tv-display`: React/Vite display app.
  - `packages/core`: shared web package.
- Supabase backend: `supabase/config.toml`, `supabase/migrations`, `supabase/functions`, `supabase/tests`, `supabase/seed.sql`.
- Release and operations tooling: `tool/`, `scripts/`, `.github/workflows/`, `docs/`.

## Existing Architecture

- Flutter uses feature-oriented modules under `lib/features`, shared UI/design-system code under `lib/core` and `lib/widgets`, and repository/provider style access around Supabase-backed domains.
- Supabase is the backend security boundary. Docs explicitly require RLS/server-side authorization and forbid service-role keys in clients.
- Supabase Edge Functions use shared helpers under `supabase/functions/_shared`, Deno checks/tests, and service-role access where server-only behavior is required.
- Web apps are separate Vite workspaces with their own `src`, `public`, build configs, and `_headers` deployment metadata.
- Release scripts in `tool/` cover Flutter release env resolution, Android/iOS builds, Supabase probes, Cloudflare Pages deploys, and SQL audits.

## Package Managers And Runtime Versions

Validated local tool versions:

- Flutter `3.38.9`
- Dart `3.10.8`
- Node `v22.22.2`
- npm `11.8.0`
- Deno `2.7.5`
- Supabase CLI `2.90.0`

Package management:

- Flutter/Dart: `pubspec.yaml` and `pubspec.lock`.
- Web workspaces: root npm workspace with package files under `apps/*` and `packages/core`.
- Scripts workspace: `scripts/package.json` and lockfile.
- Supabase functions: Deno imports and Supabase CLI config.

## Commands Discovered

Flutter:

- `flutter pub get`
- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- `flutter test --coverage`
- `flutter build apk --debug`
- Release helpers in `tool/build_android_release_from_env.sh`, `tool/build_android_aab_from_env.sh`, and `tool/build_ios_release_from_env.sh`.

Web:

- `npm run typecheck --workspaces --if-present`
- `npm run lint --workspaces --if-present`
- `npm run test --workspaces --if-present`
- `npm run build --workspaces --if-present`
- Per-app Vite build/test/typecheck scripts.

Supabase/Deno:

- `supabase db lint --local --schema public --fail-on error`
- `deno fmt --check supabase/functions`
- `deno check ...`
- `deno test --allow-env supabase/functions`
- SQL audit helpers in `tool/supabase_rls_audit.sh`, `tool/supabase_fet_supply_smoke.sh`, and related release probe scripts.

Security/supply chain:

- `.github/workflows/secret-regex-scan.yml`
- `npm audit --audit-level=moderate`
- Optional `gitleaks`/`trufflehog` were checked but are not installed locally.

## Environment Strategy

- Env examples are tracked and sanitized.
- Production env JSON files, signing files, Firebase files, and local secrets are ignored and expected to be supplied from secure local storage or CI/hosting secrets.
- `.env` exists locally but is ignored.
- `android/key.properties` exists locally and is ignored; values were not printed or copied.
- Docs identify prior Supabase credential disclosure as a release blocker requiring rotation.

## Deployment Targets

- Flutter Android/iOS release via local/CI signing environment.
- React/Vite apps deploy as static PWAs, with Cloudflare Pages tooling present.
- Supabase schema and functions deploy through versioned migrations, Edge Function deploys, and release probe scripts.

## CI/CD Summary

- `.github/workflows/ci.yml` contains Flutter, web, Supabase, dependency audit, and secret-regex checks and now runs on pull requests, pushes to `main`, and manual dispatch.
- `.github/workflows/secret-regex-scan.yml` also runs on pull requests, pushes to `main`, and manual dispatch.
- Deployment workflows remain manual to preserve the local/free-account release model.
- Repository branch protection still needs to require the validation workflows before production release.

## Areas To Preserve

- Existing product rule that payments remain off-platform/manual confirmation.
- Supabase/RLS as the authorization boundary.
- Service-role key usage restricted to trusted backend/Edge Function contexts.
- Existing feature-oriented Flutter structure and workspace boundaries.
- Existing ignored-secret strategy for signing files and production environment files.

## Unclear Or Risky Areas

- Production/staging Supabase project state cannot be proven from static files alone.
- Dashboard-only database changes, if any, cannot be detected without comparing a live DB dump.
- Admin authorization appears distributed across frontend, RLS, and functions; object-level enforcement needs live policy tests.
- Web session storage is still high-risk for admin/venue surfaces until XSS/session hardening is reviewed end to end.
- Observability and incident-response readiness are not complete enough for a high-confidence launch.
