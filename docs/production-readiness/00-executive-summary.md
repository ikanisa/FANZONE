# Production Readiness Executive Summary

Audit date: 2026-05-06

Overall readiness: Yellow/Red
Recommendation: No-go for production launch until the human-held P0/P1 items below are closed or explicitly accepted with owners and mitigations. Repo-local implementation blockers are reduced, but credentials, deployment, and live database validation still require operator access.

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
7. CI/security gates: enabled PR/main validation triggers and added dependency/secret audit coverage to the main CI workflow.
8. CORS hardening: moved shared Edge Function helpers away from wildcard CORS by default and documented `FANZONE_EDGE_ALLOWED_ORIGINS`.
9. Admin/venue session hardening: moved custom browser sessions from `localStorage` to `sessionStorage` and clear legacy persisted tokens.

## Launch Blockers And High Findings

| Severity | Area | Finding | Evidence | Risk | Recommended fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Secrets | Supabase credentials were previously shared during assistant release work and must be rotated before launch. | `docs/README.md:68` | Compromised credentials could allow backend/API access even if no tracked secret is present now. | Rotate Supabase access token, DB password, anon key, and service-role key; update CI/hosting secrets. | Needs human action |
| P0 | Supabase Auth | `order_create` accepted an unverified decoded JWT fallback before this pass. | `supabase/functions/order_create/index.ts:66` | Forged bearer tokens could impersonate users for order creation. | Removed fallback; deploy function and rerun release probes. | Fixed in repo, needs deploy |
| P0 | Database Grants | Sensitive wallet/auth helper RPCs were callable by roles beyond trusted server contexts. | `supabase/migrations/20260506120000_release_auth_grant_hardening.sql` | Direct RPC execution could bypass intended server-only flows. | Apply migration, run RLS audit against target DB. | Fixed in repo, needs DB apply |
| P1 | Supabase Validation | Local Supabase DB lint/audit could not run because Docker/Postgres was unavailable. | `supabase db lint --local --schema public --fail-on error` failed: `127.0.0.1:54322` refused. | SQL grants/policies need live DB verification. | Start local Supabase or run against staging with operator secrets. | Not fixed |
| P1 | CI/CD | Main CI and secret scan workflows were manual only. | `.github/workflows/ci.yml`, `.github/workflows/secret-regex-scan.yml` | PRs could merge without automated lint/test/build/security gates. | PR/main triggers and dependency/secret audit job added; branch protection still needs repository configuration. | Partially fixed |
| P1 | Edge CORS | Shared Edge Function CORS allowed `*` by default. | `supabase/functions/_shared/cors.ts`, `supabase/functions/_shared/cors_allowlist.ts` | Privileged functions were easier to call from unintended origins. | Environment-aware allowlist added; deployed secrets must set exact production origins. | Partially fixed |
| P1 | Web Sessions | Admin and venue apps used browser local storage for custom sessions. | `apps/admin/src/lib/supabase.ts`, `apps/venue-portal/src/lib/supabase.ts` | XSS could expose long-lived tokens across browser restarts. | Session storage now uses `sessionStorage` and clears legacy `localStorage`; MFA/server mediation still needs product decision. | Partially fixed |
| P1 | Flutter Release Validation | Flutter tests passed, but format/analyze failed and debug APK build hung in this environment. | See `02-validation-baseline.md`. | Release confidence was incomplete. | Format/analyze fixed locally; Android/iOS release builds still need target build environment. | Partially fixed |
| P2 | Supply Chain | `scripts` workspace had one moderate npm advisory. | `npm audit --audit-level=moderate` in `scripts` | Non-app tooling dependency had a known advisory. | Stale scripts lockfile dependencies removed by `npm audit fix`; audit now passes. | Fixed |
| P2 | Observability | Runbooks and production alerting were incomplete for auth outage, DB migration failure, slow DB, and high error rate. | `docs/operations/incident-runbooks.md` | Incidents would be slower to detect and recover from. | Runbook skeleton added; real alert routing/dashboard ownership still needs operator configuration. | Partially fixed |

## Go/No-Go Criteria

Do not launch until:

- Credentials in the documented rotation blocker are rotated.
- The new Supabase grant-hardening migration is applied to staging/prod and the SQL/RLS audit scripts pass.
- Edge Functions are redeployed, especially `order_create`.
- GitHub branch protection requires the now-enabled CI and secret/dependency audit checks.
- Flutter mobile release builds are verified in the target Android/iOS build environment.

## Roadmap

0-7 days:
- Rotate Supabase credentials, deploy Edge Functions, apply the new grant-hardening migration, and rerun SQL/RLS audits.
- Configure GitHub branch protection for the now-enabled CI checks.
- Rerun Android/iOS release smoke builds in the supported build environment.

8-30 days:
- Verify deployed Edge Function CORS allowlists from every production browser origin.
- Require MFA/least-privilege checks for sensitive admin and venue operations.
- Add pgTAP/RLS tests for owner, non-owner, anon, authenticated, and admin scenarios.

31-90 days:
- Add production observability dashboards, backup/restore exercises, performance budgets, and accessibility regression checks.
- Review dependency drift and automate dependency/security update cadence.
