# Production Release Checklist

## Required before shipping

- Audit Supabase auth, RLS, storage rules, edge functions, migrations, backups, and rollback paths in the production project.
- Review `ios/Flutter/AppConfig.xcconfig` and confirm the bundle ID, team ID, and APNs environment are correct for release signing.
- Prepare a production dart-define file from `env/production.example.json` and keep `ENABLE_GLOBAL_CHALLENGES=false` until the weekly jackpot backend is live.
- Replace placeholder values such as `SENTRY_DSN=REPLACE_WITH...` before promoting a build.

## Android release

- Confirm `./tool/build_android_release_from_env.sh production` succeeds.
- Confirm `./tool/build_android_aab_from_env.sh production` succeeds.
- Verify the resulting APK or AAB is signed with the upload keystore.
- Upload the signing keystore to secure secrets storage and CI.
- Run `./tool/supabase_release_probe.sh` against production credentials before enabling live rollout.

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
- Run `./tool/supabase_rls_audit.sh` with `SUPABASE_DB_PASSWORD` set and keep the successful output with the release ticket.
- Run `./tool/supabase_fet_supply_smoke.sh` with `SUPABASE_DB_PASSWORD` set and keep the successful output with the release ticket.
- Review `docs/fet-supply-governance.md` before any manual minting or promotional credit.
- Check `public.fet_supply_overview.remaining_mintable` before any manual grant, promo credit, or reward backfill.
- Validate password reset email templates and redirect URLs.

## Operational readiness

- `ci.yml` is the canonical mobile/backend pipeline. Keep its build flags aligned with `env/production.example.json`.
- Add Sentry alert rules for crash-free sessions, startup crashes, and unhandled exceptions.
- Validate notification tokens are registering and `push-notify` can dispatch from production credentials.
- Confirm release notes, privacy disclosures, and support contact details are ready.
