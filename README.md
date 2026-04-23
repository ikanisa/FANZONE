# FANZONE

FANZONE is a free football prediction app built around a lean historical-data model, simple match picks, and in-app token rewards.

It is not a betting product, a sportsbook, or an odds engine. Users make free picks for fun, earn in-app rewards, and follow selected competitions through a Supabase-backed Flutter app and admin console.

## Repo Surfaces

- Flutter mobile app in `lib/`
- React/Vite admin console in `admin/`
- Supabase schema, SQL verification, and Edge Functions in `supabase/`

## Current Product Model

The production source of truth now centers on:

- `competitions`
- `seasons`
- `teams`
- `team_aliases`
- `matches`
- `standings`
- `team_form_features`
- `predictions_engine_outputs`
- `user_predictions`
- `token_rewards`

The prediction system focuses on:

- home / draw / away
- over 2.5 goals
- both teams to score
- optional scoreline guidance
- simple historical form and standings context

The platform deliberately excludes:

- bookmaker odds
- betting markets
- xG and advanced event warehouses
- player-level and lineup data
- weather, injury, and suspension modeling
- legacy pool, slip, jackpot, and daily-challenge settlement logic

## 2026-04-22 Lean Refactor Status

The repository has been refactored to a single lean prediction model:

- Supabase schema cut over to the new football domain
- legacy prediction tables, settlement RPCs, odds ingestion, and advanced match satellites removed from the backend source of truth
- `/predict` is the single prediction entry surface in the mobile app
- CSV-based import readiness added for competitions, seasons, teams, aliases, matches, and standings
- simple feature generation and prediction generation jobs added
- user prediction scoring and reward issuance moved to lean match-result based flows

Residual legacy files that still exist outside the live path are treated as archival or compatibility shims and are not the active product contract. Use the docs below as the current source of truth.

## Architecture Summary

```text
Flutter app
  -> Riverpod providers / feature gateways
  -> Supabase client
  -> lean football views, RPCs, and user prediction flows

Admin app
  -> React Router + TanStack Query
  -> Supabase browser client
  -> fixture result entry, import oversight, prediction monitoring

Supabase
  -> normalized football schema
  -> RLS policies
  -> import / feature / prediction / scoring RPCs
  -> Edge Functions for import, prediction generation, scoring, alerts
```

## Key Backend Jobs

- `generate-predictions`
  - generates lean engine outputs for upcoming fixtures
- `score-predictions`
  - scores pending user predictions after full-time results are entered
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

### Admin app

```bash
cd admin
npm ci
npm run dev
```

### Supabase

Apply migrations with your normal Supabase workflow, then deploy the lean Edge Functions:

```bash
supabase db push
supabase functions deploy generate-predictions
supabase functions deploy score-predictions
supabase functions deploy import-football-data
supabase functions deploy dispatch-match-alerts
```

Edge runtime notes:

- `generate-predictions`, `score-predictions`, and `import-football-data` are designed for shared-secret job execution via `x-cron-secret`.
- these jobs are internal runtime surfaces, not external bearer-triggered endpoints

For the consolidated historical fixtures export, use the local loader instead of hand-pushing raw rows:

```bash
python3 tool/import_matches_all_csv.py \
  --csv "/path/to/Matches - ALL.csv" \
  --db-url "$SUPABASE_DB_URL" \
  --apply
```

## Verification

Flutter:

```bash
flutter analyze
flutter test
```

Admin:

```bash
cd admin
npm run lint
npm run build
npm run test
```

Edge Functions:

```bash
deno check supabase/functions/generate-predictions/index.ts
deno check supabase/functions/score-predictions/index.ts
deno check supabase/functions/import-football-data/index.ts
deno check supabase/functions/dispatch-match-alerts/index.ts
```

## Documentation

- [Lean Prediction Audit Report](docs/lean-prediction-audit-report-2026-04-22.md)
- [Lean Prediction Architecture](docs/lean-prediction-architecture.md)
- [Lean Prediction Import Workflow](docs/lean-prediction-import-workflow.md)
- [Lean Prediction Engine](docs/lean-prediction-engine.md)
- [Lean Prediction Migration Notes](docs/lean-prediction-migration-notes.md)
- [Lean Prediction Cleanup Report](docs/lean-prediction-cleanup-report.md)
- [Lean Prediction Production Checklist](docs/lean-prediction-production-checklist.md)

## Historical Documents

Documents dated before `2026-04-22` may still describe pools, slips, jackpots, odds ingestion, or other pre-refactor structures. Treat them as historical context only unless they have been explicitly updated after the lean cutover.
