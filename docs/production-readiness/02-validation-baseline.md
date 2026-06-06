# Production Readiness Validation Baseline

Audit date: 2026-05-06

## 2026-06-06 Current Evidence Refresh

- `flutter analyze` now passes with no issues after the logger interpolation cleanup in `lib/core/logging/app_logger.dart`.
- `release/qa/current-fullstack-supabase-evidence.json` records the current Flutter coverage gate as passing with 288 tests.
- `release/qa/flutter-coverage-evidence.json` validates `release/qa/flutter-coverage-lcov.info` at 199 files, 14,923 executable lines, 5,393 covered lines, and 36.14% line coverage.
- `release/qa/edge-cors-smoke-evidence.json` validates deployed Edge preflight behavior for WhatsApp OTP and pool social-card across the website, admin, venue, and TV origins without using credentials.
- `release/qa/admin-auth-deploy-smoke-evidence.json` validates the deployed admin Edge function is active at version 15 and rejects an unauthenticated POST before any admin action can execute.
- `tool/full_history_secret_scan.sh` passed locally and is wired into `.github/workflows/secret-regex-scan.yml` after the tracked-file regex scan.
- Linked Supabase public URL safety constraints were applied, existing data was audited clean, and constraints were validated by `tool/supabase_public_url_safety_contract.sh`; latest evidence: `output/release-evidence/public-url-safety/20260606T072128Z.log`.

## Local Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `git status --short` | Passed | Worktree was clean at audit start. |
| `git branch --show-current` | Passed | `main`. |
| `git log -1 --oneline` | Passed | `c2fdd73 test: account for managed supabase defaults`. |
| `flutter --version` | Passed | Flutter `3.38.9`. |
| `dart --version` | Passed | Dart `3.10.8`. |
| `node --version` | Passed | Node `v22.22.2`. |
| `npm --version` | Passed | npm `11.8.0`. |
| `deno --version` | Passed | Deno `2.7.5`. |
| `supabase --version` | Passed | Supabase CLI `2.90.0`; `2.98.2` available. |
| `docker info --format '{{.ServerVersion}}'` | Passed | Docker server `28.4.0`. |
| `flutter pub get` | Passed | Dependencies resolved; 51 packages reported newer incompatible versions. |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | Passed | 286 files checked, no formatting changes needed. |
| `flutter analyze` | Passed | No issues found. |
| `flutter test` | Failed | Dart compiler failed writing `output.dill`: `OS Error: No space left on device, errno = 28`. `/System/Volumes/Data` had about 194 MiB free. |
| `npm run typecheck --workspaces --if-present` | Passed | Admin, website, venue portal, TV display, and core workspace type checks completed. |
| `npm run lint --workspaces --if-present` | Passed | All workspace lint scripts completed. |
| `npm run test --workspaces --if-present` | Passed | Admin: 22 tests across 8 files. Website: 6 tests across 2 files. Other workspaces had no test script/matching tests. |
| `npm run build --workspaces --if-present` | Passed | Admin, TV display, venue portal, and website production builds completed. |
| `bash -n tool/validate_web_release_env.sh tool/validate_release_env.sh` | Passed | Release env validators are syntactically valid after JWT role hardening. |
| `tool/validate_web_release_env.sh website` with synthetic anon/service-role JWTs | Passed | Synthetic anon-role JWT passed; synthetic service-role JWT was rejected without printing token contents. |
| `tool/validate_release_env.sh <temp-file> --client` with synthetic anon/service-role JWTs | Passed | Synthetic client anon-role JWTs passed; synthetic service-role `SUPABASE_ANON_KEY` was rejected. |
| `deno fmt --check supabase/functions` | Passed | 41 files checked after Edge changes. |
| `find supabase/functions -name '*.ts' -print0 \| xargs -0 deno check` | Passed | Every Supabase function/shared TypeScript file type-checked. |
| `deno test --allow-env supabase/functions` | Passed | 34 tests passed, 0 failed. |
| `npm audit --audit-level=moderate` at repo root | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `apps/admin` | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `apps/website` | Passed | 0 vulnerabilities. |
| `npm audit --audit-level=moderate` in `scripts` | Passed | 0 vulnerabilities. |
| Redacted secret regex scan over tracked files | Passed | No tracked matches found with the repo workflow pattern. Local ignored env files were not printed. |
| `gitleaks version` | Not available | Tool not installed. |
| `trufflehog --version` | Not available | Tool not installed. |
| `supabase status` | Failed | Local Supabase containers are not running: `No such container: supabase_db_FANZONE`. |
| `supabase start` | Not run | Docker exists, but the system data volume is effectively full; starting/pulling local Supabase would be unreliable and potentially disruptive. |
| `supabase db lint --local --schema public --fail-on error` | Not run | Requires a running local Supabase DB. |

## Locally Validated Surfaces

- Flutter dependency resolution, static analysis, full test suite, and coverage evidence.
- Web workspace typecheck, lint, tests, production builds, and moderate npm audits.
- Supabase Edge Function formatting, type checking, and unit tests.
- Static secret-regex scanning over tracked files and release env role validation with synthetic JWTs.
- Current branch/commit and initial worktree cleanliness.

## Blocked Or Not Locally Proven

- Android/iOS release builds and signing/codesigning flows.
- Local Supabase DB lint, migration replay, RLS/grant audit, storage policies, and generated types.
- Staging/production Supabase state, because operator DB credentials were not used.
- Provider-side credential rotation, branch protection, GitHub Environment approvals, Cloudflare dashboard settings, and production scheduler history.
- Service-worker behavior and final provider-side header evidence after each deploy. Deployed Edge CORS preflight evidence is now captured in `release/qa/edge-cors-smoke-evidence.json`.
- Admin/venue end-to-end role and object-level authorization with seeded live users.

## Validation Follow-Up Checklist

1. Keep `flutter test --coverage` in the release evidence loop and raise targeted coverage around high-risk flows as they change.
2. Run Android and iOS release smoke builds in the supported signing/codesigning environment.
3. Start local Supabase or use staging credentials, then run `supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error`.
4. Apply migrations to a throwaway/staging database and run `psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql`.
5. Deploy updated Edge Functions and rerun `node tool/capture_edge_cors_smoke.mjs`, `tool/supabase_release_probe.sh`, `tool/supabase_whatsapp_auth_smoke.sh`, and cron/job smoke scripts.
6. Extend JWT role validation to `tool/preflight_build_check.sh` and any release smoke scripts that accept `SUPABASE_ANON_KEY`.
7. Add full-history secret scanning with `gitleaks` or `trufflehog` and run it before launch.
8. Verify deployed web headers with `curl -I` for each origin, including `/index.html` and static assets.
