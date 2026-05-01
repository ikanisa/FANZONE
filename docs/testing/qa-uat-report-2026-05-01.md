# QA/UAT Report - 2026-05-01

## Scope

QA covered the refactored sports-bar platform surfaces: Flutter mobile guest app, venue dashboard, admin PWA, FET wallet and rewards, pool sharing, automated settlement, Edge Functions, RLS/security posture, and performance readiness.

Status key:

- `PASS`: directly executed and passed in this environment.
- `PARTIAL`: static, unit, widget, browser smoke, or code-path coverage passed, but live end-to-end UAT still needs a seeded backend/device/session.
- `BLOCKED`: could not be executed because a required environment dependency was unavailable.

## Environment

- Repo: `/Volumes/PRO-G40/FANZONE`
- Date: 2026-05-01
- Local Supabase database was unavailable. `supabase status`, `supabase db lint --local`, and `supabase test db ...` could not connect to `127.0.0.1:54322`.
- Admin, venue, and website PWAs were built and smoke-tested from local Vite preview servers.
- Worktree already contained broad refactor changes before QA. QA fixes in this pass were limited to wallet RPC grants and venue portal no-env rendering.

## Automated Checks

| Check | Result | Notes |
| --- | --- | --- |
| `git diff --check` | PASS | No whitespace/check errors. |
| `npm run typecheck --workspaces --if-present` | PASS | Admin, venue portal, website, and core type checks passed. |
| `npm run lint --workspaces --if-present` | PASS | Workspace lint passed. Venue lint was rerun after the QA fix and passed. |
| `npm run test --workspaces --if-present` | PASS | Admin and website test suites passed. |
| `npm run build --workspaces --if-present` | PASS | Admin, venue portal, and website production builds passed. Venue build was rerun after the QA fix and passed. |
| `flutter analyze` | PASS | No analyzer issues found. |
| `flutter test` | PASS | Full Flutter test suite passed, 217 tests. |
| `deno test --allow-env supabase/functions/_shared/*_test.ts supabase/functions/*/*_test.ts` | PASS | 27 Edge/shared tests passed. |
| `find supabase/functions -name '*.ts' ... deno check` | PASS | All Edge Function TypeScript files checked successfully. |
| Playwright/Chromium PWA smoke | PARTIAL | Admin and website rendered. Venue initially rendered blank, then passed after the QA fix. Screenshots are in `output/playwright/`. |
| `supabase db lint --local` | BLOCKED | Local Postgres on `127.0.0.1:54322` refused connection. |
| `supabase test db supabase/tests/pool_settlement_engine.sql` | BLOCKED | Same local DB connectivity issue. |
| `supabase test db supabase/tests/rls_hardening_audit.sql` | BLOCKED | Same local DB connectivity issue. |

## Mobile UAT Checklist

| Scenario | Status | Evidence/Next Step |
| --- | --- | --- |
| User opens app without QR | PARTIAL | Flutter app/widget tests passed. Needs physical device or simulator smoke against release config. |
| User opens app from venue/table QR | PARTIAL | QR/session routing code compiles and tests pass. Needs live QR token and seeded venue table. |
| User views menu | PARTIAL | Menu UI/repository paths compile and tests pass. Needs seeded Supabase menu data. |
| User creates order | PARTIAL | Order UI and Edge Function checks pass. Needs live venue/table/user. |
| User earns FET from order | BLOCKED | Requires wallet/order RPC execution against DB. |
| User views FET wallet | PARTIAL | Wallet UI tests and analyzer pass. Live ledger requires DB. |
| User creates pool | PARTIAL | Pool screens/repository compile and tests pass. Live RPC blocked. |
| User shares pool URL | PARTIAL | Sharing/social card function checks pass. Live URL/storage generation requires DB and storage. |
| Another user joins through shared URL | BLOCKED | Requires two live/seeded users and invite state. |
| User stakes FET | BLOCKED | Requires wallet ledger RPC and DB transaction. |
| User sees live pool stats | PARTIAL | Client paths compile; live realtime/load behavior not measured. |
| Match result finalizes | BLOCKED | Requires admin/system DB action. |
| Pool settles | BLOCKED | Settlement SQL test could not run without DB. |
| Winner receives FET | BLOCKED | Requires settlement ledger verification. |
| Loser loses stake | BLOCKED | Requires settlement ledger verification. |
| User spends FET on bar order if venue allows | BLOCKED | Requires venue redemption config and wallet/order RPC. |
| Insufficient FET error works | BLOCKED | Requires wallet debit RPC execution. |
| Cancelled match refund works | BLOCKED | Requires cancelled match settlement/refund SQL execution. |

