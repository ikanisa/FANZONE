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

1. Request-scoped Edge CORS: `buildCorsHeaders` now accepts a `Request` and reflects only allowlisted request origins for browser calls while preserving existing explicit-origin behavior. The WhatsApp OTP and pool social-card functions now pass the current request into CORS responses.
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
| P1 | Admin authorization | Shared Edge Function authorization now supports active admin role checks, and admin management gates super-admin/admin/viewer actions separately. | `supabase/functions/_shared/auth.ts`, `supabase/functions/admin_user_management/index.ts`, `supabase/functions/_shared/auth_test.ts` | Residual risk depends on deployed RLS/grant state and target DB drift. | Deploy functions and run live role/RLS regression checks against staging/prod. | Fixed in repo, needs deploy/live validation |
| P1 | Web release env validation | `VITE_SUPABASE_ANON_KEY` validation only checked for a JWT-looking prefix. | `tool/validate_web_release_env.sh:56`, `tool/validate_web_release_env.sh:104`, `tool/validate_release_env.sh:69`, `tool/validate_release_env.sh:126` | A service-role JWT could be misnamed and shipped to browsers. | Decode JWT payload during validation and require role `anon`; reject service-role or unexpected roles. | Fixed in repo |
| P1 | WhatsApp reviewer OTP | Fixed OTPs for store review could become a standing public login path if left configured indefinitely. | `supabase/functions/whatsapp-otp/index.ts:32`, `supabase/functions/whatsapp-otp/index.ts:122`, `supabase/functions/whatsapp-otp/index_test.ts:136`, `docs/release-checklist.md:64` | A leaked/reused reviewer phone and OTP bypasses normal OTP delivery and rate-limit intent. | Require short-lived `WHATSAPP_AUTH_TEST_EXPIRY`, rotate/remove reviewer secrets after review, redeploy function secrets. | Fixed in repo, needs deploy/secrets |
| P1 | Edge CORS | Some browser-callable Edge responses were not request-scoped, risking wrong-origin CORS headers when multiple origins are configured. | `supabase/functions/_shared/http.ts:24`, `supabase/functions/_shared/http_test.ts:42`, `supabase/functions/whatsapp-otp/index.ts:77`, `supabase/functions/generate-pool-social-card/index.ts:253` | Browser access can fail for valid origins or accidentally expose responses to an unintended configured origin. | Pass `Request` to CORS helpers from browser-callable functions and verify deployed `FANZONE_EDGE_ALLOWED_ORIGINS`. | Fixed in repo, needs deploy |
| P1 | Audit helper grants | Historical migrations grant `sports_bar_write_audit(...)` to `authenticated`, allowing actor spoofing if callable directly. | `supabase/migrations/20260501155500_remote_audit_helper_dynamic_sql.sql:86`, `supabase/migrations/20260506130000_audit_helper_grant_hardening.sql:5`, `supabase/tests/rls_hardening_audit.sql:135` | Authenticated clients could write audit records outside product RPCs/functions. | Apply the new revoke migration and run RLS/grant audit against staging/prod. | Fixed in repo, needs DB apply |
| P1 | Supabase live validation | Live validation now runs through `SUPABASE_DB_URL` or the linked Supabase CLI Management API. Pending migrations `20260506130000` and `20260507120000` were applied to the linked FANZONE database, and validation passed. | `tool/supabase_live_validation.sh`, `tool/supabase_rls_audit.sh`, `tool/supabase_fet_supply_smoke.sh`, `supabase migration list --linked` | CI still needs repo secrets if live SQL validation must run unattended in GitHub Actions. | Add `SUPABASE_DB_URL`/`SUPABASE_BOOTSTRAP_DB_URL` secrets or a managed Supabase CLI auth strategy for CI. | Fixed locally/live; CI secrets remain |
| P1 | Scheduled jobs | Production cron workflows now have environment approval, branch restrictions, concurrency, and secret preflights; provider scheduler monitoring evidence is still external. | `.github/workflows/cron-settle.yml`, `.github/workflows/cron-match-alerts.yml` | Pool settlement or match-alert dispatch can silently stop if provider schedules/alerts are not configured. | Verify provider schedules, missed-run alerts, and incident owner escalation outside the repo. | Repo fixed; provider evidence remains |
| P1 | Deploy gates | Cloudflare deploy workflows now use the `production` GitHub Environment, required reviewers, protected `main` dispatch, concurrency, and env validation. | `.github/workflows/deploy-website.yml`, `.github/workflows/deploy-admin.yml`, `.github/workflows/deploy-venue-portal.yml`, `.github/workflows/deploy-tv-display.yml` | Production promotion still depends on provider secrets and smoke-test discipline. | Keep required reviewers enabled and verify Cloudflare deploy secrets before release. | Fixed in repo and GitHub settings |
| P1 | Flutter validation | `flutter test` could not complete in this environment because the system volume was full. | `02-validation-baseline.md` | Mobile regression confidence remains incomplete for this run. | Free system disk or move Dart temp/cache paths, then rerun `flutter test` and coverage. | Blocked |
| P2 | Public URL rendering | Browser apps now use shared `safeHref`/`safeImageUrl` helpers at public link and image boundaries. | `packages/core/src/url.ts`, `apps/website/src/components/MatchPools.tsx` | DB-level URL constraints are still not enforced for all externally sourced URL columns. | Add database constraints for generated URL fields where feasible. | Fixed in app code |
| P2 | Error isolation | React roots now have app-level error boundaries with reload affordances. | `apps/admin/src/components/ui/AppErrorBoundary.tsx`, `apps/website/src/components/ui/AppErrorBoundary.tsx`, `apps/venue-portal/src/components/console/AppErrorBoundary.tsx`, `apps/tv-display/src/components/AppErrorBoundary.tsx` | Telemetry is still absent, so render failures are user-visible but not automatically reported. | Add production error telemetry. | Fixed in repo |
| P2 | Secret scanning depth | CI uses a narrow regex scan; full-history tools are not installed locally. | `.github/workflows/secret-regex-scan.yml:21`, `02-validation-baseline.md` | Historical or non-JWT secrets may be missed. | Add `gitleaks` or `trufflehog` full-history scanning with explicit allowlists. | Not fixed |

