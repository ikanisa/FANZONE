# FANZONE Agent Guide

This repo is a production sports-bar and hospitality platform. Work additively, preserve existing release surfaces, and do not delete or replace working code unless a migration plan and validation evidence already exist.

## Repo Layout

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter customer mobile app. |
| `apps/admin/` | Existing React/Vite platform admin console. Keep active until Flutter Web replacement reaches parity. |
| `apps/venue-portal/` | Existing React/Vite venue operations and staff console. |
| `apps/website/` | React/Vite guest web/PWA surface. |
| `apps/tv-display/` | React/Vite venue TV display surface. |
| `packages/core/` | Shared TypeScript contracts for web apps. |
| `supabase/migrations/` | Append-only schema, RLS, RPC, trigger, view, and grant migrations. |
| `supabase/functions/` | Supabase Edge Functions. |
| `supabase/tests/` | SQL contract, RLS, and backend verification scripts. |
| `docs/` | Architecture, security, operations, testing, and release documentation. |
| `tool/` | Release, Supabase, validation, and evidence scripts. |
| `env/*.example.json` | Example Flutter runtime config only. Real `env/*.json` files stay ignored. |

## Product Rules

- FANZONE is not a betting, gambling, cash-out, odds, or wagering platform.
- FET is a non-cash loyalty and rewards points ledger, not a fintech wallet or cash-equivalent balance.
- Customer payment execution stays off-platform: cash, manual mobile-money instructions, external POS/Revolut-link handoff, or future provider integration after an explicit product decision.
- Clients must never receive Supabase service-role keys or privileged integration secrets.
- Table-number ordering is the current production default. Optional table sessions must be server-validated and must not reintroduce open QR ordering as a required dependency.
- Existing React admin and venue surfaces remain active while any Flutter Web admin replacement is built in parallel.

## Architecture Conventions

- Prefer feature-first Flutter modules under `lib/features/<domain>/`.
- Keep presentation, provider/controller, gateway/repository, model, and infrastructure concerns separated.
- Use `go_router` for routes, deep links, and guarded navigation.
- Use Riverpod for testable state and dependency injection.
- Use generated immutable models where the repo already has generated model patterns.
- Use Supabase Edge Functions or Postgres RPCs for sensitive or multi-row mutations.
- Use append-only migrations for deployed database changes.
- Reuse existing design tokens and components before adding new abstractions.
- Add a package only when at least two app surfaces actually need the same code.

## Security Rules

- Enable and test RLS for any table exposed to clients.
- Venue/staff/admin mutations must enforce venue membership or platform admin roles server-side.
- Customer reads and writes must be scoped to the authenticated user, joined table/session context, or public venue/menu/event data.
- Sensitive state changes require audit evidence: order status, manual payment, refund/void, reward redemption, game settlement, staff/admin override, role changes, and config changes.
- No destructive migration belongs in the normal migration chain without an explicit backup, rollback plan, and release note.
- Do not commit production env files, signing files, Firebase service files, database URLs, service-role keys, or provider tokens.

## Commands

Flutter:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool
./tool/flutter_analyze_release.sh
flutter test
flutter build apk --debug
```

Web workspaces:

```bash
npm ci
npm run typecheck --workspaces --if-present
npm run lint --workspaces --if-present
npm run test --workspaces --if-present
npm run build --workspaces --if-present
```

Supabase and Edge Functions:

```bash
supabase db push --dry-run
./tool/supabase_rls_audit.sh
./tool/supabase_fet_supply_smoke.sh
deno fmt --check supabase/functions
find supabase/functions -name '*.ts' -print0 | xargs -0 deno check
deno test --allow-env supabase/functions
```

Release checks:

```bash
./tool/product_boundary_scan.sh
./tool/go_live_readiness.sh --local
./tool/check_world_class_evidence.sh
```

Use linked Supabase validation when local Docker/Supabase is unavailable.

## Testing Strategy

- Add Flutter unit/widget tests for route guards, providers, models, order flows, game flows, and design-system behavior.
- Add integration tests for venue discovery, table-number order placement, payment handoff, order tracking, loyalty rewards, and entertainment entry.
- Add SQL tests for RLS, cross-venue isolation, cross-user isolation, mutation grants, and audited RPC behavior.
- Add Edge Function tests for CORS, auth, input validation, privileged operations, and failure responses.
- Add web/admin tests for route guards, role checks, data tables, mutation dialogs, and build metadata.
- Add product-boundary checks when changing entertainment or payment copy.

## Definition Of Done

- The changed customer app surface compiles and passes targeted tests.
- The affected web/admin/venue surface type-checks, lints, and builds.
- Supabase migrations apply cleanly or dry-run cleanly.
- New RLS/RPC/function behavior has verification coverage.
- No betting/gambling/cash-out/odds/customer-wallet behavior is introduced.
- No service-role secret or production credential is exposed to client code.
- Docs and runbooks reflect any new operational behavior.
- Release evidence states what was verified and what remains unverified.
