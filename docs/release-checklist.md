# Production Release Checklist

## Current Android snapshot

- Latest validated Android handoff: [android-release-handoff-2026-04-19.md](/Volumes/PRO-G40/FANZONE/docs/android-release-handoff-2026-04-19.md:1)
- Current production Android package: `app.fanzone.football`
- Current release version: `1.1.0+6`
- Current Android release artifacts:
  - `build/app/outputs/flutter-apk/app-release.apk`
  - `build/app/outputs/bundle/release/app-release.aab`

## Required before shipping

- Audit Supabase auth, RLS, storage rules, edge functions, migrations, backups, and rollback paths in the production project.
- Review `ios/Flutter/AppConfig.xcconfig` and confirm the bundle ID, team ID, and APNs environment are correct for release signing.
- Create a local `env/production.json` from `env/production.example.json` and keep `ENABLE_GLOBAL_CHALLENGES=false` until the weekly jackpot backend is live.
- Replace all placeholder values in your local `env/production.json` and the platform signing/Firebase files before promoting a build.

## Android release

- Confirm `./tool/build_android_release_from_env.sh production` succeeds.
- Confirm `./tool/build_android_aab_from_env.sh production` succeeds.
- Verify the resulting APK or AAB is signed with the upload keystore.
- Upload the signing keystore to secure secrets storage and CI.
- Run `./tool/supabase_release_probe.sh` against production credentials before enabling live rollout.
- Run `./tool/supabase_whatsapp_auth_smoke.sh` against production credentials before enabling live rollout.

## iOS release

- Confirm `ios/Runner/GoogleService-Info.plist` is the production Firebase config.
- Run `./tool/build_ios_release_from_env.sh production` and fix any fail-fast validation before opening Xcode.
- Open the Runner target in Xcode and confirm signing, push notifications, and background remote notifications resolve without manual overrides.
- Archive a production build and validate install on a physical device.
- Validate push delivery and notification tap routing on at least one physical iPhone.

## Backend validation

- Verify production credentials point to the correct Supabase project.
- Confirm feature flags match the live backend, especially notifications, deep linking, and jackpot/global challenge rollout.
- Validate `fet_wallets`, `fet_wallet_transactions`, and `public_leaderboard` exist and are covered by policy.
- Confirm built-in Supabase email, phone OTP, magic link/OAuth, and third-party auth providers are disabled for the production project. Anonymous sign-in may remain enabled only for the mobile guest flow.
- Run `./tool/supabase_rls_audit.sh` with `SUPABASE_DB_PASSWORD` set and keep the successful output with the release ticket.
- Run `./tool/supabase_fet_supply_smoke.sh` with `SUPABASE_DB_PASSWORD` set and keep the successful output with the release ticket.
- Review `docs/fet-supply-governance.md` before any manual minting or promotional credit.
- Check `public.fet_supply_overview.remaining_mintable` before any manual grant, promo credit, or reward backfill.
- Validate WhatsApp OTP delivery, expiry, and rate-limit behaviour in the production `whatsapp-otp` function.
- Confirm `WABA_ACCESS_TOKEN`, `WABA_PHONE_NUMBER_ID`, and `SUPABASE_JWT_SECRET` are present in the deployed Edge Function secrets.

## Operational readiness

- `ci.yml` is the canonical mobile/backend pipeline. Keep its build flags aligned with `env/production.example.json`.
- Validate the current error-reporting path for the release build. The mobile app now queues runtime errors locally and flushes them to the Supabase-backed telemetry RPC `log_app_runtime_errors_batch`; confirm the migration is applied and operators know where to inspect `app_runtime_errors`.
- Validate notification tokens are registering and `push-notify` can dispatch from production credentials.
- Confirm release notes, privacy disclosures, and support contact details are ready.
