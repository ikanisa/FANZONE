# FANZONE

FANZONE is a mobile-first football prediction and fan engagement platform with an internal FET token ledger, a role-gated admin console, and a Supabase-backed backend contract.

This repository contains three production surfaces:

- a Flutter mobile app for Android and iOS
- a React/Vite admin console for internal operators
- Supabase migrations, SQL verification suites, and Edge Functions that define the backend contract

## Project Overview

FANZONE combines live football discovery with fan identity, prediction mechanics, wallet-led rewards, team communities, and operator tooling.

The current codebase covers:

- live fixtures, scores, competitions, match detail, and search
- prediction pools, free prediction slips, daily challenges, and leaderboards
- FET wallet balances, transfers, and partner reward redemption
- team communities, anonymous fan identity, featured teams, and AI-curated team news
- push notifications, match alerts, privacy/account deletion workflows, and product analytics
- an internal admin console for users, fixtures, competitions, predictions, challenges, wallet oversight, partners, rewards, redemptions, moderation, notifications, analytics, audit logs, and admin access

The active product direction is a Malta-first launch with global expansion support. The schema and app already include regional market preferences, featured events, and global launch tables, while the competition scope is intentionally limited to top-flight leagues and selected global competitions.

## Current Status

- Mobile app: active development, version `1.1.0+6`
- Admin console: active development, deployable via Cloudflare Pages
- Backend contract: active and large, with migrations through `2026-04-19`
- Release hardening: in progress, with dedicated launch, audit, benchmark, and release docs under [`docs/`](docs)

Not everything in the product surface is fully live by default. Several features exist behind build-time flags or backend readiness gates, especially jackpot/global challenges, social feed, AI analysis, advanced stats, community contests, and seasonal leaderboards.

## Product Purpose And Scope

FANZONE is not a generic CMS or a simple score app. The repository implements a product stack with the following intended scope:

- consumer mobile experience for football fans
- internal token-based engagement economy using FET
- community and fan-identity mechanics around clubs
- staff-operated control plane for content, finance, moderation, and operational oversight
- Supabase-native backend with RLS, RPCs, views, and scheduled jobs

Out of scope for this repository today:

- Flutter web, desktop, or non-mobile platforms
- local Supabase emulation/configuration baked into the repo
- real-money payments or gambling flows
- third-party crash reporting; runtime failures are captured through the Supabase-backed telemetry path

## Architecture Summary

### High-level architecture

```text
Flutter mobile app
  -> Riverpod providers / services / gateways
  -> Supabase client (anon auth, RLS, RPCs, tables, views)
  -> Firebase Messaging bootstrap for push registration

React admin console
  -> React Router + TanStack Query
  -> Supabase browser client
  -> role-gated admin tables, views, and RPCs

Supabase backend contract
  -> SQL migrations
  -> RLS policies
  -> RPCs and views
  -> Deno Edge Functions
  -> SQL verification scripts

GitHub Actions
  -> CI gates
  -> admin deployment
  -> scheduled backend jobs
  -> release artifact builds
```

### Mobile architecture

The mobile app is organized around feature modules in [`lib/features/`](lib/features), with shared models, widgets, services, and providers.

Key patterns in the Flutter app:

- `GoRouter` for shell + nested route navigation
- `flutter_riverpod` for state/query orchestration
- `get_it` + `injectable` for DI bootstrapping
- gateway abstractions for Supabase-backed data access
- `freezed` and `json_serializable` for models
- `SharedPreferences` and `Hive`-backed structured cache for local persistence
- feature gating via compile-time `--dart-define` values in [`lib/config/app_config.dart`](lib/config/app_config.dart)
- startup/performance instrumentation in [`lib/core/performance/`](lib/core/performance)

The app supports guest browsing for some surfaces, but authenticated flows are required for predictions, wallet actions, notifications, profile-protected routes, and fan/community actions.

### Admin architecture

The admin console lives under [`admin/`](admin) and uses:

- React 19
- Vite
- React Router
- TanStack Query
- Supabase JS
- role-based access control backed by the `admin_users` table

The admin app is not a separate backend. It talks directly to Supabase using authenticated browser sessions and relies on backend RLS and audited RPCs for sensitive actions.

### Backend architecture

The backend contract is defined in [`supabase/migrations/`](supabase/migrations) and expanded by Edge Functions under [`supabase/functions/`](supabase/functions).

