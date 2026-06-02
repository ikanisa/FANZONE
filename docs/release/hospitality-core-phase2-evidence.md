# Hospitality Core Phase 2 Evidence

Date: 2026-05-23

Scope: table-number ordering lifecycle hardening, venue/staff order workflow alignment, manual payment wrapper and reconciliation boundaries, customer order tracking labels, scoped realtime guardrails, FET rewards-ledger product-boundary copy, and release evidence for the active Flutter, React/Vite admin, venue portal, website, and Supabase surfaces.

## Verified Locally

- Shared order lifecycle helpers exist in `packages/core/src/orderLifecycle.ts` for venue portal active-order counts and valid next actions.
- Flutter order status labels map legacy `placed` to `Submitted` and `received` to `Accepted`.
- Customer order tracking renders the target lifecycle: `Submitted`, `Accepted`, `Preparing`, `Ready`, `Served`, and `Completed`.
- `order_update_status` validates target and legacy order statuses through the shared Edge lifecycle list, then delegates to `venue_transition_order_status`.
- `order_mark_paid` remains a compatibility wrapper over `venue_update_order_payment_status`.
- `20260523140000_manual_payment_note_requirement.sql` requires actor notes for manual paid, partial, refund, and dispute payment status updates.
- `supabase/functions/order_update_status/order_update_status_contract_test.ts` and `supabase/functions/order_mark_paid/order_mark_paid_contract_test.ts` assert the compatibility-wrapper contracts for canonical RPC delegation, legacy status compatibility, and manual/off-platform payment method limits. `tool/order_edge_boundary_scan.mjs` guards that the wrappers do not directly write `orders`, `order_state_events`, or `payment_events`.
- `20260523120000_manual_payment_reconciliation.sql` adds the read-only `venue_manual_payment_reconciliation(uuid, date)` RPC for venue-scoped daily-close/manual payment summaries from `payment_events`; it reports `provider_api_used` and does not execute provider APIs.
- `supabase/tests/manual_payment_reconciliation_readiness.sql` and `tool/supabase_manual_payment_reconciliation_smoke.sh` provide a non-mutating readiness gate for that reconciliation RPC.
- `supabase/tests/manual_payment_reconciliation_contract.sql` provides a rollback-based SQL contract for venue-scoped daily-close summaries, amount/reference/provider evidence, and cross-venue reconciliation denial.
- Venue portal Insights now consumes `venue_manual_payment_reconciliation` through `usePaymentReconciliation`, displays daily-close totals by business date, and refreshes through a venue-scoped `orders` realtime filter.
- `tool/order_edge_boundary_scan.mjs` now also protects `order_create`: table-number resolution, venue-scoped menu lookup, server-side price snapshots, submitted initial status, initial `order_state_events` write, cleanup on failed item/event writes, and no `card` payment method.
- `supabase/functions/order_create/order_create_contract_test.ts` covers the same order-create contract in the Deno Edge Function test suite.
- Flutter checkout/payment handoff now rejects unsafe non-HTTPS Revolut launch URLs and ignores unsupported `card` methods returned by handoff payloads.
- Flutter order tracking now exposes a `Call staff` order issue path when the order has a resolved table. It uses the existing `ring_bell` Edge Function through `bellGatewayProvider` and includes the order code in the bell message.
- `20260523130000_staff_call_acknowledgement_rpc.sql` adds `venue_acknowledge_bell_request(uuid)`, an audited venue-scoped RPC for staff-call acknowledgement. The venue portal now uses that RPC instead of directly updating `bell_requests`.
- `supabase/tests/staff_call_acknowledgement_readiness.sql` and `tool/supabase_staff_call_acknowledgement_smoke.sh` provide a non-mutating readiness gate for the staff-call acknowledgement RPC.
- `supabase/tests/staff_call_acknowledgement_contract.sql` provides a rollback-based SQL contract for successful acknowledgement, idempotent re-acknowledgement, cross-venue denial, audit evidence, and direct authenticated `bell_requests` update rejection.
- `tool/flutter_ordering_boundary_scan.mjs` protects the Flutter customer ordering path: table-number checkout, server-created order payload boundaries, external payment handoff/submission boundaries, scoped order realtime, order-linked staff call, and no required QR ordering dependency.
- Product-boundary release scan now also runs:
  - `tool/scoped_realtime_scan.mjs`
  - `tool/order_edge_boundary_scan.mjs`
  - `tool/order_lifecycle_parity_scan.mjs`
  - `tool/venue_portal_hospitality_scan.mjs`
  - `tool/entertainment_reward_boundary_scan.mjs`
  - `tool/flutter_ordering_boundary_scan.mjs`
