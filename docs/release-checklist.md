# Production Release Checklist

## Current Android Snapshot

- Latest validated Android release artifacts must be regenerated from the current sports-bar pool build before store submission.
- Current production Android package: `app.fanzone.football`
- Current release version: `1.1.2+10`
- Current Android release artifacts:
  - `build/app/outputs/flutter-apk/app-release.apk`
  - `build/app/outputs/bundle/release/app-release.aab`

## Required before shipping

- Audit Supabase auth, RLS, storage rules, edge functions, migrations, backups, and rollback paths in the production project.
- Review `ios/Flutter/AppConfig.xcconfig` and confirm the bundle ID, team ID, and APNs environment are correct for release signing.
- Create a local `env/production.json` from `env/production.example.json` and keep `/pools` as the live fan engagement surface.
- Configure Cloudflare Pages projects for website, admin, venue dashboard, and TV display before launch.
- Use local Cloudflare deploys through `tool/deploy_cloudflare_pages.sh`; GitHub Actions are manual-only fallbacks and must not be required for release.
- Keep the app-store handoff package in `release/` aligned with the final production build.
- Replace all placeholder values in your local `env/production.json` and the platform signing/Firebase files before promoting a build.

## Android release

- Run `./tool/preflight_build_check.sh production`.
- Confirm `./tool/build_android_release_from_env.sh production` succeeds.
- Confirm `./tool/build_android_aab_from_env.sh production` succeeds.
- Verify the resulting APK or AAB is signed with the upload keystore.
- Upload the signing keystore to secure secrets storage and CI.
- Run `./tool/supabase_release_probe.sh` against production credentials before enabling live rollout.
- Run `./tool/supabase_whatsapp_auth_smoke.sh` against production credentials before enabling live rollout.

## iOS release

- Confirm `ios/Runner/GoogleService-Info.plist` is the production Firebase config.
- Confirm Apple Team ID `63STJ5N27W` is set in the ignored local `ios/Flutter/AppConfig.xcconfig`.
- Run `./tool/build_ios_release_from_env.sh production` and fix any fail-fast validation before opening Xcode.
- Use `FANZONE_IOS_FORCE_UNSIGNED=1 ./tool/build_ios_release_from_env.sh production` only for compile/archive verification when Apple signing assets are not available on the build machine.
- Open the Runner target in Xcode and confirm signing, push notifications, and background remote notifications resolve without manual overrides.
- Archive a production build and validate install on a physical device.
- Validate push delivery and notification tap routing on at least one physical iPhone.

## Web and PWA release

- Confirm `npm run build -w @fanzone/website` succeeds.
- Confirm `npm run build -w @fanzone/admin` succeeds.
- Confirm `npm run build -w @fanzone/venue-portal` succeeds.
- Confirm `npm run build -w @fanzone/tv-display` succeeds.
- Confirm browser release env with `./tool/validate_web_release_env.sh venue-portal` and `./tool/validate_web_release_env.sh tv-display`.
- Configure local Cloudflare Wrangler access and optional project-name env vars for `tool/deploy_cloudflare_pages.sh`.
- Verify deep route refresh works for public web, venue dashboard, and TV screen routes after deploy.

## Backend validation

- Verify production credentials point to the correct Supabase project.
- Confirm feature flags match the live backend, especially notifications, deep linking, venue ordering, and pool rollout.
- Validate `fet_wallets`, `fet_wallet_transactions`, `match_pools`, `match_pool_entries`, `match_pool_settlements`, and `pool_operation_audit_logs` exist and are covered by policy.
- Confirm built-in Supabase email, phone OTP, magic link/OAuth, and third-party auth providers are disabled for the production project. Anonymous sign-in may remain enabled only for the mobile guest flow.
- Run `./tool/supabase_live_validation.sh` with `SUPABASE_DB_URL`, `SUPABASE_DB_PASSWORD`, or an authenticated linked Supabase CLI profile, and keep the successful output with the release ticket.
- Review `docs/fet-supply-governance.md` before any manual minting or promotional credit.
- Check `public.fet_supply_overview.remaining_mintable` before any manual grant, promo credit, or reward backfill.
- Validate WhatsApp OTP delivery, expiry, and rate-limit behaviour in the production `whatsapp-otp` function.
- Confirm `WABA_ACCESS_TOKEN`, `WABA_PHONE_NUMBER_ID`, and `SUPABASE_JWT_SECRET` are present in the deployed Edge Function secrets.
- For store submission builds, also confirm `WHATSAPP_AUTH_TEST_PHONE=+35699711145`, `WHATSAPP_AUTH_TEST_OTP=123456`, and a short-lived `WHATSAPP_AUTH_TEST_EXPIRY` are present in the deployed `whatsapp-otp` secrets.
- Run `WHATSAPP_AUTH_TEST_PHONE=+35699711145 WHATSAPP_AUTH_TEST_OTP=123456 WHATSAPP_AUTH_TEST_EXPIRY=<future-iso-timestamp> ./tool/supabase_whatsapp_auth_smoke.sh` and keep the successful output with the release ticket.

## Reviewer app access

- Dedicated review/test phone number: `+35699711145`
- Dedicated review/test OTP: `123456`
- Reviewer flow: launch the submitted build, enter `+35699711145`, tap `SEND OTP`, then enter `123456`.
- This path is powered by the deployed `whatsapp-otp` function secrets above. If those secrets are missing, reviewer login will fail even if the app build is correct.

## Store submission package

- Android: `release/android/play-store-metadata.md`, `release/android/data-safety-notes.md`, and `release/android/app-access-instructions.md`.
- iOS: `release/ios/app-store-metadata.md`, `release/ios/app-review-notes.md`, and `release/ios/privacy-label-notes.md`.
- Legal: `release/legal/privacy-policy.md`, `release/legal/terms.md`, and `release/legal/fet-reward-terms.md`.
- QA: `release/qa/production-uat-report.md` and `release/qa/release-checklist.md`.

## Operational readiness

- `ci.yml` is the canonical mobile/backend pipeline. Keep its dart-define keys aligned with `env/production.example.json`.
- Validate the current error-reporting path for the release build. The mobile app now queues runtime errors locally and flushes them to the Supabase-backed telemetry RPC `log_app_runtime_errors_batch`; confirm the migration is applied and operators know where to inspect `app_runtime_errors`.
- Validate notification tokens are registering and `push-notify` can dispatch from production credentials.
- Confirm release notes, privacy disclosures, and support contact details are ready for the sports-bar pool product.