Core backend domains present in the schema:

- profiles, preferences, and onboarding
- competitions, teams, matches, odds, standings, live events, advanced stats
- prediction challenges, entries, slips, daily challenges, settlement flows
- FET wallets, transfers, mint governance, partner marketplace, redemptions
- team supporters, contributions, fan identity, team news, social feed, contests
- notification preferences, device tokens, notification logs, match alerts
- admin users, feature flags, audit logs, moderation, analytics, account deletion

## Tech Stack

| Surface | Stack |
| --- | --- |
| Mobile app | Flutter, Dart `^3.10.8`, Material 3 |
| Mobile state | Riverpod, Riverpod Generator |
| Mobile DI | GetIt, Injectable |
| Mobile models | Freezed, Json Serializable |
| Mobile backend client | `supabase_flutter` |
| Mobile push bootstrap | Firebase Core, Firebase Messaging |
| Mobile local storage | SharedPreferences, Hive |
| Admin app | React 19, TypeScript, Vite |
| Admin routing/data | React Router, TanStack Query, Supabase JS |
| Backend | Supabase PostgreSQL, RLS, RPCs, Views |
| Edge functions | Deno / TypeScript |
| AI-backed ingestion | Google Gemini APIs in Edge Functions |
| CI/CD | GitHub Actions |
| Admin hosting | Cloudflare Pages |
| Android release ops | Gradle, Fastlane |
| iOS build ops | Xcode, CocoaPods |

## Repository Structure

```text
.
├── lib/                          # Flutter application code
│   ├── app.dart                  # Root MaterialApp
│   ├── app_router.dart           # App routes and auth redirects
│   ├── config/                   # Build-time config from dart-defines
│   ├── core/                     # DI, cache, runtime, performance, errors
│   ├── features/                 # Screen-level product features
│   ├── models/                   # Freezed / JSON models
│   ├── providers/                # Riverpod providers
│   ├── services/                 # Riverpod services + app integrations
│   └── widgets/                  # Shared UI building blocks
├── test/                         # Flutter unit, widget, golden, accessibility, and performance tests
├── assets/                       # Fonts, images, and data assets
├── admin/                        # React/Vite admin console
│   ├── src/components/           # Layout and shared UI
│   ├── src/config/               # Env and route config
│   ├── src/features/             # Admin pages + hooks
│   ├── src/hooks/                # Auth, toast, query helpers
│   └── wrangler.toml             # Cloudflare Pages config
├── supabase/
│   ├── migrations/               # Schema, RLS, RPCs, views
│   ├── functions/                # Deno Edge Functions
│   ├── tests/                    # SQL verification suites
│   └── .temp/                    # Local Supabase CLI link state (gitignored)
├── tool/                         # Build, release, smoke-test, and asset scripts
├── docs/                         # Release, privacy, launch, audit, and benchmark docs
├── android/                      # Android host project + Fastlane metadata
├── ios/                          # iOS host project
└── .github/workflows/            # CI, deployment, and scheduled jobs
```

## Prerequisites

Use versions close to what CI and the repo already assume:

- Flutter stable `3.27.x` with Dart `^3.10.8`
- Xcode with CocoaPods for iOS builds
- Android SDK / Android Studio
- Java 17 for Android/CI parity
- Node.js 22 for the admin console
- npm (lockfile is committed)
- Deno 2.x for Supabase Edge Functions
- `psql` for database verification scripts
- optional: Supabase CLI for linking a project and populating `supabase/.temp`
- optional: Ruby/Bundler if you intend to use Fastlane locally

## Configuration And Environment Variables

This repository uses different configuration channels for different surfaces. They are not interchangeable.

### 1. Mobile runtime config (`--dart-define`)

The Flutter app reads build-time config from [`lib/config/app_config.dart`](lib/config/app_config.dart). Use `--dart-define-from-file` with a JSON file.

Tracked templates:

- [`env/development.example.json`](env/development.example.json)
- [`env/staging.example.json`](env/staging.example.json)
- [`env/production.example.json`](env/production.example.json)

The real `env/*.json` files are intentionally gitignored. Create your own local copies, for example:

```bash
cp env/development.example.json env/development.json
cp env/staging.example.json env/staging.json
cp env/production.example.json env/production.json
```

Required mobile keys:

