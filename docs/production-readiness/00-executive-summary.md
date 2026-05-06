# Production Readiness Executive Summary

Audit date: 2026-05-06
Audit start branch/commit: `main` at `c2fdd73 test: account for managed supabase defaults`

Overall readiness: Red
Go/no-go recommendation: No-go for production launch until the credential-rotation blocker, live Supabase/RLS validation, and privileged-session risks are closed or explicitly accepted with owners and mitigations.

## Scope Reviewed

- Flutter mobile app: `lib/`, `test/`, `integration_test/`, `android/`, `ios/`, `tool/`, and release env examples.
- Web surfaces: `apps/admin`, `apps/website`, `apps/venue-portal`, `apps/tv-display`, and `packages/core`.
- Supabase backend: `supabase/config.toml`, migrations, Edge Functions, RLS/audit SQL, seeds, and release probes.
- CI/CD, release, and operations: `.github/workflows`, `tool/`, `scripts/`, `docs/`, env examples, and deployment metadata.

The repo already has meaningful production structure: Flutter is feature-oriented, web apps are split by surface, Supabase/RLS is documented as the backend authorization boundary, service-role usage is intended to stay in trusted functions, and Deno/web checks are available. The remaining launch risk is concentrated in human-held credentials, live environment verification, privileged session storage, and operational controls.

## Safe Refactor Passes Completed

1. Request-scoped Edge CORS: `buildCorsHeaders` now accepts a `Request` and reflects only allowlisted request origins for browser calls while preserving existing explicit-origin behavior. The WhatsApp OTP and pool social-card functions now pass the current request into CORS responses.
2. WhatsApp reviewer OTP hardening: fixed reviewer OTPs now require `WHATSAPP_AUTH_TEST_EXPIRY` with a valid future timestamp. Missing, invalid, or expired expiry disables the fixed OTP path.
3. Database grant hardening: added a migration to revoke direct client execution of `public.sports_bar_write_audit(...)` from `PUBLIC`, `anon`, and `authenticated`, while preserving trusted `service_role` execution.
4. RLS audit coverage: extended `supabase/tests/rls_hardening_audit.sql` so future audits assert `sports_bar_write_audit(...)` is not executable by `anon` or `authenticated`.
5. Release checklist hardening: updated the store-review WhatsApp OTP checklist to require a short-lived expiry and smoke-test it explicitly.

## Top Findings

