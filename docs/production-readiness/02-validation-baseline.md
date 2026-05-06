# Production Readiness Validation Baseline

Audit date: 2026-05-06

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

- Flutter dependency resolution and static analysis.
- Web workspace typecheck, lint, tests, production builds, and moderate npm audits.
- Supabase Edge Function formatting, type checking, and unit tests.
- Static secret-regex scanning over tracked files.
- Current branch/commit and initial worktree cleanliness.

## Blocked Or Not Locally Proven

- Full Flutter test suite and coverage, due system disk exhaustion.
- Android/iOS release builds and signing/codesigning flows.
- Local Supabase DB lint, migration replay, RLS/grant audit, storage policies, and generated types.
- Staging/production Supabase state, because operator DB credentials were not used.
- Provider-side credential rotation, branch protection, GitHub Environment approvals, Cloudflare dashboard settings, and production scheduler history.
- Deployed CORS/CSP/cache headers and service-worker behavior.
- Admin/venue end-to-end role and object-level authorization with seeded live users.

## Validation Follow-Up Checklist

1. Free system disk or use a clean CI runner, then rerun `flutter test` and `flutter test --coverage`.
2. Run Android and iOS release smoke builds in the supported signing/codesigning environment.
3. Start local Supabase or use staging credentials, then run `supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error`.
4. Apply migrations to a throwaway/staging database and run `psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql`.
5. Deploy updated Edge Functions and run `tool/supabase_release_probe.sh`, `tool/supabase_whatsapp_auth_smoke.sh`, and cron/job smoke scripts.
6. Add full-history secret scanning with `gitleaks` or `trufflehog` and run it before launch.
7. Verify deployed web headers with `curl -I` for each origin, including `/index.html` and static assets.
