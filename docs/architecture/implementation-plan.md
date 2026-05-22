# FANZONE Hospitality Implementation Plan

## Current Implementation Review

FANZONE is already a multi-surface production codebase, not a blank scaffold. The active surfaces are:

- Flutter customer mobile app in `lib/`.
- React/Vite platform admin in `apps/admin/`.
- React/Vite venue operations portal in `apps/venue-portal/`.
- React/Vite guest web/PWA in `apps/website/`.
- React/Vite TV display in `apps/tv-display/`.
- Supabase backend in `supabase/`, with migrations, Edge Functions, SQL contract tests, RLS audits, and release scripts.

The current app already has these production primitives:

- `go_router`, Riverpod, Supabase Flutter, generated models, app config, feature access, telemetry, and route gating.
- Venue discovery, venue detail, menu browsing, cart/order placement, order tracking, receipt, payment handoff, and staff-call support.
- Manual off-platform payment handling through cash, MoMo/USSD, Revolut-link, or other instructions, with staff/admin confirmation paths.
- FET loyalty ledger, rewards, match pools, game sessions, settlement functions, admin controls, audit logs, and TV display state.
- CI for Flutter analysis/tests/builds, web builds, Edge Function checks, SQL audits, secret scanning, and release evidence.

### Audit Snapshot: 2026-05-22

Current surfaces and their roles:

| Surface | Current State | Target Direction |
| --- | --- | --- |
| Flutter customer app (`lib/`) | Feature-first modules exist for auth, onboarding, home, ordering, pools, games, profile, settings, and wallet/rewards. | Keep as the primary mobile/PWA customer surface; rename customer-facing wallet/stake/pool language toward loyalty points and challenges while preserving backend compatibility. |
| React admin (`apps/admin/`) | Active platform admin console with guarded routes and Supabase client integration. | Keep live until Flutter Web admin reaches route, role, export, audit, and UAT parity. |
| React venue portal (`apps/venue-portal/`) | Active venue operations console covering orders, rewards, targets, settings, and venue context. | Keep live; evolve into staff/KDS-grade operations if a separate Flutter staff app is not justified yet. |
| React website/PWA (`apps/website/`) | Active guest web fallback with canonical source checks and PWA metadata validation. | Keep aligned with mobile product boundaries and hospitality/rewards positioning. |
| React TV display (`apps/tv-display/`) | Active venue display surface with PWA metadata checks. | Keep as scoped realtime/game-night display; avoid whole-table realtime channels. |
| Supabase (`supabase/`) | Migrations, SQL contract tests, RLS audits, Edge Functions, cron-style scripts, and release probes exist. | Continue append-only migrations; move sensitive and multi-row writes into RPCs/Edge Functions with audit rows. |

Current backend function coverage includes order creation, order status update,
manual payment marking, payment handoff, ring bell/staff call, WhatsApp OTP,
admin onboarding, venue claims, menu ingestion, push notifications, football
data import, match alerts, and match-pool settlement.

Current SQL test coverage includes bootstrap object checks, sports-bar contract
verification, RLS hardening audit, FET supply and reward engine checks, pool
settlement/sharing, admin control-center checks, feature registry checks,
WhatsApp auth verification, and UAT fixture verification.

Primary gaps against the target hospitality brief:

- The requested Flutter Web admin replacement does not exist yet; admin is currently React/Vite.
- The product has legacy loyalty-ledger and pool-entry language that must be constrained to non-cash loyalty points and no-gambling copy.
- QR ordering was intentionally removed. The current production flow uses app-entered table numbers.
- Table-session, bill-session, kitchen-ticket, and receipt-generation concepts exist partially but need stronger canonical naming, RPC contracts, and UI coverage.
- Admin/venue operations need broader finance, menu-versioning, rewards, support, audit, and game-night workflows before venue pilot scale.
- There is now a dedicated `tool/product_boundary_scan.sh` gate for active app/admin/runtime copy; legacy SQL identifiers can remain until a planned data migration exists.
- A separate staff/KDS app is not present. The first production path should harden the existing venue portal for staff/KDS use before adding another app.
- Supabase Realtime usage needs a documented channel inventory and tests proving venue/order/game/table-session scoping.

## Product Boundaries

- Build for bars, lounges, restaurants, clubs, fan zones, and entertainment venues.
- Keep hospitality operations and entertainment engagement separate from any fintech or group-savings domain.
- Keep FET only as non-cash loyalty and rewards points. Do not implement customer cash-out, cash prizes, odds, paid prediction entry, pooled betting, or a customer fintech wallet.
- Payment execution remains configurable and off-platform for MVP: cash at venue, manual mobile money, external POS/Revolut-link instructions, and future provider integration only after explicit approval.
- Preserve current table-number ordering. Optional future table sessions must be signed, server-validated, expiring, venue-scoped, and additive.

## Target Architecture

The target architecture is additive:

```text
Flutter customer app
  -> feature-first modules
  -> Riverpod providers and gateways
  -> Supabase client with anon key only
  -> Edge Functions and Postgres RPCs for sensitive writes

Flutter Web admin replacement
  -> apps/bar_admin_portal/
  -> shared Flutter design/domain packages when reuse is proven
  -> role-guarded routes and URL state
  -> Supabase anon client plus audited RPC/Edge mutations

Existing React admin, venue portal, website, and TV display
  -> remain active until Flutter Web admin parity and migration evidence exist

Supabase
  -> append-only migrations
  -> RLS on exposed tables
  -> RPCs for atomic state transitions
  -> Edge Functions for privileged orchestration
  -> SQL tests and release probes
```