- Active customer/operator copy now uses rewards-ledger language instead of customer wallet language for FET surfaces while preserving legacy internal route/service/schema identifiers.
- `tool/product_boundary_scan.sh` now rejects active runtime copy such as `FET wallet`, `wallet balance`, `wallet transfer`, `open wallet`, `Buy FET`, stake-style paid-entry language, pot language, and FET winnings language so FET remains positioned as non-cash loyalty/rewards points.
- Customer FET transfer UX is no longer exposed in the Flutter rewards screen or website rewards hub. Client transfer methods fail closed with a rewards-ledger boundary message, and `tool/product_boundary_scan.sh` now rejects customer transfer copy such as `Send FET`, `FET transfer`, `Recipient Fan ID`, and `Confirm Transfer` in active runtime surfaces.
- Venue portal PWA metadata now uses FET rewards-ledger language, and `tool/validate_pwa_release_metadata.mjs` rejects wallet-language metadata in `index.html` and `site.webmanifest`.
- `tool/venue_portal_hospitality_scan.mjs` statically protects the active staff/KDS surface boundaries: scoped venue order/bell realtime, canonical lifecycle actions, audited manual payment details, order state timeline loading, and no direct `orders`, `payment_events`, or `order_state_events` writes from the portal.
- `tool/venue_portal_hospitality_scan.mjs` also requires the daily-close reconciliation UI/hook/RPC path and rejects direct `payment_events` realtime subscriptions.
- `supabase/tests/order_lifecycle_deployment_readiness.sql` and `tool/supabase_order_lifecycle_smoke.sh` provide a non-mutating deployment readiness gate for the linked Supabase lifecycle schema/RPC/RLS shape. `tool/supabase_live_validation.sh` now includes this readiness gate.
- `tool/supabase_hospitality_core_phase2.sh` is the consolidated Supabase validation entrypoint for the lifecycle, manual payment reconciliation, and staff-call acknowledgement readiness/contract checks.
- `20260522150000_order_lifecycle_hardening.sql` explicitly revokes direct client `INSERT`, `UPDATE`, and `DELETE` on `order_state_events`; lifecycle writes must come from audited RPC/Edge paths.
- `venue_transition_order_status` now rejects transitions into `cancelled`, `refunded`, or `disputed` unless an operator reason is provided. The active venue portal order board and order detail surfaces prompt for that reason before calling `order_update_status`.
- `test/core_order_lifecycle_test.ts` verifies the app/shared lifecycle helpers normalize legacy statuses, expose valid next actions, and require reasons for `cancelled`, `refunded`, and `disputed`.
- `supabase/tests/order_lifecycle_deployment_readiness.sql` now fails if anonymous users can read `order_state_events` or authenticated clients can mutate lifecycle events directly.
- `supabase/tests/order_lifecycle_deployment_readiness.sql` now also checks the manual payment RPC definition for payment event evidence, amount/reference capture, `provider_api_used=false`, and audit logging requirements.
- `supabase/tests/staff_call_acknowledgement_readiness.sql` checks that authenticated clients do not have direct `UPDATE` grants on `bell_requests`; staff acknowledgements must go through the audited RPC.
- `tool/entertainment_reward_boundary_scan.mjs` protects the entertainment/rewards boundaries across SQL contracts, the settlement Edge Function, admin pool operations, and venue portal game/pool operations.
- `tool/supabase_release_readiness_hardening.sh` runs the non-mutating SQL release-readiness contract for pool settlement idempotency, game-answer duplicate guards, game settlement eligibility, reward ledger paths, payment-submission audit behavior, and restricted grants. This linked Supabase check passed on 2026-05-23.

## Passing Commands

```bash
node tool/scoped_realtime_scan.mjs
node tool/order_edge_boundary_scan.mjs
node tool/order_lifecycle_parity_scan.mjs
node tool/venue_portal_hospitality_scan.mjs
node tool/entertainment_reward_boundary_scan.mjs
node tool/flutter_ordering_boundary_scan.mjs
./tool/product_boundary_scan.sh
./tool/supabase_release_readiness_hardening.sh
bash -n tool/supabase_manual_payment_reconciliation_smoke.sh tool/supabase_staff_call_acknowledgement_smoke.sh tool/supabase_live_validation.sh tool/go_live_readiness.sh
bash -n tool/supabase_hospitality_core_phase2.sh
supabase db push --dry-run
deno fmt --check packages/core/src/orderLifecycle.ts test/core_order_lifecycle_test.ts supabase/functions/_shared/order_lifecycle.ts supabase/functions/_shared/order_lifecycle_test.ts
deno check supabase/functions/order_create/index.ts supabase/functions/order_update_status/index.ts supabase/functions/order_mark_paid/index.ts supabase/functions/_shared/order_lifecycle.ts
deno test supabase/functions/_shared/order_lifecycle_test.ts supabase/functions/order_create/order_create_contract_test.ts supabase/functions/order_update_status/order_update_status_contract_test.ts supabase/functions/order_mark_paid/order_mark_paid_contract_test.ts
deno test test/core_order_lifecycle_test.ts
npm run typecheck -w @fanzone/core
npm run typecheck -w @fanzone/admin
npm run typecheck -w @fanzone/venue-portal
npm run typecheck -w @fanzone/website
npm run lint --workspaces --if-present
npm run lint -w @fanzone/venue-portal
npm run test -w @fanzone/venue-portal
npm run test -w @fanzone/admin
npm run test -w @fanzone/website
node tool/validate_pwa_release_metadata.mjs admin
node tool/validate_pwa_release_metadata.mjs tv-display
npm run validate:release-metadata -w @fanzone/website
npm run build -w @fanzone/admin
npm run build -w @fanzone/venue-portal
npm run build -w @fanzone/website
dart format --output=none --set-exit-if-changed lib test
flutter test test/checkout_payment_handoff_test.dart test/order_model_test.dart test/order_tracking_screen_test.dart
flutter test test/screen_widgets_test.dart test/order_tracking_screen_test.dart test/order_model_test.dart
flutter test test/feature_flow_integration_test.dart test/wallet_model_test.dart test/screen_widgets_test.dart
./tool/flutter_analyze_release.sh
```