| Key | Required | Notes |
| --- | --- | --- |
| `APP_ENV` | Yes | `development`, `staging`, or `production` |
| `APP_VERSION` | Recommended | Can be overridden by build scripts |
| `SUPABASE_URL` | Yes | Required for backend connectivity |
| `SUPABASE_ANON_KEY` | Yes | Required for backend connectivity |

Optional mobile keys currently supported by code:

| Key | Purpose |
| --- | --- |
| `IMAGE_CDN_BASE_URL` | Optional image CDN base URL |
| `STATIC_CDN_BASE_URL` | Optional static CDN base URL |
| `STATIC_ASSET_VERSION` | Static asset cache version |
| `ENABLE_PREDICTIONS` | Prediction surface toggle |
| `ENABLE_WALLET` | Wallet surface toggle |
| `ENABLE_LEADERBOARD` | Leaderboard toggle |
| `ENABLE_REWARDS` | Rewards / marketplace toggle |
| `ENABLE_MEMBERSHIP` | Membership toggle |
| `ENABLE_NOTIFICATIONS` | Push init + notification UI toggle |
| `ENABLE_TEAM_COMMUNITIES` | Team communities toggle |
| `ENABLE_SOCIAL_FEED` | Social feed toggle |
| `ENABLE_FAN_IDENTITY` | Fan identity toggle |
| `ENABLE_MARKETPLACE` | Marketplace toggle |
| `ENABLE_AI_ANALYSIS` | AI analysis UI toggle |
| `ENABLE_ADVANCED_STATS` | Advanced stats UI toggle |
| `ENABLE_COMMUNITY_CONTESTS` | Community contests toggle |
| `ENABLE_SEASONAL_LEADERBOARDS` | Seasonal leaderboard toggle |
| `ENABLE_DEEP_LINKING` | Deep-link route support |
| `ENABLE_FEATURED_EVENTS` | Featured/global event surfaces |
| `ENABLE_GLOBAL_CHALLENGES` | Jackpot/global challenge surface |
| `ENABLE_REGION_DISCOVERY` | Regional discovery/onboarding flows |
Important:

- the example JSON files contain placeholders and are not enough for a real backend connection
- missing `SUPABASE_URL` / `SUPABASE_ANON_KEY` causes the mobile app to show a backend connection error state
- `lib/firebase_options.dart` is gitignored and must exist locally for the app to build

### 2. Root `.env` for shell tooling

The root `.env` file is used by shell scripts such as the Supabase probes. It is not read by the Flutter app.

Tracked template:

- [`.env.example`](.env.example)

Minimum values used by different scripts:

| Variable | Used by |
| --- | --- |
| `SUPABASE_URL` | `tool/supabase_release_probe.sh`, `tool/supabase_edge_job_smoke.sh`, `tool/supabase_whatsapp_auth_smoke.sh` |
| `SUPABASE_ANON_KEY` | `tool/supabase_release_probe.sh`, `tool/supabase_whatsapp_auth_smoke.sh` |
| `SUPABASE_SERVICE_ROLE_KEY` | `tool/supabase_edge_job_smoke.sh` |
| `CRON_SECRET` | `tool/supabase_edge_job_smoke.sh` and scheduled settle flows |
| `SUPABASE_DB_URL` or `SUPABASE_BOOTSTRAP_DB_URL` | `tool/supabase_bootstrap_smoke.sh` |
| `SUPABASE_DB_URL`, `SUPABASE_RLS_DB_URL`, or `SUPABASE_FET_DB_URL` | `tool/supabase_rls_audit.sh`, `tool/supabase_fet_supply_smoke.sh` |
| `WHATSAPP_AUTH_TEST_PHONE` | optional live send coverage in `tool/supabase_whatsapp_auth_smoke.sh` |
| `WHATSAPP_AUTH_TEST_OTP` | optional live verify coverage in `tool/supabase_whatsapp_auth_smoke.sh` |
| `SUPABASE_DB_PASSWORD` | fallback only when the repo is linked locally and `supabase/.temp/pooler-url` exists |

### 3. Admin environment

The admin app reads Vite env vars in [`admin/src/config/env.ts`](admin/src/config/env.ts).

Required admin vars:

| Variable | Required | Notes |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Yes for live admin | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Yes for live admin | Supabase anon key |

Use the committed template file and keep your real `admin/.env` local:

Example:

```bash
cp admin/.env.example admin/.env
```

Admin auth assumptions:

