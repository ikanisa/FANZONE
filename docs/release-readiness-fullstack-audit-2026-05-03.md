# FANZONE Fullstack Audit - 2026-05-03

## Scope

This audit covers the implemented Flutter customer app, React venue portal/dashboard, React website/admin apps, Supabase schema/functions/migrations, shared TypeScript core package, tests, and release documentation.

This is a surgical refactor plan. The product model stays intact: WhatsApp OTP, 6-digit user IDs, external payments, manual payment confirmation, FET ledger, staked prediction pools, centralized games, teams, venue-linked TV screens, and order-linked settlement eligibility.

## Repo Map

- `lib/`: Flutter mobile app with feature screens, providers, theme, widgets, models, and Supabase-facing services.
- `apps/venue-portal/`: Vite/React venue dashboard for orders, menu, FET reward settings, tables, insights, and the target operational dashboard routes.
- `apps/website/`: Vite/React public/user web surfaces.
- `apps/admin/`: Vite/React admin surfaces.
- `packages/core/`: shared TypeScript database row types, status types, and design tokens.
- `supabase/migrations/`: Postgres schema, policies, RPCs, compatibility migrations, and remote history markers.
- `supabase/functions/`: Edge Functions for order creation/status/payment and prediction pool operations.
- `supabase/tests/`: database-facing tests and SQL validation scripts.
- `test/`: Flutter unit/widget/golden tests.
- `docs/`: product rules, deployment, QA, architecture, and venue dashboard design references.

## Existing Implementation Found

- Flutter already has a dark-first centralized theme layer under `lib/theme`.
- Venue portal has the dashboard shell, sidebar, status chips, overview, order queue, manual mark-paid modal, order detail, and concrete target module screens for the remaining operational routes.
- Manual payment confirmation is auditable through the `venue_update_order_payment_status` RPC and payment event records.
- Supabase remote migration state is reconciled through `20260503141000_settlement_state_trigger_compat.sql`; `supabase db push --dry-run` now reports the remote database is up to date.
- Prediction-pool RPC/function work exists around match pools, pool entries, settlement, audit logs, and venue scoping.
- The release-blocker hardening migration at `supabase/migrations/20260503130000_release_blocker_hardening.sql` is present in local migrations and the linked remote history. It adds venue wallet ledger tables/RPCs, qualifying-order eligibility checks, centralized game/session/question/answer tables, answer race-safety constraints, screen state, RLS, and grants.
- `supabase/migrations/20260503135000_fan_profile_categories.sql` was deployed to the linked remote database in this pass. It aligns fan profile categories with local, top-European, and national team selections and enforces category limits.
- `supabase/migrations/20260503141000_settlement_state_trigger_compat.sql` was deployed to the linked remote database in this pass. It keeps early settlement protection while allowing the cancelled/postponed settlement paths implemented by `settle_match_pool`.

## High-Risk Findings

- Local Supabase database validation now runs with Colima/Docker using a database-only start. `supabase db reset` replays the migration chain through `20260503141000`.
- Settlement eligibility enforcement is present through `user_has_qualifying_order(...)` and eligibility-aware settlement logic, and the SQL verification suite now covers the order-window rule, venue-linked pools, settlement permissions, and RLS grants.
- Flutter UI still contains many scattered style declarations. The central typography source exists, but broad screen-by-screen token adoption remains incomplete.
- Venue portal menu management had direct UI-owned Supabase mutations. This was refactored into the existing venue operations service as the first cleanup slice.
- Venue portal target dashboard routes have been replaced with concrete operational screens, but some high-impact actions intentionally remain permission-locked until wired to live RPCs and backend policy checks.
- Legacy onboarding/database compatibility paths mention display names; the current WhatsApp/no-name login path must remain the only required user flow.
- Credentials were exposed in chat. Repo cleanup cannot revoke them; rotate Supabase keys, database password, and access token from the provider dashboards.

## Implementation Approach

1. Keep the current architecture and improve the highest-risk modules first.
2. Centralize dashboard data mutations behind `venueOperations.ts` instead of direct component calls.
3. Strengthen the Flutter typography source of truth first, then gradually reduce screen-level hardcoded styles.
4. Add focused tests around design-system guarantees and any changed business logic.
5. Keep local Supabase validation in the release gate; full-stack service health still needs a separate pass for Realtime/Storage/Studio under Colima.
6. Run Flutter analysis/tests and venue-portal type/lint/build checks after each cleanup slice.

## Release Readiness Position

Current rating: **Ready with minor fixes** for the checked app/dashboard/database surfaces; **not ready for unattended launch** until full local service health and live dashboard action wiring are complete.

Primary remaining blockers are full Supabase service health under Colima for Realtime/Storage/Studio and wiring every newly concrete venue dashboard action to production RPCs. The linked remote database and local SQL verification suite are up to date after this pass.
