# Production Readiness Executive Summary

Audit date: 2026-05-06
Audit start branch/commit: `main` at `c2fdd73 test: account for managed supabase defaults`

Overall readiness: Amber
Go/no-go recommendation: No-go for production launch until credential rotation is proven, Cloudflare Pages BFF runtime variables are verified on the deployed admin/venue projects, and provider-side scheduler/deploy evidence is captured.

## Scope Reviewed

- Flutter mobile app: `lib/`, `test/`, `integration_test/`, `android/`, `ios/`, `tool/`, and release env examples.
- Web surfaces: `apps/admin`, `apps/website`, `apps/venue-portal`, `apps/tv-display`, and `packages/core`.
- Supabase backend: `supabase/config.toml`, migrations, Edge Functions, RLS/audit SQL, seeds, and release probes.
- CI/CD, release, and operations: `.github/workflows`, `tool/`, `scripts/`, `docs/`, env examples, and deployment metadata.

The repo already has meaningful production structure: Flutter is feature-oriented, web apps are split by surface, Supabase/RLS is documented as the backend authorization boundary, service-role usage is intended to stay in trusted functions, and Deno/web checks are available. The remaining launch risk is concentrated in human-held credentials, deployed Cloudflare runtime variable verification, and provider-side operational evidence.

## Safe Refactor Passes Completed

1. Request-scoped Edge CORS: `buildCorsHeaders` now accepts a `Request` and reflects only allowlisted request origins for browser calls while preserving existing explicit-origin behavior. The WhatsApp OTP and pool social-card functions now pass the current request into CORS responses, and deployed preflight smoke evidence passes for the website, admin, venue, and TV origins.
2. WhatsApp reviewer OTP hardening: fixed reviewer OTPs now require `WHATSAPP_AUTH_TEST_EXPIRY` with a valid future timestamp. Missing, invalid, or expired expiry disables the fixed OTP path.
3. Database grant hardening: added a migration to revoke direct client execution of `public.sports_bar_write_audit(...)` from `PUBLIC`, `anon`, and `authenticated`, while preserving trusted `service_role` execution.
4. RLS audit coverage: extended `supabase/tests/rls_hardening_audit.sql` so future audits assert `sports_bar_write_audit(...)` is not executable by `anon` or `authenticated`.
5. Release checklist hardening: updated the store-review WhatsApp OTP checklist to require a short-lived expiry and smoke-test it explicitly.
6. Mobile auth storage: custom WhatsApp auth sessions now use platform secure storage and remove the legacy general-cache key.
7. Admin authorization: shared Edge Function helpers now support role-specific admin authorization, and admin management requires the appropriate active admin role.
8. Browser session hardening: admin and venue production builds now emit a Cloudflare Pages BFF worker. OTP/session actions are mediated through same-origin `/api/auth/*` routes, Supabase access is proxied through `/api/supabase/*`, and privileged tokens are stored in HttpOnly cookies. Local development can still opt into browser mode with `VITE_PRIVILEGED_SESSION_MODE=browser`.
9. Deploy and cron controls: production deploy and operation workflows now require GitHub Environments, protected `main` branch dispatch, concurrency, explicit permissions, and secret preflights. The GitHub environments `production` and `production-operations` have required reviewers configured in repo settings.
10. Web resilience and URL hygiene: shared safe URL helpers and app-level React error boundaries were added across web surfaces.
11. Large-file refactors: the TV display app, website API service, venue menu/reward operations, and target pages were split into narrower modules while preserving existing import surfaces.
12. Live Supabase validation: `tool/supabase_live_validation.sh` now runs lint plus SQL audits through `SUPABASE_DB_URL` or a linked Supabase CLI project. The linked FANZONE database was brought up to the latest local migrations and passed the live RLS/grant and FET supply checks.

## Top Findings