- login is WhatsApp OTP through the `whatsapp-otp` Edge Function
- the authenticated user must also have an active row in `public.admin_users`
- role enforcement is `viewer < moderator < admin < super_admin`

### 4. Platform-local config files

These files are intentionally gitignored and must be created locally:

| File | Purpose |
| --- | --- |
| `ios/Flutter/AppConfig.xcconfig` | iOS bundle id, team id, APNs environment |
| `android/key.properties` | Android upload keystore config |
| `android/app/google-services.json` | Firebase Android config |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config |
| `lib/firebase_options.dart` | FlutterFire-generated options |

Templates:

- [`ios/Flutter/AppConfig.xcconfig.example`](ios/Flutter/AppConfig.xcconfig.example)
- [`android/key.properties.example`](android/key.properties.example)

### 5. Supabase Edge Function secrets

Edge Functions use environment variables provided in the deployed Supabase project. Based on the checked-in functions and workflows, the relevant secrets are:

| Variable | Function(s) |
| --- | --- |
| `SUPABASE_URL` | all deployed functions |
| `SUPABASE_SERVICE_ROLE_KEY` | all deployed functions |
| `CRON_SECRET` | `auto-settle` |
| `PUSH_NOTIFY_SECRET` | `push-notify`, internal `auto-settle` calls |
| `WABA_ACCESS_TOKEN` | `whatsapp-otp` |
| `WABA_PHONE_NUMBER_ID` | `whatsapp-otp` |
| `SUPABASE_JWT_SECRET` | `whatsapp-otp` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | `push-notify` |
| `TEAM_NEWS_SYNC_SECRET` | `gemini-team-news` |
| `CURRENCY_SYNC_SECRET` | `gemini-currency-rates` |
| `MATCH_SYNC_SECRET` | `gemini-sports-data` |
| `GEMINI_API_KEY` | Gemini-backed ingestion functions |
| `GEMINI_MODEL` | optional model override for Gemini-backed functions |
| `ALLOWED_ORIGIN` | optional CORS origin override |
| `FANZONE_SUPABASE_URL` | optional override used by `gemini-currency-rates` |
| `FANZONE_SUPABASE_SERVICE_ROLE_KEY` | optional override used by `gemini-currency-rates` |

## Setup And Installation

### Mobile app

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

If you do not already have Firebase config locally:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

That should generate `lib/firebase_options.dart` and the platform Firebase files if you choose to output them.

### Admin console

```bash
cd admin
npm ci
```

### Backend contract / Edge Functions

The repo contains migrations, functions, and SQL verification scripts, but it does not ship a committed local Supabase development stack configuration. Day-to-day work assumes an existing Supabase project.

At minimum:

- provision or obtain a Supabase project
- apply migrations through your normal Supabase workflow
- if you want to run the audit scripts that depend on `supabase/.temp/pooler-url`, link the repo to the project first

## Local Development

### Run the mobile app

Use a real env file, not the placeholder example file:

```bash
flutter run --dart-define-from-file=env/development.json
```

Useful variants:

```bash
flutter run --dart-define-from-file=env/staging.json
flutter run -d <device-id> --dart-define-from-file=env/development.json
dart run build_runner watch --delete-conflicting-outputs
```

### Run the admin console

```bash
cd admin
npm run dev
```

Preview a production build locally:

```bash
cd admin
npm run build
npm run preview
```

### Backend / integration development notes

- most mobile data flows are remote-first against Supabase
- several gateways include cache or local fallback data for degraded browsing, but write paths still require backend connectivity
- some verification scripts assume `psql` and a linked Supabase project
- scheduled jobs are implemented in GitHub Actions and/or DB-side scheduling, not in a local orchestrator inside this repo

## Build And Run Instructions

### Mobile debug / verification build

```bash
flutter build apk --debug
```

### Android release APK

```bash
./tool/build_android_release_from_env.sh staging
./tool/build_android_release_from_env.sh production
```

### Android release AAB

```bash
./tool/build_android_aab_from_env.sh staging
./tool/build_android_aab_from_env.sh production
```

Notes:

- production Android builds require a valid upload keystore
- release signing values can come from `android/key.properties` or `FANZONE_UPLOAD_*` environment variables
- the Android package name is `app.fanzone.football`

### iOS release build

```bash
./tool/build_ios_release_from_env.sh staging
./tool/build_ios_release_from_env.sh production
```

