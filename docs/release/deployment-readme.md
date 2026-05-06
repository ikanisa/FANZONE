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
supabase functions deploy settle-match-pools
supabase functions deploy dispatch-match-alerts
supabase functions deploy push-notify
supabase functions deploy generate-pool-social-card
supabase functions deploy import-football-data
supabase functions deploy menu_ingest_create
supabase functions deploy menu_ingest_worker
supabase functions deploy menu_ocr_parse
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
tool/supabase_rls_audit.sh
tool/supabase_fet_supply_smoke.sh
tool/supabase_edge_job_smoke.sh settle-match-pools
tool/supabase_edge_job_smoke.sh dispatch-match-alerts
```

## Web/PWA

Cloudflare Pages is the configured release path. The deploy script loads
ignored env files and refuses browser env that exposes backend secrets.

```bash
npm ci
tool/deploy_cloudflare_pages.sh website venue-portal tv-display admin
```

Expected production domains:

- Public PWA: `https://fanzone.ikanisa.com`
- Venue dashboard: configured Cloudflare Pages/custom domain.
- TV display: configured Cloudflare Pages/custom domain, commonly
  `https://screen.fanzone.ikanisa.com`.
- Admin: internal operations domain only.

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
Supabase fixes for already-applied migrations. Never delete orders, wallet
ledger rows, settlement rows, or audit history as a rollback mechanism.
