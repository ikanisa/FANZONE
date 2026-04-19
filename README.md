# FANZONE

**The global football prediction, fan engagement, and operations platform.**

FANZONE is a mixed-surface repository:

- a native Flutter mobile app in `lib/`
- a React/Vite admin console in `admin/`
- Supabase migrations, SQL verification scripts, and edge functions in `supabase/`
- release and operational tooling in `tool/`

## Surfaces

| Surface | Status |
|---------|--------|
| Mobile app (Flutter) | Active |
| Admin console (React/Vite) | Active |
| Supabase backend contract | Active |

## Repository Structure

```text
.
├── lib/                          # Flutter application code
│   ├── main.dart                 # Bootstrap + service init
│   ├── app.dart                  # Root MaterialApp
│   ├── app_router.dart           # GoRouter navigation
│   ├── features/                 # Screen-level mobile features
│   ├── models/                   # Freezed/data-transfer models
│   ├── providers/                # Riverpod query/state providers
│   ├── services/                 # Supabase-backed service providers
│   ├── theme/                    # Design system
│   ├── widgets/                  # Shared mobile UI components
│   └── core/                     # Config, network, errors, launch-market utils
├── admin/                        # React/Vite admin console
│   ├── src/features/             # Admin pages + hooks
│   ├── src/components/           # Shared admin layout/UI
│   └── src/lib|config|types/     # Runtime wiring and shared types
├── supabase/                     # DB contract + machine jobs
│   ├── migrations/               # Schema/policy evolution
│   ├── functions/                # Deno edge functions
│   └── tests/                    # SQL verification scripts
├── tool/                         # Build, release, and smoke-test scripts
├── test/                         # Flutter widget/unit tests
├── docs/                         # Launch, release, and audit docs
├── android/                      # Android host project
├── ios/                          # iOS host project
└── .github/workflows/            # CI/CD and scheduled automation
```

## Prerequisites

- Flutter SDK compatible with `sdk: ^3.10.8`
- Xcode for iOS builds
- Android SDK / Android Studio for Android builds
- Node.js for `admin/`

## Environment Setup

Mobile runtime configuration is injected with `--dart-define` or `--dart-define-from-file`.

```bash
flutter run --dart-define-from-file=env/development.example.json
```

Required mobile values:

- `APP_ENV`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional mobile values:

- `SENTRY_DSN`
- `ENABLE_PREDICTIONS`
- `ENABLE_WALLET`
- `ENABLE_LEADERBOARD`
- `ENABLE_REWARDS`
- `ENABLE_MEMBERSHIP`
- `ENABLE_NOTIFICATIONS`

Admin environment values live in `admin/.env` locally and are documented in `admin/.env.example`:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_ALLOW_DEMO_MODE`

## Quick Start

```bash
# Mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=env/development.example.json
flutter test
flutter analyze

# Admin
npm --prefix admin install
npm --prefix admin run lint
npm --prefix admin run build

# Edge functions
deno check supabase/functions/auto-settle/index.ts \
  supabase/functions/push-notify/index.ts \
  supabase/functions/gemini-team-news/index.ts \
  supabase/functions/gemini-currency-rates/index.ts

# Release helpers
./tool/build_android_release_from_env.sh staging
./tool/build_ios_release_from_env.sh staging
./tool/supabase_release_probe.sh
```

## Architecture

| Layer | Technology |
|------|------------|
| Mobile UI | Flutter + Material 3 |
| Mobile navigation | GoRouter |
| Mobile state | Riverpod |
| Mobile models | Freezed + json_serializable |
| Admin UI | React 19 + Vite + React Router |
| Admin data | Supabase JS + TanStack Query |
| Backend | Supabase migrations, views/RPCs, Deno edge functions |
| Telemetry | Sentry (mobile) |

## Backend Contract

The app and admin console rely on Supabase tables, views, and RPCs defined under `supabase/migrations/`.

Examples:

- wallets: `fet_wallets`, `fet_wallet_transactions`
- predictions: `prediction_challenges`, `prediction_challenge_entries`, `prediction_slips`
- admin plane: `admin_users`, `admin_audit_logs`, admin-facing views/RPCs
- social/community: `team_supporters`, `team_news`, `feed_messages`

Operational probes and policy checks:

- `tool/supabase_release_probe.sh`
- `tool/supabase_rls_audit.sh`
- `tool/supabase_fet_supply_smoke.sh`
- SQL checks in `supabase/tests/`

## Contributing

1. Keep mobile, admin, and Supabase changes scoped and intentional.
2. Run `flutter analyze` and `flutter test` for mobile changes.
3. Run `npm --prefix admin run lint` and `npm --prefix admin run build` for admin changes.
4. Run `deno check` on touched edge functions.
5. Commit generated Dart files when their source models/providers change.
6. Do not rely on committed local `.env` files for release builds.

See [docs/release-checklist.md](docs/release-checklist.md) for release-facing operational inputs.