Notes:

- the script validates `ios/Flutter/AppConfig.xcconfig`
- it also requires `ios/Runner/GoogleService-Info.plist`
- the script builds with `--no-codesign`; final signing/archive still happens in Xcode

### Admin build

```bash
cd admin
npm run build
```

## Testing And Quality Gates

### Mobile checks

```bash
dart format --output=none --set-exit-if-changed lib test tool
./tool/flutter_analyze_release.sh
flutter test
flutter test --coverage
```

The Flutter test suite covers:

- unit tests for models, utilities, caching, and failures
- widget tests
- golden tests in `test/design_system_golden_test.dart`
- accessibility guideline checks
- startup and frame-budget regression checks

Important test notes:

- fonts are vendored under `assets/fonts/` to keep golden tests deterministic
- generated Dart files must be up to date before CI passes

### Admin checks

```bash
cd admin
npm run lint
npm run test
npm run build
```

### Edge Function checks

```bash
deno fmt --check supabase/functions
deno check supabase/functions/auto-settle/index.ts \
  supabase/functions/push-notify/index.ts \
  supabase/functions/gemini-team-news/index.ts \
  supabase/functions/gemini-currency-rates/index.ts
deno test supabase/functions
```

### SQL / backend verification scripts

These are the operational checks already used by CI and release workflows:

```bash
./tool/supabase_bootstrap_smoke.sh
./tool/supabase_edge_job_smoke.sh
./tool/supabase_whatsapp_auth_smoke.sh
./tool/supabase_release_probe.sh
./tool/supabase_rls_audit.sh
./tool/supabase_fet_supply_smoke.sh
```

Prerequisites vary by script:

