# Production Readiness Executive Summary

Audit date: 2026-05-06

Overall readiness: Red
Recommendation: No-go for production launch until the open P0/P1 items below are closed or explicitly accepted with owners and mitigations.

## Scope Reviewed

- Flutter mobile app at `lib/`, `test/`, `integration_test/`, Android/iOS project files, and release tooling in `tool/`.
- Admin and companion web apps at `apps/admin`, `apps/website`, `apps/venue-portal`, `apps/tv-display`, and shared package code at `packages/core`.
- Supabase backend at `supabase/`, including migrations, Edge Functions, RLS test scripts, config, and operational scripts.
- CI/CD and release tooling at `.github/workflows/`, `tool/`, `scripts/`, env examples, and docs.

The repo already has meaningful production hardening: Supabase/RLS is documented as the backend authorization boundary, service-role keys are not intended for clients, off-platform payments are an explicit product rule, Edge Functions have Deno tests, Flutter has a broad test suite, and the web workspaces build cleanly.

## Safe Refactor Passes Completed

1. Edge auth hardening: removed the unsigned JWT fallback from `supabase/functions/order_create/index.ts`; order creation now requires a verified Supabase auth result.
2. Database grant hardening: added migration `supabase/migrations/20260506120000_release_auth_grant_hardening.sql` to revoke sensitive helper RPCs from public, anon, and authenticated roles and restrict them to `service_role`.
3. RLS audit coverage: extended `supabase/tests/rls_hardening_audit.sql` to assert auth and wallet helper RPCs are not executable by anon/authenticated roles and that future default grants are not broadly exposed.
4. Web hardening: added baseline CSP headers to each static web app and disabled production sourcemaps for the admin app.
5. Release tooling hardening: made `tool/deploy_cloudflare_pages.sh` refuse dirty-worktree deploys unless explicitly allowed.
6. Secret scan tuning: adjusted `.github/workflows/secret-regex-scan.yml` to avoid false positives from sanitized top-level env examples.

## Launch Blockers And High Findings

| Severity | Area | Finding | Evidence | Risk | Recommended fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Secrets | Supabase credentials were previously shared during assistant release work and must be rotated before launch. | `docs/README.md:68` | Compromised credentials could allow backend/API access even if no tracked secret is present now. | Rotate Supabase access token, DB password, anon key, and service-role key; update CI/hosting secrets. | Needs human action |
| P0 | Supabase Auth | `order_create` accepted an unverified decoded JWT fallback before this pass. | `supabase/functions/order_create/index.ts:66` | Forged bearer tokens could impersonate users for order creation. | Removed fallback; deploy function and rerun release probes. | Fixed in repo, needs deploy |
| P0 | Database Grants | Sensitive wallet/auth helper RPCs were callable by roles beyond trusted server contexts. | `supabase/migrations/20260506120000_release_auth_grant_hardening.sql` | Direct RPC execution could bypass intended server-only flows. | Apply migration, run RLS audit against target DB. | Fixed in repo, needs DB apply |
| P1 | Supabase Validation | Local Supabase DB lint/audit could not run because Docker/Postgres was unavailable. | `supabase db lint --local --schema public --fail-on error` failed: `127.0.0.1:54322` refused. | SQL grants/policies need live DB verification. | Start local Supabase or run against staging with operator secrets. | Not fixed |
| P1 | CI/CD | Main CI and secret scan workflows are manual only. | `.github/workflows/ci.yml:3`, `.github/workflows/secret-regex-scan.yml:3` | PRs can merge without automated lint/test/build/security gates. | Enable automatic PR/push checks or document branch protection compensating controls. | Not fixed |
| P1 | Edge CORS | Shared Edge Function CORS still allows `*`. | `supabase/functions/_shared/cors.ts:5` | Privileged functions are easier to call from unintended origins. | Move to environment-aware origin allowlist for browser-facing functions. | Not fixed |
| P1 | Web Sessions | Admin and venue apps use browser local storage for Supabase sessions. | `apps/admin/src/lib/supabase.ts`, `apps/venue-portal/src/lib/supabase.ts` | XSS can expose long-lived tokens; CSP only reduces, not removes, this risk. | Review session lifetime, XSS posture, MFA, and cookie/server mediation for high-risk admin actions. | Partially fixed |
| P1 | Flutter Release Validation | Flutter tests pass, but format/analyze still fail and debug APK build hung in this environment. | See `02-validation-baseline.md`. | Release confidence is incomplete. | Fix analyzer/format drift and rerun Android/iOS/web release builds in the supported build environment. | Not fixed |
| P2 | Supply Chain | `scripts` workspace has one moderate npm advisory. | `npm audit --audit-level=moderate` in `scripts` | Non-app tooling dependency has a known advisory. | Run `npm audit fix` after reviewing lockfile impact. | Not fixed |
| P2 | Observability | Runbooks and production alerting are incomplete for auth outage, DB migration failure, slow DB, and high error rate. | `docs/` review | Incidents will be slower to detect and recover from. | Add operational runbooks, alert routing, and dashboards. | Not fixed |

## Go/No-Go Criteria

Do not launch until:

- Credentials in the documented rotation blocker are rotated.
- The new Supabase grant-hardening migration is applied to staging/prod and the SQL/RLS audit scripts pass.
- Edge Functions are redeployed, especially `order_create`.
- CI or an explicit protected-release process runs Flutter, web, Supabase, Deno, and secret scanning checks before release.
- Flutter analyzer/format drift is resolved and release builds are verified in the target build environment.

## Roadmap

0-7 days:
- Rotate Supabase credentials, deploy Edge Functions, apply the new grant-hardening migration, and rerun SQL/RLS audits.
- Fix Flutter format/analyze failures and rerun Android/iOS release smoke builds.
- Decide whether manual-only CI remains acceptable; otherwise enable PR/push checks.

8-30 days:
- Replace wildcard Edge CORS with an allowlist.
- Harden admin and venue session handling and require MFA/least-privilege checks for sensitive operations.
- Add pgTAP/RLS tests for owner, non-owner, anon, authenticated, and admin scenarios.

31-90 days:
- Add production observability dashboards, incident runbooks, backup/restore exercises, performance budgets, and accessibility regression checks.
- Review dependency drift and automate dependency/security update cadence.
