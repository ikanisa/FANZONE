# FANZONE Deployment README

This repo uses ignored local env files or a secret manager for production
values. Do not commit real `.env`, `.env.staging`, `.env.production`,
`env/*.json`, `android/key.properties`, keystores, Firebase plist/json files, or
Supabase service-role credentials.

## Environment Files

- `.env.example`: local/development release tooling template.
- `.env.staging.example`: staging release tooling template.
- `.env.production.example`: production release tooling template.
- `supabase/.env.example`: Supabase Edge Function secrets template.
- `env/development.example.json`, `env/staging.example.json`,
  `env/production.example.json`: Flutter `--dart-define-from-file` templates.
- `apps/*/.env.example`: browser-safe Vite templates.

Validate a real release env before building:

```bash
tool/validate_release_env.sh staging --all
tool/validate_release_env.sh production --all
tool/validate_web_release_env.sh website
tool/validate_web_release_env.sh venue-portal
tool/validate_web_release_env.sh tv-display
tool/validate_web_release_env.sh admin
```

## Supabase

```bash
supabase db push --dry-run --db-url "$SUPABASE_DB_URL"
supabase db push --db-url "$SUPABASE_DB_URL"
supabase secrets set --env-file supabase/.env.production
supabase functions deploy whatsapp-otp
supabase functions deploy order_create
supabase functions deploy order_mark_paid
supabase functions deploy order_update_status
supabase functions deploy payment-hub
supabase functions deploy ring_bell
supabase functions deploy settle-match-pools
supabase functions deploy dispatch-match-alerts
supabase functions deploy sync-livescore-football
supabase functions deploy fan-trivia
supabase functions deploy song-guess
supabase functions deploy music-bingo
supabase functions deploy generate-weekly-game-packs
supabase functions deploy push-notify
supabase functions deploy generate-pool-social-card
supabase functions deploy import-football-data
supabase functions deploy menu_ingest_create
supabase functions deploy menu_ingest_worker
supabase functions deploy menu_ocr_parse
```

Hospitality Core Phase 2 currently has four ordered Supabase migrations:

1. `20260522150000_order_lifecycle_hardening.sql`
2. `20260523120000_manual_payment_reconciliation.sql`
3. `20260523130000_staff_call_acknowledgement_rpc.sql`
4. `20260523140000_manual_payment_note_requirement.sql`

Before applying them, capture a production backup and run the dry run:

```bash
tool/create_supabase_backup_evidence.sh
supabase db push --dry-run --db-url "$SUPABASE_DB_URL"
```

If using a linked Supabase CLI project instead of `SUPABASE_DB_URL`, confirm
`SUPABASE_DB_PASSWORD` is current before running `supabase db push --dry-run`.
The query-based smoke scripts can fall back to `supabase db query --linked`,
but migration dry-runs still need valid database credentials.

After applying migrations through the normal release process, collect both
readiness and rollback-contract evidence:

```bash
tool/supabase_hospitality_core_phase2.sh --readiness
tool/supabase_hospitality_core_phase2.sh --contract
```

Before deploying Edge Functions, confirm `supabase/.env.production` includes
the production browser allowlist:

```bash
FANZONE_EDGE_ALLOWED_ORIGINS=https://fanzone.ikanisa.com,https://admin.example.com,https://venues.example.com,https://screen.example.com
FANZONE_EDGE_ALLOW_WILDCARD_CORS=false
```

Use exact deployed origins. Do not use `*` for production CORS.

Run backend release probes after deployment:

```bash
tool/supabase_release_probe.sh
tool/supabase_live_validation.sh
tool/supabase_whatsapp_auth_smoke.sh
tool/supabase_hospitality_core_phase2.sh --readiness
tool/supabase_hospitality_core_phase2.sh --contract
tool/supabase_edge_job_smoke.sh
tool/scheduler_payload_smoke.sh
tool/supabase_app_edge_smoke.sh
tool/supabase_game_edge_smoke.sh
```

For a single production evidence bundle after the individual probes pass, run:

```bash
tool/collect_world_class_evidence.sh
```

The collector captures WhatsApp OTP, app Edge Function, game Edge Function,
cron, deployed web, live Supabase, backup, and secret-scan evidence. A launch
approval run must complete without `PENDING` or `FAIL`.

`tool/supabase_live_validation.sh` uses `SUPABASE_DB_URL` when available.
If a DB URL is not available, it falls back to the linked Supabase CLI project
and runs SQL audits through `supabase db query --linked`. This still requires a
locally authenticated Supabase CLI profile with access to the release project.

## Web/PWA

Cloudflare Pages is the configured release path. The deploy script loads
ignored env files and refuses browser env that exposes backend secrets.
Admin and venue dashboard production builds emit a Pages `_worker.js` BFF that
mediates privileged Supabase access through same-origin HttpOnly cookies.
Configure each Cloudflare Pages project with runtime variables available to
Functions/Workers:

```bash
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_PRIVILEGED_SESSION_MODE=bff
```

Do not set `VITE_PRIVILEGED_SESSION_MODE=browser` for production admin or
venue releases.

```bash
npm ci
tool/deploy_cloudflare_pages.sh website venue-portal tv-display admin
```

Expected production domains:

- Guest PWA: `https://fanzone.guest.ikanisa.com`
- Public website: `https://fanzone.ikanisa.com`
- Venue dashboard: `https://fanzone.venue.ikanisa.com`
- TV display: `https://fanzonetv.ikanisa.com`
- Admin: `https://fanzoneadmin.ikanisa.com`

## Flutter Mobile

Create ignored Flutter env and signing files before release:

```bash
cp env/production.example.json env/production.json
cp android/key.properties.example android/key.properties
cp ios/Flutter/AppConfig.xcconfig.example ios/Flutter/AppConfig.xcconfig
```

Then fill real values through local secret storage.

```bash
tool/preflight_build_check.sh production
flutter clean
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
tool/build_android_aab_from_env.sh production
tool/build_ios_release_from_env.sh production
```

## Rollback

Use `docs/release/rollback.md`. Prefer feature flags and forward-compatible
Supabase fixes for already-applied migrations. Never delete orders, FET rewards
ledger rows, settlement rows, or audit history as a rollback mechanism.