- `tool/supabase_bootstrap_smoke.sh` requires `psql` and `SUPABASE_BOOTSTRAP_DB_URL` or `SUPABASE_DB_URL`
- `tool/supabase_edge_job_smoke.sh` requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
- `tool/supabase_whatsapp_auth_smoke.sh` requires `SUPABASE_URL` and `SUPABASE_ANON_KEY`, and supports optional `WHATSAPP_AUTH_TEST_PHONE` / `WHATSAPP_AUTH_TEST_OTP`
- `tool/supabase_release_probe.sh` requires `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- `tool/supabase_rls_audit.sh` and `tool/supabase_fet_supply_smoke.sh` accept `SUPABASE_DB_URL` directly, or fall back to `SUPABASE_DB_PASSWORD` plus `supabase/.temp/pooler-url`

## Key Workflows, Scripts, And Commands

| Command | Purpose |
| --- | --- |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate Dart code |
| `flutter run --dart-define-from-file=env/development.json` | Run mobile app locally |
| `./tool/build_android_release_from_env.sh <env>` | Build release APK |
| `./tool/build_android_aab_from_env.sh <env>` | Build release AAB |
| `./tool/build_ios_release_from_env.sh <env>` | Build iOS release without codesign |
| `./tool/flutter_analyze_release.sh` | Analyzer gate that fails on warnings/errors |
| `./tool/supabase_release_probe.sh` | Public API/RLS release probe |
| `./tool/supabase_edge_job_smoke.sh` | Edge Function auth-layer smoke checks |
| `./tool/supabase_whatsapp_auth_smoke.sh` | WhatsApp-only auth smoke checks |
| `./tool/supabase_rls_audit.sh` | SQL audit for RLS hardening |
| `./tool/supabase_fet_supply_smoke.sh` | FET supply cap smoke test |
| `cd admin && npm run dev` | Run admin locally |
| `cd admin && npm run build` | Build admin for deployment |
| `cd admin && npm run test` | Run admin tests |

Special-purpose scripts:

- [`tool/generate_icons.sh`](tool/generate_icons.sh) is a macOS-specific asset helper with hardcoded source paths
- [`tool/prepare_store_screenshots.sh`](tool/prepare_store_screenshots.sh) is a macOS/local-operator script for Play Store screenshot prep

These are not portable general-purpose setup scripts and should be treated as operator utilities.

## Backend And Integration Overview

### Major schema domains

The migration chain shows the backend currently supports:

- `profiles`, `user_market_preferences`, privacy settings, onboarding completion
- `competitions`, `teams`, `matches`, `live_match_events`, `match_advanced_stats`, `match_player_stats`, odds cache
- `prediction_challenges`, `prediction_challenge_entries`, pool settlement RPCs
- `prediction_slips`, `prediction_slip_selections`, daily challenge tables
- `fet_wallets`, `fet_wallet_transactions`, mint governance, transfer flows, supply cap enforcement
- `team_supporters`, `team_contributions`, `team_news`, social feed, community contests
- `notification_preferences`, `device_tokens`, `notification_log`, `match_alert_subscriptions`
- `partners`, `rewards`, `redemptions`, admin reconciliation/audit functions
- `admin_users`, `admin_audit_logs`, admin data-plane views and RPCs
- `product_events` analytics logging

### Edge Functions

Current Edge Functions in the repo:

- `auto-settle`: settles eligible pools and prediction slips, triggers winner notifications
- `push-notify`: sends push notifications through FCM/APNs using a Firebase service account
- `gemini-team-news`: grounded AI ingestion for team news
- `gemini-currency-rates`: grounded AI refresh of EUR exchange rates used by the FET system
- `gemini-sports-data`: structured Gemini-powered match events and odds ingestion

### Scheduled/operational jobs

Current GitHub Actions jobs encode part of the production operating model:

- `cron-settle.yml`: every 15 minutes fallback settlement trigger
- `cron-currency-refresh.yml`: every 6 hours currency refresh
- `team-news-ingestion.yml`: manual team news ingestion workflow
- `deploy-admin.yml`: admin deployment on `main`/`develop`

## Auth And Access Model

### Mobile auth

FANZONE uses two authentication paths, both managed through Supabase Auth:

**1. WhatsApp OTP (full authentication)**

- OTP is generated and delivered via WhatsApp Cloud API using the `gikundiro` authentication template
- The `whatsapp-otp` Edge Function handles OTP generation, storage, WhatsApp delivery, and session creation
- On successful verification, the Edge Function creates/finds the Supabase Auth user and returns a session JWT
- No Twilio or Supabase-native SMS provider is used

**2. Guest mode (anonymous authentication)**

- Uses Supabase anonymous auth (`enable_anonymous_sign_ins = true`)
- Guest users can browse matches, fixtures, teams, leagues, standings, pools (read-only), and leaderboard
- Guest users **cannot**: make predictions, join/create pools, access wallet, access fan identity, modify settings, or perform any write-action
- When a guest attempts a protected action, the app shows a sign-in prompt and redirects to the upgrade flow

**Onboarding flow (5+ steps)**

```
Splash → Welcome → Auth Choice → [WhatsApp OTP path OR Guest path] → Favorite Team → Popular Teams → Home
```

- Auth Choice screen: "Continue with WhatsApp" or "Continue as Guest"
- WhatsApp path: Phone Input → OTP Verification → Team Selection → Home (full access)
- Guest path: Anonymous sign-in → Team Selection → Home (view-only)

**Guest-to-authenticated upgrade**

- Guest users can upgrade at any time via `/upgrade` route
- The upgrade screen reuses the WhatsApp OTP verification flow
- On successful upgrade, the `merge_anonymous_to_authenticated` RPC migrates the guest's data (favorite teams, followed teams/competitions, onboarding state) to the new authenticated profile
- The anonymous profile is deleted after merge

**Required Supabase secrets for WhatsApp Cloud API**

```bash
supabase secrets set WABA_ACCESS_TOKEN=<your-token>
supabase secrets set WABA_PHONE_NUMBER_ID=<your-phone-number-id>
supabase secrets set SUPABASE_JWT_SECRET=<your-jwt-signing-secret>
# Optional: WABA_OTP_TEMPLATE_NAME (default: gikundiro)
# Optional: OTP_EXPIRY_SECONDS (default: 600)
```

**Required Supabase dashboard setting**

- Authentication → Settings → Enable Anonymous Sign-ins: **ON**
- Authentication → Providers → Email: **OFF**
- Authentication → Providers → Phone: **OFF**

**Protected routes** (require full auth, not guest):

- `/wallet/exchange`, `/fan-id`, `/memberships`, `/social`, `/rewards`
- `/notifications`, `/notification-settings`, `/privacy`
- `/settings/*`, `/profile/settings/*`

**Config assumptions**

- mobile feature access is primarily compile-time via `AppConfig`
- admin feature control exists in the backend schema, but the mobile app does not currently read remote admin feature flags
- push notification flows require both Firebase client config and Supabase function secrets

## Release Guidance

The operational source of truth is [`docs/release-checklist.md`](docs/release-checklist.md). Use it before any store or production promotion.

### Mobile release path

Android:

- build APK/AAB with the environment scripts
- ensure signing config is real, not placeholder
- optionally use Fastlane lanes in [`android/fastlane/Fastfile`](android/fastlane/Fastfile)

iOS:

- build with `./tool/build_ios_release_from_env.sh production`
- open Xcode for final signing, archive, APNs capability validation, and TestFlight/App Store steps

### Admin release path

- the admin app builds on every relevant CI/deploy workflow
- pushes to `main` deploy production to Cloudflare Pages
- pushes to `develop` deploy a preview environment

### Backend release path

This repo contains the database contract and verification scripts, but it does not codify a full end-to-end migration deployment command inside the README because local/project setup may differ.

At minimum, a backend promotion should include:

- applying pending migrations
- deploying touched Edge Functions
- running the release probe
- running RLS and FET governance audits where relevant
- confirming secrets, rate limits, and notification delivery paths

## Deployment Notes

### What is automated today

- CI runs on pushes to `main` and `develop`, and on PRs targeting `main`
- same-repo pushes and PRs also run database bootstrap, probe, and SQL audit steps when the required GitHub secrets are configured
- admin deploys automatically from GitHub Actions to Cloudflare Pages
- `main` pushes trigger Android artifact build and iOS no-codesign verification build
- scheduled GitHub Actions can trigger settlement and currency refresh

### What is still manual or environment-specific

- mobile store submission and release promotion
- iOS signing and archive/export
- provisioning Firebase credentials and FlutterFire outputs
- provisioning Supabase secrets and applying migrations in the target project

## Troubleshooting

### Mobile app shows a connection/setup error at login

Check:

- `SUPABASE_URL` and `SUPABASE_ANON_KEY` are present in the active `env/*.json`
- you ran with `--dart-define-from-file=...`
- the JSON file contains real values, not example placeholders
- `SUPABASE_JWT_SECRET`, `WABA_ACCESS_TOKEN`, and `WABA_PHONE_NUMBER_ID` are set for the deployed `whatsapp-otp` Edge Function

### Flutter build fails because `firebase_options.dart` is missing

Generate Firebase config locally:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

### iOS release build fails immediately

The iOS release script explicitly fails if any of these are missing or placeholder:

- `ios/Flutter/AppConfig.xcconfig`
- `ios/Runner/GoogleService-Info.plist`
- a real Apple team id
- a real bundle identifier
- a valid `FANZONE_APS_ENVIRONMENT`

### Android production build fails on signing

Provide real signing values through:

- `android/key.properties`, or
- `FANZONE_UPLOAD_STORE_FILE`
- `FANZONE_UPLOAD_STORE_PASSWORD`
- `FANZONE_UPLOAD_KEY_ALIAS`
- `FANZONE_UPLOAD_KEY_PASSWORD`

### Admin login is locked or redirects back to `/login`

Check:

- `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
- the admin user exists in Supabase Auth as a phone identity that can receive WhatsApp OTP
- the same authenticated user also has an active `admin_users` row
- missing admin env now hard-locks auth and data access instead of falling back to demo content

### Supabase audit scripts fail with missing `supabase/.temp/pooler-url`

Those scripts can run either against local Supabase link state or a direct Postgres URL:

- set `SUPABASE_DB_URL` for `tool/supabase_rls_audit.sh` and `tool/supabase_fet_supply_smoke.sh`
- set `SUPABASE_BOOTSTRAP_DB_URL` for `tool/supabase_bootstrap_smoke.sh`
- if you prefer local link state, ensure `supabase/.temp/pooler-url` exists and `SUPABASE_DB_PASSWORD` is set

### Push notifications do not arrive

Check:

- `ENABLE_NOTIFICATIONS=true` in the active mobile env file
- platform Firebase files are present
- `lib/firebase_options.dart` matches the target Firebase project
- `GOOGLE_SERVICE_ACCOUNT_JSON` is configured in Supabase
- APNs is configured for iOS
- you are testing on a physical device, not a simulator

## Common Issues And Gotchas

- `env/*.json` real files are gitignored; examples are templates only
- `admin/.env.example` is committed as a template, but the real `admin/.env` remains local-only
- generated Dart files must be committed when source models/providers change
- some mobile features are present in routing/UI but intentionally disabled by default
- the app is mobile-only; web/desktop platforms are intentionally excluded
- localization scaffolding exists, but only English strings are committed today

## Contribution Guidelines

### General expectations

- keep changes scoped to the surface you are modifying
- do not edit generated Dart files by hand
- regenerate and commit `*.g.dart`, `*.freezed.dart`, and `injection.config.dart` changes when required
- update docs when changing build, release, or configuration behavior

### Minimum validation before opening a PR

For Flutter changes:

- `dart run build_runner build --delete-conflicting-outputs`
- `./tool/flutter_analyze_release.sh`
- `flutter test`

For admin changes:

- `cd admin && npm run lint`
- `cd admin && npm run test`
- `cd admin && npm run build`

For Edge Function / backend changes:

- `deno fmt --check` on touched functions
- `deno check` on touched functions
- `deno test supabase/functions`
- relevant SQL probe/audit scripts when schema or RLS changed

## Coding Conventions

### Flutter / Dart

The repo enforces the following conventions through [`analysis_options.yaml`](analysis_options.yaml) and CI:

- prefer `const`
- avoid `print`
- prefer single quotes
- prefer relative imports
- use keys in widget constructors
- keep child properties ordered consistently
- warnings are treated as release-gating failures by `./tool/flutter_analyze_release.sh`

### Admin / TypeScript

- ESLint is configured in [`admin/eslint.config.js`](admin/eslint.config.js)
- TypeScript + React Hooks linting is enabled
- keep route-level data access inside the existing query hook patterns where possible

## Branch And PR Workflow

The repository automation currently assumes:

- `main` is the production branch
- `develop` is an active integration/preview branch
- PR CI is wired for PRs targeting `main`
- pushes to `main` and `develop` run CI
- pushes affecting `admin/**` on `main` or `develop` deploy the admin console
- pushes to `main` also build mobile release artifacts in CI

If your team works off feature branches, branch from the appropriate long-lived branch and target a PR that preserves those automation expectations.

## Security And Secrets

Do not commit:

- real `env/*.json`
- root `.env`
- `admin/.env`
- Android keystores or `android/key.properties`
- `ios/Flutter/AppConfig.xcconfig`
- Firebase config files
- `lib/firebase_options.dart`
- Supabase service-role keys, Firebase service account JSON, or Play/App Store credentials

Repository security patterns already present in code:

- RLS is enabled across sensitive tables
- many write flows are behind audited RPCs
- admin access is role-gated and hardened through dedicated SQL functions
- FET minting paths are constrained and governed in SQL
- release probes explicitly check for anon data leakage and improper writes

Read:

- [`docs/fet-supply-governance.md`](docs/fet-supply-governance.md)
- [`docs/privacy-policy.md`](docs/privacy-policy.md)

## Known Limitations / Near-Term Roadmap

Observed directly from the current code and config:

- `ENABLE_GLOBAL_CHALLENGES` is `false` in the tracked env templates and CI; jackpot/global challenge rollout is not yet treated as fully live
- social feed, AI analysis, advanced stats, community contests, and seasonal leaderboards are implemented unevenly and gated by build flags
- only English localization is committed
- local Supabase dev bootstrap is incomplete in-repo; most backend work assumes a real project
- the admin repo slice depends on browser-side Supabase auth and still needs broader component and integration coverage beyond the core RBAC guards

## Additional Documentation

- [`docs/release-checklist.md`](docs/release-checklist.md)
- [`docs/FCM_SETUP.md`](docs/FCM_SETUP.md)
- [`docs/play-store-listing.md`](docs/play-store-listing.md)
- [`docs/fet-supply-governance.md`](docs/fet-supply-governance.md)
- [`docs/privacy-policy.md`](docs/privacy-policy.md)
- [`docs/performance-baseline-2026-04-19.md`](docs/performance-baseline-2026-04-19.md)
- [`docs/fanzone-p0-launch-execution-plan-2026-04-19.md`](docs/fanzone-p0-launch-execution-plan-2026-04-19.md)

## Quick Start Reference

```bash
# Mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=env/development.json

# Tests
./tool/flutter_analyze_release.sh
flutter test

# Admin
cd admin
npm ci
npm run dev

# Edge functions
deno test supabase/functions

# Release probes
./tool/supabase_whatsapp_auth_smoke.sh
./tool/supabase_release_probe.sh
```