| Severity | Area | Finding | Evidence | Risk | Recommended fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Secrets | Documented Supabase credential exposure is not provably closed from the repo. | `docs/secret-rotation-runbook.md:3`, `docs/secret-rotation-runbook.md:9` | Compromised anon/service-role keys, DB credentials, or PATs can remain valid outside git. | Rotate Supabase anon/service-role keys, DB password/URLs, PATs, CI/provider secrets, and local env copies; record provider-side rotation evidence. | Needs human action |
| P1 | Flutter auth storage | Custom WhatsApp sessions previously used the general cache; the runtime manager now delegates to secure storage and deletes the legacy key. | `lib/core/auth/runtime_auth_session_manager.dart`, `lib/core/storage/secure_auth_session_store.dart` | Residual risk is limited to already-issued sessions on devices that have not upgraded and cleared legacy state. | Release the secure-storage build and monitor migration/delete errors. | Fixed in repo |
| P1 | Web privileged sessions | Admin and venue production builds now use a Cloudflare Pages BFF for OTP, session restore/refresh/logout, and Supabase REST/RPC/Function proxying. Tokens are set as HttpOnly cookies instead of browser-readable state. | `packages/core/cloudflare/privileged-bff-worker.js`, `apps/admin/src/lib/supabase.ts`, `apps/venue-portal/src/lib/supabase.ts`, `apps/admin/vite.config.ts`, `apps/venue-portal/vite.config.ts` | XSS can still perform same-origin actions as the user, but it can no longer directly read and exfiltrate refresh/access tokens. | Verify Cloudflare Pages runtime vars and perform deployed login/data smoke tests. | Fixed in repo; needs deploy smoke |
| P1 | Admin authorization | Shared Edge Function authorization supports active admin role checks, admin management gates super-admin/admin/viewer actions separately, and the linked deployed function rejects unauthenticated POSTs before role-sensitive operations run. | `supabase/functions/_shared/auth.ts`, `supabase/functions/admin_user_management/index.ts`, `supabase/functions/_shared/auth_test.ts`, `release/qa/admin-auth-deploy-smoke-evidence.json` | Privileged live role-matrix proof still requires short-lived admin JWTs or browser UAT evidence; no privileged JWTs are stored in repo evidence. | Keep shared auth unit tests, critical admin UAT, and `node tool/capture_admin_auth_deploy_smoke.mjs` in the release evidence loop. | Deployed with auth-boundary smoke |
| P1 | Web release env validation | `VITE_SUPABASE_ANON_KEY` validation only checked for a JWT-looking prefix. | `tool/validate_web_release_env.sh:56`, `tool/validate_web_release_env.sh:104`, `tool/validate_release_env.sh:69`, `tool/validate_release_env.sh:126` | A service-role JWT could be misnamed and shipped to browsers. | Decode JWT payload during validation and require role `anon`; reject service-role or unexpected roles. | Fixed in repo |
| P1 | WhatsApp reviewer OTP | Fixed OTPs for store review could become a standing public login path if left configured indefinitely. | `supabase/functions/whatsapp-otp/index.ts:32`, `supabase/functions/whatsapp-otp/index.ts:122`, `supabase/functions/whatsapp-otp/index_test.ts:136`, `docs/release-checklist.md:64` | A leaked/reused reviewer phone and OTP bypasses normal OTP delivery and rate-limit intent. | Require short-lived `WHATSAPP_AUTH_TEST_EXPIRY`, rotate/remove reviewer secrets after review, redeploy function secrets. | Fixed in repo, needs deploy/secrets |
| P1 | Edge CORS | Browser-callable Edge responses are now request-scoped and the deployed functions reflect only allowlisted origins. | `supabase/functions/_shared/http.ts:24`, `supabase/functions/_shared/http_test.ts:42`, `supabase/functions/whatsapp-otp/index.ts:77`, `supabase/functions/generate-pool-social-card/index.ts:253`, `release/qa/edge-cors-smoke-evidence.json` | Residual risk is configuration drift if deployed Edge secrets are changed without rerunning smoke evidence. | Keep `node tool/capture_edge_cors_smoke.mjs` and `node tool/validate_edge_cors_smoke_evidence.mjs` in the release evidence loop. | Fixed and deployed with smoke evidence |
| P1 | Audit helper grants | Direct client grants on `sports_bar_write_audit(...)` have been revoked in linked Supabase and the RLS/grant audit returns clean. | `supabase/migrations/20260501155500_remote_audit_helper_dynamic_sql.sql:86`, `supabase/migrations/20260506130000_audit_helper_grant_hardening.sql:5`, `supabase/tests/rls_hardening_audit.sql:135`, `release/qa/current-fullstack-supabase-evidence.json` | CI still needs linked database access if this audit must run unattended. | Keep `./tool/supabase_rls_audit.sh` in release validation and rerun after schema or grant changes. | Fixed in linked DB |
| P1 | Supabase live validation | Live validation now runs through `SUPABASE_DB_URL` or the linked Supabase CLI Management API. Pending migrations `20260506130000` and `20260507120000` were applied to the linked FANZONE database, and validation passed. | `tool/supabase_live_validation.sh`, `tool/supabase_rls_audit.sh`, `tool/supabase_fet_supply_smoke.sh`, `supabase migration list --linked` | CI still needs repo secrets if live SQL validation must run unattended in GitHub Actions. | Add `SUPABASE_DB_URL`/`SUPABASE_BOOTSTRAP_DB_URL` secrets or a managed Supabase CLI auth strategy for CI. | Fixed locally/live; CI secrets remain |
| P1 | Scheduled jobs | Production cron workflows now have environment approval, branch restrictions, concurrency, and secret preflights; provider scheduler monitoring evidence is still external. | `.github/workflows/cron-settle.yml`, `.github/workflows/cron-match-alerts.yml` | Pool settlement or match-alert dispatch can silently stop if provider schedules/alerts are not configured. | Verify provider schedules, missed-run alerts, and incident owner escalation outside the repo. | Repo fixed; provider evidence remains |
| P1 | Deploy gates | Cloudflare deploy workflows now use the `production` GitHub Environment, required reviewers, protected `main` dispatch, concurrency, and env validation. | `.github/workflows/deploy-website.yml`, `.github/workflows/deploy-admin.yml`, `.github/workflows/deploy-venue-portal.yml`, `.github/workflows/deploy-tv-display.yml` | Production promotion still depends on provider secrets and smoke-test discipline. | Keep required reviewers enabled and verify Cloudflare deploy secrets before release. | Fixed in repo and GitHub settings |
| P1 | Flutter validation | Current mobile evidence records `flutter test --coverage` passing with 288 tests, `flutter analyze` passing with no issues, and validated coverage metrics for 199 Flutter files. | `release/qa/current-fullstack-supabase-evidence.json`, `release/qa/flutter-coverage-evidence.json`, `release/qa/flutter-coverage-lcov.info`, `lib/core/logging/app_logger.dart`, `02-validation-baseline.md` | Coverage percentage is evidence for monitoring test breadth, not a standalone launch-quality target. | Keep coverage capture in the release evidence bundle and raise targeted coverage around high-risk flows as they change. | Fixed in current evidence |
| P2 | Public URL rendering | Browser apps use shared `safeHref`/`safeImageUrl` helpers at public link and image boundaries, and linked Supabase now enforces validated URL-safety checks for public/generated URL columns. | `packages/core/src/url.ts`, `apps/website/src/components/MatchPools.tsx`, `supabase/migrations/20260606173000_public_url_safety_constraints.sql`, `supabase/migrations/20260606174000_validate_public_url_safety_constraints.sql`, `output/release-evidence/public-url-safety/20260606T072128Z.log` | Future externally sourced URL columns need the same helper/constraint pattern when added. | Keep public URL columns behind app-side safe render helpers and database constraints. | Fixed in app code and linked DB |
| P2 | Error isolation | React roots now have app-level error boundaries with reload affordances. | `apps/admin/src/components/ui/AppErrorBoundary.tsx`, `apps/website/src/components/ui/AppErrorBoundary.tsx`, `apps/venue-portal/src/components/console/AppErrorBoundary.tsx`, `apps/tv-display/src/components/AppErrorBoundary.tsx` | Telemetry is still absent, so render failures are user-visible but not automatically reported. | Add production error telemetry. | Fixed in repo |
| P2 | Secret scanning depth | CI now runs the repo full-history credential scan after the tracked-file regex scan, and the local full-history scan passed on 2026-06-06. | `.github/workflows/secret-regex-scan.yml`, `tool/full_history_secret_scan.sh` | Regex scanning is still narrower than a dedicated secret-scanning engine. | Add `gitleaks` or `trufflehog` as a defense-in-depth gate when available. | Fixed with regex history scan; dedicated scanner remains optional hardening |

