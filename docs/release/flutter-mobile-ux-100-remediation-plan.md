# FANZONE Flutter Mobile 100% UX Remediation Plan

Date: 2026-06-08
Scope: Flutter customer mobile app under `lib/`.

## Goal

Bring every current FANZONE Flutter mobile screen, modal sheet, dialog, and wizard to a verifiable 2026 native Flutter mobile quality bar before any `100%` or `world-class` claim is made.

Success means all of the following are true:

- Every routed screen in `lib/app_router.dart` has compact, medium, and expanded layout coverage.
- Every modal, popup, dialog, and wizard has large-text, keyboard, screen-reader, reduced-motion, and safe-area coverage.
- The app supports system light, dark, and high-contrast theme requests without losing FANZONE brand identity.
- Navigation adapts by available window width, using bottom navigation on compact widths and a side navigation pattern on medium/expanded widths.
- Hospitality-critical missing flows are implemented: table/session validation, menu item detail/customization, allergen/age confirmation where applicable, payment proof/failure recovery, order issue/cancel/refund support, venue support, and account data/deletion request flows.
- Flutter accessibility guideline tests pass for Android tap targets, iOS tap targets, labeled tap targets, and text contrast on representative screens and all critical flows.
- Release evidence is current, source-commit-bound, and linked from the world-class evidence matrix.

## Authoritative Standards

- Flutter accessibility testing: `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline`.
- Flutter UI design accessibility: large fonts, sufficient contrast, 48 dp Android targets, 44 pt iOS targets.
- Flutter adaptive/responsive guidance: use available window size, not hardware class; avoid full-width large-screen content; branch navigation around Material breakpoints.
- Flutter `MaterialApp` theming APIs: provide `theme`, `darkTheme`, `highContrastTheme`, `highContrastDarkTheme`, and `themeMode`.
- Apple HIG and platform conventions for navigation, sheets, dialogs, permissions, and accessibility.
- FANZONE product rules: no betting, odds, wagering, cash-out, customer wallet, or platform payment execution.

## Route Inventory Contract

The remediation covers these route groups from `lib/app_router.dart`:

- Entry/auth: `/splash`, `/onboarding`, `/login`, `/upgrade`, `/feature-unavailable`.
- Home/sports: `/home`, `/home/matches`, `/search`, `/match/:id`.
- Venues/order: `/v/:venueSlug`, `/bar`, `/venue/:venueId`, `/venues`, `/venues/location`, `/checkout`, `/orders`, `/order/:orderId`, `/order/:orderId/success`, `/order/:orderId/receipt`.
- Pools/games: `/pools`, `/pools/:shareSlug`, `/pool/:poolId`, `/pool/:poolId/join`, `/pools/create`, `/pools/games`, `/game/:gameId`.
- Account/settings: `/notifications`, `/profile`, `/wallet`, `/wallet/transaction/:transactionId`, `/settings`, `/settings/privacy`, `/settings/help`, `/settings/privacy-policy`, `/settings/terms`.

## Implementation Phases

## Current Progress

Completed on 2026-06-08:

- Phase 0 foundation started: shader-dependent ink effects were replaced with stable Material ripples, and `FzCard` now provides a Material surface for embedded rows and focus/ink behavior.
- Phase 1 foundation started: the app shell now switches from bottom navigation on compact widths to a `NavigationRail` on medium and expanded widths.
- Phase 2 foundation started: `MaterialApp.router` now wires light, dark, high-contrast light, and high-contrast dark themes through `ThemeMode.system`.
- Phase 4 foundation started: menu item detail/customization now uses a scroll-safe bottom sheet with add-ons, prep notes, allergen confirmation, age-restriction confirmation, and unavailable-item handling; configured add-ons and notes flow through the existing cart/order DTO path.
- Phase 4 foundation continued: order tracking now collects optional external payment reference and verification notes before submitting proof to the existing venue-confirmed payment RPC; this does not mark customer payments as paid in the app.
- Phase 4 foundation continued: order tracking now exposes staff-reviewed issue, cancellation, and refund-review request sheets through the existing staff bell channel; these requests do not mutate order or payment status client-side.
- Phase 5 foundation started: `release/qa/flutter-mobile-ux-matrix.json` now tracks every current Flutter mobile route, redirect, wizard, modal sheet, dialog, and reusable modal component; `tool/validate_flutter_mobile_ux_matrix.mjs` validates inventory coverage and provides strict `--require-pass` mode for the final 100% gate.

Still required before any `100%` claim:

- Route and overlay inventory validation must be promoted from inventory mode to strict `--require-pass` mode after every matrix row has current evidence.
- Large-text, keyboard, reduced-motion, and screen-reader tests must be expanded across every route group and overlay group.
- Feature screens still need hard-coded color/style cleanup against the design system.
- Hospitality-critical flows in Phase 4 still need table/session validation, deeper failed-payment recovery states, venue support/contact beyond table-scoped staff requests, account request flows, and backend/audit evidence.
- The screen-by-screen completion matrix exists, but most rows are still `partial` or `planned`; they must become evidence-backed `pass` rows before the world-class gate can claim completion.

### Phase 0 - Stabilize Current Gates

Purpose: make the current test stack reliable enough to detect real UI regressions.