## Linked Supabase Status

`supabase db push --dry-run` against the linked project completed without pushing and reported the four pending Phase 2 migrations:

```text
20260522150000_order_lifecycle_hardening.sql
20260523120000_manual_payment_reconciliation.sql
20260523130000_staff_call_acknowledgement_rpc.sql
20260523140000_manual_payment_note_requirement.sql
```

Because that migration is not yet applied to the linked database, the strengthened `supabase/tests/order_lifecycle_contract.sql` cannot pass there yet. The attempted linked contract run failed on missing `order_status` enum values for the Phase 2 lifecycle.

The new non-mutating readiness gate confirms the same live blocker:

```bash
./tool/supabase_order_lifecycle_smoke.sh --readiness
```

```text
Missing order_status enum values: {draft,submitted,accepted,ready,completed,refunded,disputed}
```

The consolidated Hospitality Core Phase 2 wrapper was also run against the linked project:

```bash
./tool/supabase_hospitality_core_phase2.sh --readiness
./tool/supabase_hospitality_core_phase2.sh --contract
```

Both modes currently stop on the same missing Phase 2 order lifecycle enum values until `20260522150000_order_lifecycle_hardening.sql` is applied.

The manual payment reconciliation readiness gate was also run against the linked project without applying migrations:

```bash
./tool/supabase_manual_payment_reconciliation_smoke.sh
```

```text
Missing payment_events_created_at_idx
```

That is expected until `20260523120000_manual_payment_reconciliation.sql` is applied through the normal migration release process.

The rollback-based manual payment reconciliation contract was also attempted against the linked project:

```bash
./tool/supabase_manual_payment_reconciliation_smoke.sh --contract
```

```text
Missing venue_manual_payment_reconciliation RPC
```

That is expected until the manual payment reconciliation migration is applied.

The staff-call acknowledgement readiness gate currently reports that the linked project still allows direct authenticated `bell_requests` updates:

```bash
./tool/supabase_staff_call_acknowledgement_smoke.sh
```

```text
Authenticated clients must acknowledge bell_requests through venue_acknowledge_bell_request, not direct table UPDATE grants
```

`20260523130000_staff_call_acknowledgement_rpc.sql` revokes that direct `UPDATE` grant and adds the audited RPC.

The rollback-based staff-call acknowledgement contract was also attempted against the linked project:

```bash
./tool/supabase_staff_call_acknowledgement_smoke.sh --contract
```

```text
Missing venue_acknowledge_bell_request RPC
```

That is expected until the staff-call acknowledgement migration is applied.

## Required Before Live Signoff

- Apply `20260522150000_order_lifecycle_hardening.sql` to the linked Supabase project through the normal migration release process.
- Apply `20260523120000_manual_payment_reconciliation.sql` to the linked Supabase project through the normal migration release process.
- Apply `20260523130000_staff_call_acknowledgement_rpc.sql` to the linked Supabase project through the normal migration release process.
- Apply `20260523140000_manual_payment_note_requirement.sql` to the linked Supabase project through the normal migration release process.
- Keep the current `supabase db push --dry-run` output with release evidence and rerun it if any migration changes before apply.
- Rerun `./tool/supabase_order_lifecycle_smoke.sh --readiness`.
- Rerun `./tool/supabase_order_lifecycle_smoke.sh --contract`.
- Rerun `./tool/supabase_manual_payment_reconciliation_smoke.sh`.
- Rerun `./tool/supabase_manual_payment_reconciliation_smoke.sh --contract`.
- Rerun `./tool/supabase_staff_call_acknowledgement_smoke.sh`.
- Rerun `./tool/supabase_staff_call_acknowledgement_smoke.sh --contract`.
- Rerun `./tool/supabase_hospitality_core_phase2.sh --readiness`.
- Rerun `./tool/supabase_hospitality_core_phase2.sh --contract`.
- Capture passing evidence for:
  - valid and invalid status transitions;
  - cross-venue staff transition rejection;
  - customer read-only access to their own `order_state_events`;
  - manual payment confirmation `payment_events` and `audit_logs` writes;
  - venue-scoped manual payment reconciliation summary access;
  - unsupported `card` manual payment rejection.
  - venue-scoped staff-call acknowledgement and audit logging.