## High-Leverage Improvements

1. Prove credential rotation externally and redeploy all affected clients/functions after rotation.
2. Verify Cloudflare Pages BFF runtime variables and perform deployed admin/venue login and data smoke tests.
3. Add `SUPABASE_DB_URL`/`SUPABASE_BOOTSTRAP_DB_URL` GitHub secrets if live SQL validation must run unattended in Actions.
4. Make production schedulers visible, monitored, and alerting-backed at the provider level.
5. Extend JWT role validation to mobile preflight tooling and deployment smoke scripts.
6. Add production error telemetry for admin, venue, website, and TV surfaces.
7. Add DB-level constraints for generated URL fields where feasible.

## Deployment Checklist

Pre-prod:
- Rotate compromised credentials and confirm provider-side creation timestamps.
- Run `flutter analyze` and `flutter test --coverage`, then validate `release/qa/flutter-coverage-evidence.json`.
- Apply all migrations to a throwaway database and run SQL/RLS audit scripts.
- Decode env Supabase keys and verify only anon keys enter client bundles.

Staging:
- Deploy updated Edge Functions, especially `whatsapp-otp` and `generate-pool-social-card`.
- Set `FANZONE_EDGE_ALLOWED_ORIGINS` and short-lived WhatsApp reviewer OTP secrets.
- Run web builds, mobile smoke tests, Supabase release probes, and cron smoke jobs.
- Verify CORS/CSP/cache headers from deployed origins and rerun the Edge CORS smoke evidence.

Production:
- Require GitHub Environment approval and protected refs before deploy.
- Apply migrations with rollback plan and backup checkpoint.
- Confirm scheduler history, alert routes, and incident owners.
- Remove or expire reviewer OTP secrets after store review.

Rollback:
- Revert web deployment to prior Cloudflare Pages build.
- Redeploy prior Edge Function bundle if needed.
- Use the documented migration rollback/restore plan; do not run destructive DB reset commands against production.

## Roadmap

0-7 days:
- Complete credential rotation, rerun Supabase SQL/RLS audits, and keep deployed Edge smoke evidence fresh.
- Keep the Flutter coverage artifact fresh for each release candidate and raise targeted coverage around changed high-risk flows.
- Extend JWT role validation to mobile preflight tooling and deployment smoke scripts.

8-30 days:
- Implement secure mobile auth storage and admin/venue server-mediated sessions.
- Add role-specific admin Edge authorization and regression tests.
- Add scheduler alerts and GitHub deployment environment gates.

31-90 days:
- Add full-history secret scanning, dependency update automation, root React error boundaries, accessibility checks, and production observability dashboards.
- Run backup/restore exercises, load/performance checks, and legal/privacy review for PII retention/export/deletion.