## Venue Dashboard UAT Checklist

| Scenario | Status | Evidence/Next Step |
| --- | --- | --- |
| Venue logs in | PARTIAL | Venue PWA builds/lints. Live auth requires configured Supabase and seeded venue user. |
| Venue sees only own data | BLOCKED | Requires RLS test against DB. |
| Venue creates/edits menu item | PARTIAL | Menu architect UI builds. Live mutation blocked by missing DB/session. |
| Venue sets FET reward percentage | PARTIAL | Rewards UI/RPC path builds. Live persistence blocked. |
| Venue receives order | BLOCKED | Requires live mobile order flow and DB. |
| Venue marks order served | PARTIAL | UI/Edge paths compile. Live mutation blocked. |
| Venue marks order paid manually | PARTIAL | RPC path compiles. Live audit verification blocked. |
| Manual payment audit log is created | BLOCKED | Requires DB assertion. |
| Venue creates venue pool | PARTIAL | Venue pool UI builds. Live RPC blocked. |
| Venue cannot create duplicate pool for same match | BLOCKED | Requires unique index/RPC assertion against DB. |
| Venue endorses/rejects user-created venue pool | PARTIAL | UI/RPC path builds. Live permission check blocked. |
| Venue generates table QR | PARTIAL | UI builds. Live token/QR generation blocked. |

## Admin PWA UAT Checklist

| Scenario | Status | Evidence/Next Step |
| --- | --- | --- |
| Admin manages countries | PARTIAL | Admin typecheck/test/build passed. Live CRUD blocked. |
| Admin manages competitions | PARTIAL | Admin typecheck/test/build passed. Live CRUD blocked. |
| Admin manages teams | PARTIAL | Admin typecheck/test/build passed. Live CRUD blocked. |
| Admin curates matches by country | PARTIAL | Curation UI/build passed. Live persistence blocked. |
| Admin features World Cup match | PARTIAL | Curated match paths compile. Live curated match save blocked. |
| Admin monitors pools | PARTIAL | Pool operations page builds. Live data blocked. |
| Admin updates reward rules | PARTIAL | Reward rules UI/RPC paths compile. Live audit blocked. |
| Admin triggers/retries settlement | BLOCKED | Requires admin/system DB execution. |
| Admin views wallet ledger | PARTIAL | Admin app builds. Live ledger query blocked. |
| Admin adjustment requires reason | BLOCKED | Requires DB/RPC assertion. |
| Admin views audit logs | PARTIAL | Admin app builds. Live audit rows blocked. |
| Admin feature flags work | PARTIAL | Admin app builds. Live persistence blocked. |

## Security Checklist

| Scenario | Status | Evidence/Next Step |
| --- | --- | --- |
| User cannot update wallet balance directly | PARTIAL | Fixed direct `authenticated` execute grant on `wallet_post_transaction`; added audit assertion. Runtime SQL test is blocked. |
| User cannot settle pool | PARTIAL | Static grant review shows settlement functions restricted to backend/service/admin wrappers. Runtime SQL test is blocked. |
| User cannot edit another user's pool entry | BLOCKED | Requires RLS SQL test. |
| Venue cannot view other venue orders | BLOCKED | Requires RLS SQL test. |
| Venue cannot edit global reward rules | BLOCKED | Requires RLS/RPC SQL test. |
| Admin-only routes are protected | PASS | Admin test suite passed and smoke renders auth gate. |
| RLS policies enforce access | BLOCKED | SQL audit could not run without DB. |
| Settlement is idempotent | PARTIAL | Settlement function uses idempotency keys and duplicate guards; SQL settlement test blocked. |
| Creator reward cannot be duplicated | PARTIAL | Unique invite/reward paths exist; SQL reward test blocked. |
| Self-invite abuse is blocked where possible | PARTIAL | Static join/reward code review covers self-reward prevention; live DB test blocked. |

## Performance Checklist