| Severity | Area | Finding | Evidence | Risk | Recommended fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Secrets | Documented Supabase credential exposure is not provably closed from the repo. | `docs/secret-rotation-runbook.md:3`, `docs/secret-rotation-runbook.md:9` | Compromised anon/service-role keys, DB credentials, or PATs can remain valid outside git. | Rotate Supabase anon/service-role keys, DB password/URLs, PATs, CI/provider secrets, and local env copies; record provider-side rotation evidence. | Needs human action |
| P1 | Flutter auth storage | Custom WhatsApp sessions, including refresh/access tokens, are persisted through the general Hive-backed cache. | `lib/core/auth/runtime_auth_session_manager.dart:16`, `lib/core/auth/runtime_auth_session_manager.dart:90`, `lib/core/auth/runtime_auth_session_manager.dart:193` | Device compromise or broad cache inspection exposes auth material. | Move auth material to Keychain/Keystore secure storage and migrate/delete legacy `custom_auth_session_v1`. | Not fixed |
| P1 | Web privileged sessions | Admin and venue refresh tokens are stored in browser-readable `sessionStorage`. | `apps/admin/src/lib/supabase.ts:10`, `apps/admin/src/lib/supabase.ts:77`, `apps/admin/src/lib/supabase.ts:105`, `apps/venue-portal/src/lib/supabase.ts:44`, `apps/venue-portal/src/lib/supabase.ts:74` | XSS or malicious extensions can exfiltrate privileged bearer/refresh tokens. | Prefer HttpOnly cookie/BFF mediation for admin and venue sessions; add CSP/Trusted Types hardening if browser tokens remain. | Not fixed |
| P1 | Admin authorization | Shared admin authorization checks only confirm an active admin record, while `admin_user_management` can create admins including `super_admin`. | `supabase/functions/_shared/auth.ts:101`, `supabase/functions/_shared/auth.ts:143`, `supabase/functions/admin_user_management/index.ts:20`, `supabase/functions/admin_user_management/index.ts:123` | Lower-privileged admins may be able to perform actions that should require role-specific authorization. | Add role-specific server checks such as `requireAdminRole`/`requireSuperAdmin`, and add RLS/Edge tests by role. | Not fixed |
| P1 | Web release env validation | `VITE_SUPABASE_ANON_KEY` validation only checked for a JWT-looking prefix. | `tool/validate_web_release_env.sh:56`, `tool/validate_web_release_env.sh:104`, `tool/validate_release_env.sh:69`, `tool/validate_release_env.sh:126` | A service-role JWT could be misnamed and shipped to browsers. | Decode JWT payload during validation and require role `anon`; reject service-role or unexpected roles. | Fixed in repo |
| P1 | WhatsApp reviewer OTP | Fixed OTPs for store review could become a standing public login path if left configured indefinitely. | `supabase/functions/whatsapp-otp/index.ts:32`, `supabase/functions/whatsapp-otp/index.ts:122`, `supabase/functions/whatsapp-otp/index_test.ts:136`, `docs/release-checklist.md:64` | A leaked/reused reviewer phone and OTP bypasses normal OTP delivery and rate-limit intent. | Require short-lived `WHATSAPP_AUTH_TEST_EXPIRY`, rotate/remove reviewer secrets after review, redeploy function secrets. | Fixed in repo, needs deploy/secrets |
| P1 | Edge CORS | Some browser-callable Edge responses were not request-scoped, risking wrong-origin CORS headers when multiple origins are configured. | `supabase/functions/_shared/http.ts:24`, `supabase/functions/_shared/http_test.ts:42`, `supabase/functions/whatsapp-otp/index.ts:77`, `supabase/functions/generate-pool-social-card/index.ts:253` | Browser access can fail for valid origins or accidentally expose responses to an unintended configured origin. | Pass `Request` to CORS helpers from browser-callable functions and verify deployed `FANZONE_EDGE_ALLOWED_ORIGINS`. | Fixed in repo, needs deploy |
| P1 | Audit helper grants | Historical migrations grant `sports_bar_write_audit(...)` to `authenticated`, allowing actor spoofing if callable directly. | `supabase/migrations/20260501155500_remote_audit_helper_dynamic_sql.sql:86`, `supabase/migrations/20260506130000_audit_helper_grant_hardening.sql:5`, `supabase/tests/rls_hardening_audit.sql:135` | Authenticated clients could write audit records outside product RPCs/functions. | Apply the new revoke migration and run RLS/grant audit against staging/prod. | Fixed in repo, needs DB apply |
| P1 | Supabase live validation | Local Supabase is not running and live DB credentials were not used. | `supabase status` failed: `No such container: supabase_db_FANZONE` | Static review cannot prove deployed RLS, grants, migrations, storage policies, or dashboard drift. | Start local Supabase when disk permits or run `supabase db lint` and SQL audits against staging/prod. | Blocked |
| P1 | Scheduled jobs | Production cron ownership is procedural; repo workflows for settlement and match alerts are manual-only fallbacks. | `.github/workflows/cron-settle.yml:9`, `.github/workflows/cron-match-alerts.yml:9`, `docs/release/go-live-checklist.md:58` | Pool settlement or match-alert dispatch can silently stop. | Define scheduler config as code or provider-controlled schedules with missed-run alerts and owner escalation. | Not fixed |
| P1 | Deploy gates | Cloudflare deploy workflows are manual and production-secret backed, with no repo-visible environment approval gate. | `.github/workflows/deploy-website.yml:6`, `tool/deploy_cloudflare_pages.sh:41` | A manual dispatch from the wrong ref can promote production assets without required review. | Add GitHub Environments, required reviewers, concurrency, branch/tag restrictions, and post-deploy smoke gates. | Not fixed |
| P1 | Flutter validation | `flutter test` could not complete in this environment because the system volume was full. | `02-validation-baseline.md` | Mobile regression confidence remains incomplete for this run. | Free system disk or move Dart temp/cache paths, then rerun `flutter test` and coverage. | Blocked |
| P2 | Public URL rendering | URL fields from Supabase are rendered as image/link targets without a shared allowlist helper. | `apps/website/src/services/api.ts:193`, `apps/website/src/components/MatchPools.tsx:219`, `apps/website/src/components/MatchPools.tsx:328`, `apps/venue-portal/src/features/settings/QRFactoryPage.tsx:257` | Malformed or compromised DB values can create malicious click targets or tracking URLs. | Add shared `safeHref`/`safeImageUrl` validation and DB constraints for generated URLs. | Not fixed |
| P2 | Error isolation | React roots do not have app-level error boundaries. | `apps/admin/src/main.tsx:28`, `apps/website/src/main.tsx:6`, `apps/venue-portal/src/main.tsx:6`, `apps/tv-display/src/main.tsx:12` | One render exception can blank a critical admin, venue, or display surface. | Add root and route-level error boundaries with telemetry and reload/retry affordances. | Not fixed |
| P2 | Secret scanning depth | CI uses a narrow regex scan; full-history tools are not installed locally. | `.github/workflows/secret-regex-scan.yml:21`, `02-validation-baseline.md` | Historical or non-JWT secrets may be missed. | Add `gitleaks` or `trufflehog` full-history scanning with explicit allowlists. | Not fixed |

## High-Leverage Improvements

1. Prove credential rotation externally and redeploy all affected clients/functions.
2. Move mobile auth material to secure storage and delete the legacy cache key.
3. Replace admin/venue browser refresh-token storage with server-mediated sessions.
4. Add role-specific admin authorization in Edge Functions and regression tests.
5. Extend JWT role validation to mobile preflight tooling and deployment smoke scripts.
6. Apply the audit-helper grant-hardening migration and run RLS audits against staging/prod.
7. Make production schedulers visible, monitored, and alerting-backed.
8. Add deployment approvals, branch restrictions, and post-deploy smoke gates.
9. Add shared safe URL rendering helpers for browser apps.
10. Add root error boundaries and basic accessibility/security test gates for each web surface.

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