- Replace shader-dependent ink effects that break widget tests with stable Material ripples.
- Ensure `FzCard` provides a proper `Material` surface so embedded `ListTile` ink and focus states are visible.
- Add a route/screen inventory test that fails when a new routed screen lacks an explicit UX audit entry.
- Add a modal/sheet inventory test that fails when new `showModalBottomSheet` or `showDialog` calls are not registered.
- Run `node tool/validate_flutter_mobile_ux_matrix.mjs` to fail inventory drift before release evidence is assembled.
- Evidence: `flutter test test/screen_widgets_test.dart test/accessibility_audit_test.dart test/app_router_test.dart test/design_tokens_test.dart`.

### Phase 1 - Adaptive App Shell

Purpose: make the app usable across compact phones, landscape phones, tablets, foldables, iPad, and resizable windows.

- Introduce shared breakpoint tokens: compact `<600`, medium `600-839`, expanded `>=840`.
- Refactor `AppShell` to use bottom navigation on compact widths and `NavigationRail` or equivalent side navigation on medium/expanded widths.
- Preserve `StatefulShellRoute.indexedStack` state across breakpoint changes.
- Move fixed nav height/label sizing into tokenized constraints that survive 200% text scale.
- Add widget tests for compact, medium, expanded, landscape, and keyboard-open states.
- Evidence: adaptive shell tests plus screenshots in release evidence.

### Phase 2 - Theme and Design-System Completion

Purpose: remove dark-only compatibility and hard-coded feature styling.

- Add real `FzTheme.light()`, `FzTheme.highContrastLight()`, and `FzTheme.highContrastDark()`.
- Wire `MaterialApp.router` with `theme`, `darkTheme`, `highContrastTheme`, `highContrastDarkTheme`, and `themeMode: ThemeMode.system`.
- Convert feature screens away from raw colors/text styles where design tokens already exist.
- Add token tests for light/dark/high-contrast contrast ratios.
- Add golden/component states for loading, empty, error, disabled, focused, selected, and pressed states.
- Evidence: design token tests, design-system golden tests, contrast tests.

### Phase 3 - Accessibility Across Screens and Overlays

Purpose: every user-visible surface works with assistive technologies.

- Add semantics labels to custom `GestureDetector` controls or replace them with Material buttons/list tiles.
- Add focus traversal order for OTP, checkout, pool creation, profile editing, and payment handoff flows.
- Make sheets scroll-safe at 200% text scale and with the keyboard open.
- Respect reduced motion in onboarding, counters, animated entries, and route transitions.
- Add representative accessibility tests for all route groups and all overlay groups.
- Evidence: Flutter accessibility guideline tests, large-text widget tests, Android Accessibility Scanner and iOS Accessibility Inspector evidence when devices are available.

### Phase 4 - Hospitality Flow Completion

Purpose: close product gaps for real sports-bar ordering and support without violating product boundaries.

- Table/session validation: add a server-validated table/session check-in flow that keeps manual table number ordering as the fallback.
- Menu item detail/customization: add item detail sheet with options, add-ons, allergens, dietary flags, prep notes, and unavailable states.
- Allergen/age confirmation: add confirmation flows before adding restricted or sensitive items.
- Payment proof/failure recovery: add reference/proof capture for off-platform handoff and a failed-payment recovery path.
- Order support: add order issue, cancel request, refund request, and venue support flows with audit events.
- Venue support/contact: add in-app support ticket or venue contact flow from venue, order, receipt, and settings surfaces.
- Account data/deletion: replace static-only support text with request screens backed by existing account services.
- Evidence: provider tests, widget tests, integration tests, Supabase/RPC or Edge Function tests where server state changes are introduced.

### Phase 5 - Screen-by-Screen Completion Matrix

Purpose: make `100%` auditable instead of subjective.

- Create a machine-readable checklist for every route and overlay.
- Required row fields: route/surface, compact proof, medium proof, expanded proof, large-text proof, screen-reader proof, contrast proof, error/empty/loading proof, product-boundary proof, tests, evidence path, owner, status.
- Generate a Markdown summary from the checklist for release docs.
- Block `tool/check_world_class_evidence.sh` until every P0/P1 mobile row is `PASS`.
- Evidence: `release/qa/flutter-mobile-ux-matrix.json`, `tool/validate_flutter_mobile_ux_matrix.mjs`, and final strict validation with `node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass`.

### Phase 6 - Release Evidence and Go/No-Go

Purpose: only claim completion when current source proves it.

- Run `dart format --output=none --set-exit-if-changed lib test integration_test tool`.
- Run `./tool/flutter_analyze_release.sh`.
- Run targeted flow tests and full `flutter test --coverage`.
- Run `flutter build apk --debug`.
- Run `./tool/product_boundary_scan.sh`.
- Run `./tool/go_live_readiness.sh --local`.
- Run `./tool/check_world_class_evidence.sh`.
- Update `docs/release/world-class-evidence-matrix.md` and `docs/release/production-go-live-task-register.md` only after evidence exists.

## Completion Rules

- `100% compliant` is not a design opinion. It requires passing tests, current screenshots/device evidence, and a complete checklist row for every route and overlay.
- A screen cannot be marked complete while it has unproven large-text, contrast, tap-target, focus, reduced-motion, loading, empty, error, or product-boundary behavior.
- External/manual blockers must stay separate from code-owned blockers.
- Any database-backed hospitality flow must use append-only migrations and server-side authorization.
