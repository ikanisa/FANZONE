# Production Readiness Validation Baseline

Audit date: 2026-05-06

## Local Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `flutter --version` | Passed | Flutter `3.38.9`; newer Flutter available. |
| `dart --version` | Passed | Dart `3.10.8`. |
| `node --version` | Passed | Node `v22.22.2`. |
| `npm --version` | Passed | npm `11.8.0`. |
| `deno --version` | Passed | Deno `2.7.5`. |
| `supabase --version` | Passed | Supabase CLI `2.90.0`; newer CLI available. |
| `flutter pub get` | Passed | Dependencies resolved; 51 packages have newer incompatible versions. |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | Failed | 25 files would be reformatted. No formatting writes were applied because the worktree had unrelated dirty files. |
| `flutter analyze` | Failed | 15 info-level `prefer_const_constructors` issues, mostly in `lib/features/ordering/screens/venue_menu_screen.dart`. |
| `flutter test` | Passed | 232 tests passed. |
| `flutter test --coverage` | Passed | 232 tests passed and coverage collection completed. |
| `flutter build apk --debug` | Inconclusive | Produced no useful output for about 648 seconds and was killed; rerun in a supported Android build environment. |
| `npm run typecheck --workspaces --if-present` | Passed | Admin, website, venue portal, TV display, and core workspace type checks completed. |
| `npm run lint --workspaces --if-present` | Passed | All web workspace lint scripts completed. |
| `npm run test --workspaces --if-present` | Passed | Admin: 22 tests. Website: 6 tests. Other workspaces had no test script or no matching tests. |
| `npm run build --workspaces --if-present` | Passed | Admin, website, venue portal, and TV display production builds completed. Admin production output emitted no `.map` files after the config change. |
| `deno fmt --check supabase/functions` | Passed | 39 function/shared files checked. |
| `deno check supabase/functions/order_create/index.ts supabase/functions/_shared/http.ts supabase/functions/_shared/cors.ts` | Passed | Targeted type-check for changed Edge Function path and shared HTTP/CORS helpers. |
| `deno test --allow-env supabase/functions` | Passed | 27 tests passed. |
| `supabase db lint --local --schema public --fail-on error` | Failed | Local Supabase/Postgres unavailable on `127.0.0.1:54322`. |
| `docker info --format '{{.ServerVersion}}'` | Failed | Docker/Colima daemon unavailable at `/Users/jeanbosco/.colima/default/docker.sock`. |
| `gitleaks version` | Not available | Command not installed. |
| `trufflehog --version` | Not available | Command not installed. |
| Redacted secret regex scan via repo workflow pattern | Passed | No tracked matches after excluding sanitized env examples. |
| `npm audit --audit-level=moderate` at repo root | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `apps/admin` | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `apps/website` | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `scripts` | Failed | 1 moderate advisory for `ip-address <=10.1.0`; `npm audit fix` available. |
| `bash -n tool/deploy_cloudflare_pages.sh tool/*.sh` | Passed | Shell syntax valid after deploy guard update. |
| `git diff --check` | Failed | Pre-existing dirty `integration_test/app_smoke_test.dart` has trailing whitespace at lines 39, 64, and 100. |

## What Can Be Validated Locally

- Flutter dependency resolution, unit/widget/integration-style test suite, and coverage collection.
- Web workspace typecheck, lint, test, and production builds.
- Deno formatting, type checking, and Edge Function unit tests.
- Static secret regex scanning for tracked files.
- Shell syntax for release scripts.

## What Cannot Be Fully Validated Locally Yet

- Supabase migration/RLS correctness against a running local or staging database, because Docker/local Supabase was unavailable.
- Production/staging Supabase state, because operator credentials were not used during this audit.
- Android/iOS release build reproducibility, because the debug APK build hung and release signing/codesigning environments were not exercised.
- Hosted CSP/CORS behavior, because headers must be verified after deployment on the target host.
- Admin/venue end-to-end authorization, because live role, tenant, and object-level policy scenarios require seeded users and DB state.

## Risky Areas Requiring Human Review

- Credential rotation for the previously disclosed Supabase credentials.
- Whether manual-only CI is acceptable for the release model.
- Production Supabase migration application and rollback plan.
- Admin and venue session/token storage strategy.
- Edge Function CORS allowlist and environment-specific origins.
- Backup/PITR/restore exercise status.
- Legal/privacy review for PII, analytics, account deletion/export, and retention.

## Validation Follow-Up Checklist

1. Start local Supabase with Docker/Colima and run `supabase db lint --local --schema public --fail-on error`.
2. Apply migrations to a throwaway database and run `tool/supabase_rls_audit.sh` and `tool/supabase_fet_supply_smoke.sh`.
3. Deploy updated Edge Functions to staging and run the Supabase release probes.
4. Fix Dart format/analyzer findings, then rerun `dart format --set-exit-if-changed .`, `flutter analyze`, and `flutter test --coverage`.
5. Rerun Android release build and iOS no-codesign build in the supported release environment.
6. Run browser smoke tests against deployed web apps and verify CSP headers, service worker behavior, and admin/venue auth flows.
