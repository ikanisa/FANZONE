# FANZONE

FANZONE is a sports-bar entertainment platform for venues, lounges, fan zones, and hospitality operators.

The Flutter client uses the standalone `FANZONEUI` export as the primary product and UI reference. Production screens should implement those concepts through real app data, Supabase gateways, loading states, and empty states rather than hardcoded mock export data. Guests order from venue menus, earn non-cash FET loyalty rewards, join Arena challenges, and receive audited loyalty-ledger credits when challenges settle.

## Repo Surfaces

- Flutter mobile app in `lib/`
- React/Vite admin console in `apps/admin/`
- React/Vite public website/PWA in `apps/website/`
- React/Vite venue portal in `apps/venue-portal/`
- Shared TypeScript package in `packages/core/`
- Supabase schema, SQL verification, and Edge Functions in `supabase/`

## Current Product Model

The production source of truth now centers on:

- `competitions`
- `seasons`
- `teams`
- `team_aliases`
- `matches`
- `standings`
- `curated_matches`
- `match_pools`
- `match_pool_camps`
- `match_pool_entries`
- `match_pool_invites`
- `match_pool_settlements`
- `fet_wallets`
- `fet_wallet_transactions`
- `venues`, `menu_categories`, `menu_items`, and order tables

The platform implementation should follow FANZONEUI concepts first while preserving production-grade data contracts:

- no hardcoded mock production flows
- no duplicated services or tables when an existing gateway can support the screen
- no static FANZONEUI sample data copied into app state
- customer payments stay off-platform through cash, MoMo/USSD instructions, or Revolut links unless a backed product decision changes that contract

## 2026-05-01 Sports-Bar Refactor Status

The repository is being refactored to the simplified sports-bar product:

- Supabase now has an additive pool engine, camps, entries, invite rewards, settlement audit rows, and curation records.
- `/pools` is the live gaming surface across mobile and website.
- Venue portal operations center on menu/order handling and venue pool monitoring.
- Admin has fixture result entry, platform controls, loyalty-ledger oversight, and match curation.
- External customer payments remain off-system; FANZONE stores instructions and manual confirmation state only.

## Architecture Summary

```text
Flutter app
  -> Riverpod providers / feature gateways
  -> Supabase client
  -> ordering, loyalty, fixtures, and match challenge flows

Admin app
  -> React Router + TanStack Query
  -> Supabase browser client
  -> fixture result entry, match curation, platform controls, loyalty-ledger oversight

Website / venue portal
  -> Vite + React workspaces
  -> Supabase browser client and Edge Functions
  -> guest pool/ordering PWA and venue operations surface

Supabase
  -> normalized football schema
  -> RLS policies
  -> match curation, challenge, loyalty-ledger, menu, and order RPCs
  -> Edge Functions for import, alerts, menu ingestion, order status, and pool settlement
```

## Key Backend Jobs

- `settle-match-pools`
  - settles eligible finished pools through idempotent loyalty-ledger mutations
- `import-football-data`
  - validates and upserts CSV or row payloads into the lean football tables
- `dispatch-match-alerts`
  - sends kickoff and final-score notifications from lean match data

## Quick Start

### Prerequisites

- Flutter stable
- Node.js 22+
- npm
- Deno 2.x
- Supabase CLI

### Flutter app

```bash
flutter pub get
flutter run --dart-define-from-file=env/development.json
```

Use a real local env file, not the tracked example file, for live backend access.
Production `env/*.json`, keystores, `google-services.json`, `GoogleService-Info.plist`,
and Play/App Store service credentials must stay out of git and be supplied by
your CI/CD or local secure secret store.

### Admin app

```bash
cd apps/admin
npm ci
npm run dev
```

### Website

```bash
cd apps/website
npm ci
npm run dev
```

### Venue portal

```bash
cd apps/venue-portal
npm install
npm run dev
```

### Supabase

Apply migrations with your normal Supabase workflow, then deploy the lean Edge Functions:

```bash
supabase db push
supabase functions deploy settle-match-pools
supabase functions deploy import-football-data
supabase functions deploy dispatch-match-alerts
supabase functions deploy menu_ingest_worker
```

Edge runtime notes:

- `settle-match-pools`, `import-football-data`, and `dispatch-match-alerts` are designed for shared-secret job execution via `x-cron-secret`.
- `menu_ingest_worker` also requires either a service-role bearer token or `x-cron-secret`.
- these jobs are internal runtime surfaces, not external bearer-triggered endpoints

Runtime config notes:

- the FET:EUR peg is controlled by `app_config_remote.fet_per_eur`
- the welcome FET loyalty balance is controlled by `app_config_remote.foundation_grant_fet`
- the daily legacy transfer limit is controlled by `app_config_remote.wallet_transfer_daily_limit`
- local currency display derives from that peg plus `currency_rates`, `country_currency_map`, and `currency_display_metadata`
- `currency_rates` are now treated as database-managed data, not an external AI refresh job
- external customer payments are off-platform; FANZONE only provides cash, MoMo USSD, or Revolut-link handoff instructions and staff/admin manual confirmation

## Release Checklist

- Run `flutter analyze` and the targeted Flutter tests before cutting a build.
- Run `cd apps/admin && npm run lint && npm test && npm run build`.
- Run `cd apps/website && npm run lint && npm run build`.
- Run `cd apps/venue-portal && npm run lint && npm run build`.
- Apply the latest Supabase migrations before deploying app builds or Edge Functions.
- Run the SQL verification scripts against a migrated database:
  `psql -f supabase/tests/bootstrap_required_objects.sql` and
  `psql -f supabase/tests/rls_hardening_audit.sql`.
- Verify anonymous users cannot join restricted challenges, manage notification settings, or transfer FET.
- Validate deep links on Android and iOS from a cold start and a warm start.
- Confirm FCM token registration, kickoff/result notifications, and session-expiry handling on real devices.
- Supply production secrets from secure local or CI-managed files only; do not commit them.

## Verification

Flutter:

```bash
flutter analyze
flutter test
```

Admin:

```bash
cd apps/admin
npm run lint
npm run build
npm run test
```

Website:

```bash
cd apps/website
npm run lint
npm run build
```

Edge Functions:

```bash
deno check supabase/functions/settle-match-pools/index.ts
deno check supabase/functions/import-football-data/index.ts
deno check supabase/functions/dispatch-match-alerts/index.ts
```

## Documentation

- [Production Documentation Index](docs/README.md)
- [Architecture Overview](docs/architecture/overview.md)
- [Apps](docs/architecture/apps.md)
- [Backend](docs/architecture/backend.md)
- [Product Simplification Audit 2026-05-01](docs/refactor/product-simplification-audit-2026-05-01.md)
- [Permissions And RLS](docs/security/permissions-rls.md)
- [Audit Logs](docs/security/audit-logs.md)
- [Go-Live Checklist](docs/release/go-live-checklist.md)
- [Rollback](docs/release/rollback.md)
- [Admin Guide](docs/operations/admin-guide.md)
- [Agent Ops](docs/operations/agent-ops.md)
- [QA/UAT](docs/testing/qa-uat.md)
- [Channels](docs/integrations/channels.md)
- [Payments](docs/integrations/payments.md)
