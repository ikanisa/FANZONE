# Apps

## Release App Boundary

The production sports-bar release is validated across four app surfaces:

- Flutter mobile client: guest/user app for phones.
- Venue web PWA: staff operations console for bars and restaurants.
- Admin web PWA: platform operations console.
- TV display PWA: paired live display for venue screens.

`apps/website/` still exists as a public web PWA surface. It is not the Flutter mobile client and must be explicitly included or excluded by release scope before UAT.

## Flutter Mobile Client

Path: `lib/`

Audience: guests and mobile venue users.

Primary flows:

- onboarding and WhatsApp OTP;
- in-app venue entry;
- venue menu and checkout;
- off-platform payment guidance;
- order tracking;
- FET non-cash loyalty balance;
- match challenge discovery, joining, and sharing;
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

## Venue Web PWA

Path: `apps/venue-portal/`

Audience: venue owners, managers, and staff.

Routes:

- `/overview`
- `/orders`
- `/menu`
- `/pools`
- `/games`
- `/teams`
- `/participants`
- `/screen`
- `/wallet`
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
- venue ordering is selected in-app;
- FET reward edits are owner/manager gated;
- insights come from `get_venue_operational_insights`;
- screen control pushes state to `venue_screen_states` and opens the standalone TV display PWA.

## Admin Web PWA

Path: `apps/admin/`

Audience: platform operators.

Primary operations:

- countries, competitions, teams, venues;
- match curation;
- challenge operations;
- reward rules;
- loyalty-ledger oversight;
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

## TV Display PWA

Path: `apps/tv-display/`

Audience: venue screens and TVs.

Primary display modes:

- venue welcome;
- app join screen;
- active prediction challenge;
- game lobby;
- live question;
- leaderboard;
- winner reveal;
- menu/promo screen.

Commands:

```bash
npm ci
npm run dev -w @fanzone/tv-display
npm run typecheck -w @fanzone/tv-display
npm run lint -w @fanzone/tv-display
npm run build -w @fanzone/tv-display
```

Environment:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- optional `VITE_PUBLIC_APP_URL`

Notes:

- the TV app is unauthenticated and must read only screen-safe venue-scoped data;
- it uses `venue_screen_states` as the display source of truth;
- it must never show another venue's pool, game, menu, or leaderboard;
- App links must resolve to the linked venue, pool, or game context.

## Public Website PWA

Path: `apps/website/`

Audience: guests and public web users.

Primary flows:

- public landing and challenge discovery;
- match detail;
- challenge creation/joining;
- loyalty balance;
- in-app ordering and venue entry;
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
