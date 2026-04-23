# Lean Prediction Production Checklist

## Schema

- [ ] the single baseline migration `20260423050000_lean_prediction_baseline.sql` is applied
- [ ] legacy pool, slip, market, odds, and advanced-stat tables absent from production
- [ ] `app_matches` is the only active fixture projection
- [ ] legacy team/match compatibility views and RPCs absent from production

## Data

- [ ] competitions imported
- [ ] seasons imported
- [ ] teams imported
- [ ] team aliases imported
- [ ] matches imported with valid statuses and result codes
- [ ] standings snapshots imported

## Backend Jobs

- [ ] `import-football-data` deployed
- [ ] `generate-predictions` deployed
- [ ] `score-predictions` deployed
- [ ] `dispatch-match-alerts` deployed
- [ ] prediction/import jobs accept only `x-cron-secret`
- [ ] job callers use `x-cron-secret`
- [ ] scheduled jobs point to lean prediction functions only

## Mobile App

- [ ] `/predict` is the only live prediction hub
- [ ] retired pool and jackpot routes redirect correctly
- [ ] match detail shows lean sections only
- [ ] notification routing lands on `/predict`, `/match/:id`, or other valid lean destinations

## Admin

- [ ] fixtures page uses lean result-entry flow
- [ ] predictions page reads engine outputs and user prediction participation
- [ ] no active challenge or pool settlement UI remains in the main operator path

## Verification

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `cd admin && npm run lint`
- [ ] `cd admin && npm run build`
- [ ] `cd admin && npm run test`
- [ ] relevant `deno check` and function tests

## Product Guardrails

- [ ] no betting copy in live app flows
- [ ] no odds logic in active prediction surfaces
- [ ] no advanced paid-data dependency in required operations
- [ ] reward issuance remains tied to free prediction participation only
