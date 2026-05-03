# FANZONE Fullstack Refactor Audit

Date: 2026-05-03

## Executive Summary

Release rating: Not ready.

The repo is already a multi-surface product, not a blank slate. The safest path is incremental cleanup around the existing Flutter feature structure, React PWA workspaces, shared TypeScript contracts, and Supabase RPC/RLS model. This pass improved typography consistency, reduced web design-token drift, extracted venue auth UI from routing bootstrap, added release-critical order query indexes, and documented the remaining hotspots.

Production blockers remain: exposed Supabase credentials must be rotated, the time-bound reviewer OTP fixture must be removed or rotated after UAT, Flutter mobile device UAT is still required, multi-device realtime UAT is still required, and Supabase performance WARN findings still need triage or explicit acceptance.

## Repo Map

| Surface | Path | Current structure |
| --- | --- | --- |
| Flutter mobile app | `lib/` | `core`, `features`, `models`, `providers`, `services`, `theme`, `widgets/common`, and generated model files. Uses Riverpod, GoRouter, Supabase Flutter, Freezed/JSON models. |
| Venue web PWA | `apps/venue-portal` | Vite/React app with `features`, `components`, `hooks`, `services`, `lib`, and Tailwind CSS. Uses custom WhatsApp OTP session bearer token for Supabase reads. |
| Admin web PWA | `apps/admin` | Vite/React app with feature modules, admin hooks, component CSS, shared design tokens, and Vitest coverage. |
| TV display PWA | `apps/tv-display` | Vite/React display app with screen modes in `App.tsx`, Supabase data service, realtime subscription, polling fallback, and TV-first CSS. |
| Public web PWA | `apps/website` | Separate React surface for public browsing/order-style flows. It is not the Flutter mobile app. |
| Shared TS contracts | `packages/core` | Database-oriented types and `designTokens.css` shared by PWA surfaces. |
| Supabase | `supabase/` | 68+ migrations, Edge Functions, RLS/contract/UAT SQL tests, destructive scripts, and project config. |
| Flutter tests | `test/`, `integration_test/` | Widget, model, routing, cache, accessibility, onboarding, wallet, and smoke coverage. |
| Tooling | `tool/`, `scripts/` | Release, Supabase, build, and smoke-test helpers. |

## Architecture Findings

- Flutter is already reasonably modular. A forced move to a new `app/core/design_system/features` layout would create churn without immediate safety benefit.
- The existing Flutter design system is under `lib/theme` and `lib/widgets/common`. It should be treated as the canonical mobile design system unless a later migration moves it wholesale.
- Web surfaces already share `packages/core/src/designTokens.css`, but admin was redeclaring most of the same variables. That created typography and color drift.
- Venue PWA routing had auth UI embedded in `App.tsx`. This made the route shell own form state, custom OTP calls, and layout.
- Large files remain: `apps/venue-portal/src/features/target/TargetPages.tsx`, `apps/tv-display/src/App.tsx`, and `lib/features/ordering/screens/venue_menu_screen.dart`. These are maintainability risks but should be split in focused follow-up work, not all at once.

## Changes Completed

- Raised shared web typography tokens so `xs/sm/base` map to 12/14/16px instead of 11/13/14px.
- Added shared web display and font-weight tokens for stronger dashboard/TV hierarchy.
- Removed duplicated admin token definitions that shadowed `packages/core/src/designTokens.css`; retained admin-specific hover/layout tokens.
- Raised admin button/input/badge typography and touch targets.
- Raised Flutter fixed text sizes below 12px across production `lib/` code to the minimum readable size.
- Raised Flutter bottom navigation and `FzBadge` defaults to match the app’s bold mobile typography direction.
- Extracted venue login UI into `apps/venue-portal/src/features/auth/VenueLoginPage.tsx`.
- Added additive Supabase indexes for venue payment queues and qualifying-order eligibility lookups.
- Extended UAT fixture verification to assert those release query indexes exist.

## Backend And Supabase Review

Critical business protections already present or previously hardened:

- Unique immutable 6-digit fan ID allocation.
- Venue-linked prediction pools.
- Server-side pool join/stake checks.
- Ledgered user and venue wallet mutations.
- Eligibility-based pool settlement.
- Stable 20-question game session selection.
- One answer per team/question and one first-correct answer per question.
- Venue-isolated TV screen state and TV-safe live question RPC.
- RLS-backed dashboard access by venue membership.

Indexes added in this pass:

- `orders_venue_payment_created_idx` on `(venue_id, payment_status, created_at desc)`.
- `orders_eligibility_lookup_idx` on `(venue_id, user_id, created_at desc)` for paid, non-cancelled orders.

## Security Notes

- No dangerous React HTML/code execution sinks were found in the scanned app code.
- Browser `localStorage` is used for custom WhatsApp OTP sessions in admin/venue flows. This is an accepted architecture tradeoff for the current client-side PWA model, but it must be documented and paired with short token lifetimes, strong CSP, and credential rotation.
- The reviewer OTP fixture is time-bound UAT support and must not be treated as a production bypass.
- Supabase service role secrets and DB credentials exposed during review must be rotated before production.

## Remaining Refactor Risks

- `TargetPages.tsx` mixes many venue dashboard routes in one file. Split by feature after the current release-hardening patch stabilizes.
- `tv-display/src/App.tsx` owns data loading, QR generation, routing, and all modes. Extract `hooks/useVenueScreen.ts` and `modes/*` in a separate TV-only pass.
- Flutter ordering screens are large. Split `venue_menu_screen.dart` into menu header, category rail, item card, and cart summary components.
- There are still many hardcoded Flutter spacing/radius styles. They are visually consistent enough to ship, but future cleanup should replace them with `FzSpacing` and `FzRadii`.
- Full Supabase advisor WARN cleanup is still open.

## Quality Gates For This Pass

Executed after this refactor:

- `git diff --check`: pass.
- `flutter analyze`: pass.
- `flutter test`: pass, 221 tests.
- `flutter test test/design_system_golden_test.dart --update-goldens`: pass after intentional typography scale change.
- `npm run typecheck`: pass across workspaces.
- `npm test`: pass, admin 22 tests and website 6 tests.
- `npm run lint -w @fanzone/admin --if-present`: pass.
- `npm run lint -w @fanzone/venue-portal`: pass.
- `npm run build -w @fanzone/venue-portal`: pass.
- `npm run lint -w @fanzone/tv-display`: pass.
- `npm run build -w @fanzone/tv-display`: pass.
- `npm run build -w @fanzone/admin`: pass.
- `SUPABASE_URL=http://localhost:54321 deno test --allow-env supabase/functions/whatsapp-otp/index_test.ts`: pass, 7 tests.
- `supabase db query --linked -f supabase/tests/uat_01_fixture_verification.sql`: pass.
- Authenticated venue PWA browser smoke: pass, screenshot `output/playwright/venue-portal-refactor-authenticated.png`.

## Recommended Next Fixes

1. Rotate all exposed Supabase credentials and remove/rotate reviewer OTP fixture after UAT.
2. Execute Flutter mobile device UAT for auth, fan profile, ordering, pools, eligibility, wallet, and settlement.
3. Execute phone + venue dashboard + TV realtime UAT with the seeded staff fixtures.
4. Split the venue target pages and TV mode tree in small follow-up PRs.
5. Triage the remaining Supabase performance WARN findings by route/query priority.