| Area | Status | Notes |
| --- | --- | --- |
| Pool list loads fast | PARTIAL | Indexes exist for `match_pools` by match/status, country/status, and venue/status. No live timing without DB. |
| Match list loads fast | PARTIAL | Match and curated-match date/status indexes exist. No live timing without DB. |
| Wallet ledger paginates | PARTIAL | Wallet transaction indexes exist by user/date, type/date, pool, order, venue, and idempotency. Live pagination timing blocked. |
| Admin tables paginate | PARTIAL | Admin/client code builds; live query timing blocked. |
| Live pool stats do not overload database | PARTIAL | Entry indexes exist by pool/status, camp, and user/date. Needs realtime/load test. |
| Add indexes where required | PASS | Static review found required core wallet, pool, settlement, order, match, venue, and share-event indexes present. No new performance index was required in this pass. |

## Browser Smoke

| Surface | Result | Notes |
| --- | --- | --- |
| Admin PWA | PASS | `output/playwright/admin-mobile-smoke.png` rendered WhatsApp verification gate with no console errors in Python smoke. |
| Venue PWA | FAIL, then PASS | Initial smoke showed a blank page with `supabaseUrl is required`; fixed to render a configuration error screen. Confirmed in `output/playwright/venue-mobile-smoke-fixed.png`. |
| Website/PWA fallback | PASS | `output/playwright/website-mobile-smoke.png` rendered the feature-control unavailable state with no console errors in Python smoke. |

## Bugs Fixed

- Hardened the wallet ledger mutation RPC in `supabase/migrations/20260501162000_wallet_rpc_grant_hardening.sql`: `wallet_post_transaction` is no longer directly executable by `anon` or `authenticated`; `service_role` keeps execute access.
- Extended `supabase/tests/rls_hardening_audit.sql` so direct wallet mutation and backend settlement functions fail the audit if exposed to client roles again.
- Fixed the venue dashboard blank screen when Supabase env vars are missing. `apps/venue-portal/src/lib/supabase.ts` now lazily guards client creation, and `apps/venue-portal/src/App.tsx` renders a visible configuration error state.

## Known Issues

- Full live UAT was not completed because no local or remote Supabase database was available in this environment.
- SQL RLS, wallet, settlement, creator reward, refund, duplicate-pool, and audit-log tests are present but could not execute.
- Mobile QR/deep-link flows were not run on a simulator or physical device in this QA pass.
- PWA role UAT was limited to unauthenticated smoke screens because seeded admin/venue sessions were unavailable.
- Performance findings are static/index based only; no `EXPLAIN ANALYZE` or load test was possible without DB data.

## Release Blockers

1. Run DB lint and SQL smoke tests against a real target:
   - `supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error`
   - `psql "$SUPABASE_DB_URL" -f supabase/tests/bootstrap_required_objects.sql`
   - `psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql`
   - `psql "$SUPABASE_DB_URL" -f supabase/tests/fet_wallet_reward_engine.sql`
   - `psql "$SUPABASE_DB_URL" -f supabase/tests/pool_settlement_engine.sql`
   - `psql "$SUPABASE_DB_URL" -f supabase/tests/pool_sharing_completion.sql`
2. Complete seeded manual UAT with guest A, guest B, venue owner/manager/staff, and admin.
3. Validate production/staging env vars for mobile, admin, venue, Edge Functions, storage, social cards, and share/deep links.
4. Verify settlement, refund, wallet ledger, manual payment audit, duplicate venue pool prevention, creator reward idempotency, and insufficient-balance handling against live data.
5. Run DB performance checks with realistic pool, match, order, share-event, and ledger volumes.

## Recommended Next Sprint

- Add a deterministic UAT seed pack for two guests, one venue, one admin, menus, matches, pools, wallet balances, orders, QR tables, and share invites.
- Add CI for Supabase migrations, db lint, and SQL smoke tests on an ephemeral database.
- Add Playwright auth fixtures for admin and venue role flows.
- Add Flutter integration tests pinned to a simulator/device target for QR, ordering, wallet, pool join, and settlement readback.
- Add `EXPLAIN`/load checks for pool list, match list, wallet ledger pagination, admin tables, and live pool stats.
- Add operational monitoring for failed settlement runs, wallet reconciliation deltas, duplicate idempotency attempts, and social card generation failures.