Use packages only where they remove real duplication:

- `packages/design_system` after the Flutter admin shell needs shared Flutter components.
- `packages/hospitality_domain` after both customer and admin surfaces share stable models.
- `packages/entertainment_domain` after loyalty/game contracts stabilize across customer, admin, and TV.
- Keep the existing `packages/core` for web TypeScript contracts until React surfaces are retired.

## Implementation Phases

### Phase 1: Governance And Boundary Hardening

- Add this implementation plan and `AGENTS.md`.
- Add and keep `tool/product_boundary_scan.sh` in the local go-live gate for prohibited customer/admin/runtime language around betting, odds, wagering, cash-out, cash prizes, paid prediction entries, and pooled prizes.
- Update visible customer/admin copy from wallet/stake wording to loyalty-points language where it affects active UX.
- Document current command gates and dirty-worktree caution for future agents.

### Phase 2: Hospitality Core Upgrade

- Strengthen venue discovery, venue detail, menu browsing, cart, checkout, order timeline, receipt, staff call, and order issue flows in the Flutter customer app.
- Add canonical table-session compatibility only as server-validated context over the existing table-number flow.
- Add or wrap RPCs for atomic order creation, order state transitions, manual payment recording, receipt payload generation, staff-call creation, and bill/session closure.
- Expand venue operations around live order board, staff workload, manual payment confirmation, issue handling, daily close, and audit timeline.
- Canonicalize order states as `draft`, `submitted`, `accepted`, `preparing`, `ready`, `served`, `completed`, `cancelled`, `refunded`, and `disputed`; every transition must be server-validated and written to `order_state_events`.
- Store price snapshots and inventory/availability decisions at order creation.
- Require actor, role, reason where applicable, and audit evidence for cancel, refund, void, adjustment, manager comp, and manual payment records.

### Phase 3: Flutter Web Admin Replacement

- Create `apps/bar_admin_portal/` as a Flutter Web/PWA app.
- Implement admin auth, route guards, shell, tenant/venue switcher, dashboard, audit visibility, and release/build info first.
- Add modules in this order: venues, menus/tables, orders/staff operations, finance/reports, entertainment, rewards, support/risk, feature flags/system.
- Keep `apps/admin/` available until parity tests, UAT evidence, and production deploy checks pass.
- Build with Material 3, vendored Google Fonts, the existing FANZONE tokens, and compact admin-dense layouts.
- Do not share packages until both the customer app and admin portal need the same stable Flutter component or domain model.

### Phase 3A: Staff/KDS Decision

- Treat `apps/venue-portal/` as the production staff/KDS surface first.
- Add fast tap targets, reconnect/backfill behavior, role-scoped order/ticket boards, staff calls, manual payment recording, and ticket-state transitions there.
- Create a separate Flutter staff/KDS app only if venue UAT proves a dedicated mobile/tablet install is operationally better than the portal.

### Phase 4: Entertainment And Loyalty

- Keep football predictions, quizzes, music games, table-vs-table games, event nights, leaderboards, and coupons free-to-play or loyalty-points based.
- Convert customer-visible language to points, rankings, challenges, rewards, and coupons.
- Keep settlement deterministic and reproducible, with lock times, duplicate-entry guards, late-entry rejection, audit logs, and moderation tools.
- Use Supabase Realtime only through scoped channels: order, venue order board, game/event, leaderboard, TV display, and optional table session.
- Store `rules_version`, lock time, entry timestamps, settlement inputs, and settlement outputs for each challenge/game round.
- Reject late and duplicate entries in the database or Edge Function, not only in UI.
- Rate-limit quiz submissions and prevent double reward redemption with unique constraints or idempotency keys.
- Any moderation override must include actor, role, reason, before/after payload, and audit record.

### Phase 5: Release Readiness

- Extend CI for Flutter Web admin builds, product-boundary scans, SQL/RLS tests, Edge Function tests, and web PWA metadata checks.
- Run mobile, admin, venue, TV, Supabase, and Edge validation before staging.
- Produce venue-pilot evidence: customer order flow, staff order board, manual payment, order realtime, game entry, settlement, leaderboard, reward redemption, admin reporting, and incident rollback.
- Add realtime reconnect tests for customer order tracking, venue order board, TV display, leaderboard, and optional table-session presence.
- Keep Supabase Cron/job execution observable through `tool/run_supabase_cron_job.sh`, Edge job smoke checks, and scheduler runbooks.
- Run product-boundary, secret/dependency, accessibility, performance, SQL/RLS/RPC, Edge Function, and PWA release checks before any go-live claim.

## Acceptance Criteria

- Customer Flutter app compiles and passes targeted tests.
- New Flutter Web admin app compiles before any React admin retirement.
- Existing React admin/venue/website/TV surfaces remain functional during transition.
- Supabase migrations are append-only and validate cleanly.
- RLS tests prove cross-user and cross-venue isolation for new surfaces.
- Product-boundary scan passes for active runtime surfaces.
- Table-number ordering continues to work.
- Optional table-session behavior, if added, is server-validated and expiring.
- Manual payment confirmation is audited and cannot imply automatic provider settlement.
- Entertainment remains no-betting, no-odds, no-cash-out, no-cash-prize, and no paid prediction entry.
- FET remains non-cash loyalty points, backed by ledger rows and product-safe copy.
- Go-live evidence names the exact commands, builds, devices, and linked Supabase checks used.