## High-Leverage Improvements

1. Prove credential rotation externally and redeploy all affected clients/functions.
2. Verify Cloudflare Pages BFF runtime variables and perform deployed admin/venue login and data smoke tests.
3. Add `SUPABASE_DB_URL`/`SUPABASE_BOOTSTRAP_DB_URL` GitHub secrets if live SQL validation must run unattended in Actions.
4. Make production schedulers visible, monitored, and alerting-backed at the provider level.
5. Extend JWT role validation to mobile preflight tooling and deployment smoke scripts.
6. Add production error telemetry for admin, venue, website, and TV surfaces.
7. Add DB-level constraints for generated URL fields where feasible.

## Deployment Checklist

Pre-prod:
- Rotate compromised credentials and confirm provider-side creation timestamps.
- Free local disk or use a clean CI runner, then rerun Flutter tests and coverage.
- Apply all migrations to a throwaway database and run SQL/RLS audit scripts.
- Decode env Supabase keys and verify only anon keys enter client bundles.

Staging:
- Deploy updated Edge Functions, especially `whatsapp-otp` and `generate-pool-social-card`.
- Set `FANZONE_EDGE_ALLOWED_ORIGINS` and short-lived WhatsApp reviewer OTP secrets.
- Run web builds, mobile smoke tests, Supabase release probes, and cron smoke jobs.
- Verify CORS/CSP/cache headers from deployed origins.

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
- Complete credential rotation, deploy Edge fixes, apply audit-helper grant migration, and rerun Supabase SQL/RLS audits.
- Fix local/CI disk constraints and rerun full Flutter tests/coverage.
- Extend JWT role validation to mobile preflight tooling and deployment smoke scripts.

8-30 days:
- Implement secure mobile auth storage and admin/venue server-mediated sessions.
- Add role-specific admin Edge authorization and regression tests.
- Add scheduler alerts and GitHub deployment environment gates.

31-90 days:
- Add full-history secret scanning, dependency update automation, root React error boundaries, accessibility checks, and production observability dashboards.
- Run backup/restore exercises, load/performance checks, and legal/privacy review for PII retention/export/deletion.
