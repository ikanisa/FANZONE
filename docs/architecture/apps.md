# Apps

## Flutter Mobile App

Path: `lib/`

Audience: guests and mobile venue users.

Primary flows:

- onboarding and WhatsApp OTP;
- QR/table venue entry;
- venue menu and checkout;
- off-platform payment guidance;
- order tracking;
- FET wallet;
- match pool discovery, joining, and sharing;
- profile, notifications, privacy, and settings.

Commands:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/development.json
flutter build apk --release --dart-define-from-file=env/production.json
flutter build ipa --release --dart-define-from-file=env/production.json
```

Environment:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- optional `SENTRY_DSN`
- optional CDN values from `env/*.example.json`

Production notes:

- real `env/*.json` files are ignored;
- Firebase and store signing files are ignored and must come from CI/local secure storage;
- mobile app should never contain a Supabase service-role key.

## Website PWA

Path: `apps/website/`

Audience: guests and public web users.

Primary flows:

- public landing and pool discovery;
- match detail;
- pool creation/joining;
- wallet;
- QR ordering and venue entry;
- profile, notifications, settings, privacy.

Commands:

```bash
npm ci
npm run lint
npm run test
npm run build
npm run preview
```

Notes:

- `npm run build` runs the canonical source drift check first.
- `npm run validate:release-metadata` must pass before production deploy.
- `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are required.

## Venue Portal

Path: `apps/venue-portal/`

Audience: venue owners, managers, and staff.

Routes:

- `/orders`
- `/menu`
- `/pools`
- `/rewards`
- `/tables`
- `/insights`
- `/settings`

Commands:

```bash
npm ci
npm run typecheck
npm run lint
npm run build
npm run preview
```

Notes:

- orders use audited payment RPCs and service-status Edge Function calls;
- table QR payloads come from Supabase `generate_table_qr`;
- FET reward edits are owner/manager gated;
- insights come from `get_venue_operational_insights`.

## Admin Console

Path: `apps/admin/`

Audience: platform operators.

Primary operations:

- countries, competitions, teams, venues;
- match curation;
- pool operations;
- reward rules;
- wallet oversight;
- audit logs;
- admin access;
- platform controls and settings.

Commands:

```bash
npm ci
npm run typecheck
npm run lint
npm run test
npm run build
npm run preview
```

Notes:

- `VITE_ALLOW_DEMO_MODE` is local-only and must not be enabled in production;
- admin mutations must route through admin RPCs or audited Edge Functions;
- role guards in the UI are convenience controls, not the security boundary.

## Shared Core Package

Path: `packages/core/`

Purpose:

- shared TypeScript contracts;
- database row types;
- app-level domain types for web workspaces.

Commands:

```bash
npm run typecheck -w @fanzone/core
```
