# FANZONE P0 Launch Execution Plan — 2026-04-19

## Purpose

This document converts the benchmark report into a strict launch execution plan.

It is anchored to the primary UI reference at [`/Users/jeanbosco/Downloads/FANZONE`](</Users/jeanbosco/Downloads/FANZONE/src/App.tsx:67>). External benchmarks remain additive. The goal is not to “improve the app” in the abstract. The goal is to ship a coherent, non-gambling, Malta-first football fan product that is trustworthy enough to launch and disciplined enough to scale.

## Non-negotiable launch gates

FANZONE should not launch until all of the following are true.

1. Mobile is green.
   - `flutter analyze` passes.
   - `flutter test` passes.
   - core flows have integration coverage.
2. Core football data is authoritative.
   - AI-search extraction is not the primary source of live match state or odds-like data.
3. Sensitive admin mutations are server-authenticated.
   - no client-side direct status mutation for redemptions
   - no client-authored audit records for sensitive actions
4. Wallet and settlement integrity are provable.
   - settlement remainder handling matches governance rules
   - supply and ledger reconciliations can be run and explained
5. The mobile product center is coherent.
   - the shipping app behaves like the reference concept: prediction-first, fan identity/social/wallet-supportive, football-utility-fast
6. Production observability exists.
   - crash reporting
   - function logging review
   - launch-day alerting for settlement, notifications, and ingestion freshness

## Execution order

### Phase 0: Release blockers

Duration target: 2 to 4 days

Ship nothing else before these are closed.

### Phase 1: Product-center realignment

Duration target: 5 to 8 days

This aligns the shipped app to the prototype reference.

### Phase 2: Trust and operations hardening

Duration target: 5 to 10 days

This makes the system launch-safe.

### Phase 3: Malta-first launch polish

Duration target: 3 to 5 days

This is for local activation, not architecture repair.

## Workstream A: Mobile product realignment to the reference

### A1. Rebuild the home screen around immediate football value

Problem:

- The reference home gets to `Predictions`, `Live Action`, and `Upcoming` almost immediately ([`HomeFeed.tsx`](</Users/jeanbosco/Downloads/FANZONE/src/components/HomeFeed.tsx:78>)).
- The current Flutter home makes the user pass through Fan Identity, featured event, launch strategy, and action-grid layers before live football ([`matchday_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/home/screens/matchday_hub_screen.dart:100>)).

Files:

- [`lib/features/home/screens/matchday_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/home/screens/matchday_hub_screen.dart:67>)
- [`lib/widgets/fan/fan_identity_widgets.dart`](</Volumes/PRO-G40/FANZONE/lib/widgets/fan/fan_identity_widgets.dart:332>)
- [`lib/widgets/common/featured_event_banner.dart`](</Volumes/PRO-G40/FANZONE/lib/widgets/common/featured_event_banner.dart:15>)

Required changes:

- Move live football and prediction-ready matches above most strategy and explainer modules.
- Change the top impression from “platform orientation” to “football action plus prediction.”
- Keep Fan Identity and featured events, but demote them below the first live/upcoming block unless there is a hard launch-specific reason not to.
- Replace the current `MATCHDAY HUB` framing with copy closer to the reference product center.

Acceptance criteria:

- The first screenful shows:
  - product title aligned to prediction-first behavior
  - direct action to prediction flow
  - direct action to Fan ID or identity surface
  - live football block
  - upcoming block
- No more than one non-core promotional/explainer card appears before live football.

### A2. Tighten match detail into a benchmark-grade prediction-plus-football surface

Problem:

- Match detail structure is good, but still below FotMob / SofaScore / Flashscore depth and scan speed.

Files:

- [`lib/features/home/screens/match_detail_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/home/screens/match_detail_screen.dart:69>)
- related tabs under [`lib/features/home/widgets/match_detail`](</Volumes/PRO-G40/FANZONE/lib/features/home/widgets/match_detail)

Required changes:

- Keep `Predict` first.
- Add clearer rule and timing context around prediction availability and settlement.
- Make live context tighter:
  - match state
  - source/trust cue
  - alert state
  - fast team/competition follow controls
- Improve compactness in stats, lineups, and overview.

Acceptance criteria:

- A user can open a match and answer all of these in under 10 seconds:
  - Is this live, upcoming, or finished?
  - Can I still predict?
  - What happens if I join a pool or challenge?
  - Can I turn on alerts here?
  - Where do I get lineups and stats?

### A3. Make the wallet express the product’s real edge

Problem:

- The reference wallet foregrounds `Club Earnings Split` and the tier ladder ([`WalletHub.tsx`](</Users/jeanbosco/Downloads/FANZONE/src/components/WalletHub.tsx:72>)).
- The shipping wallet foregrounds balance and actions but under-explains the club-economy mechanic ([`wallet_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/wallet/screens/wallet_screen.dart:74>)).

Files:

- [`lib/features/wallet/screens/wallet_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/wallet/screens/wallet_screen.dart:41>)
- [`lib/services/wallet_service.dart`](</Volumes/PRO-G40/FANZONE/lib/services/wallet_service.dart:18>)

Required changes:

- Add a first-class split module above or immediately below the balance hero.
- Show current membership tier and exact user-vs-club split.
- Make Fan ID semantics explicit in transfer UX.
- Make reward and redemption status clearer from the wallet.

Acceptance criteria:

- A user can explain:
  - how FET moves
  - how club split works
  - what their current tier means
  - how to send using Fan ID
without leaving the wallet surface.

### A4. Turn identity, club support, and social into one progression ladder

Problem:

- The product already has Fan ID, clubs, membership, contributions, and social.
- These still feel like separate screens instead of one identity system.

Files:

- [`lib/features/community/screens/clubs_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/community/screens/clubs_hub_screen.dart:107>)
- [`lib/features/community/screens/membership_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/community/screens/membership_hub_screen.dart:495>)
- [`lib/features/social/screens/social_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/social/screens/social_hub_screen.dart:83>)
- [`lib/features/identity`](</Volumes/PRO-G40/FANZONE/lib/features/identity>)

Required changes:

- Make the progression explicit:
  - choose club
  - activate Fan ID
  - join membership tier
  - contribute/support
  - challenge friends
  - redeem locally
- Reduce duplicate explanations across these surfaces.
- Strengthen “friends” beyond pool adjacency where possible.

Acceptance criteria:

- The user can tell what the next identity step is from every identity-related screen.

## Workstream B: Flutter release hardening

### B1. Fix current compile and test failures

Files:

- [`lib/features/community/screens/membership_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/community/screens/membership_hub_screen.dart:542>)
- [`lib/widgets/match/match_list_widgets.dart`](</Volumes/PRO-G40/FANZONE/lib/widgets/match/match_list_widgets.dart:14>)
- [`test/app_config_test.dart`](</Volumes/PRO-G40/FANZONE/test/app_config_test.dart:17>)
- [`lib/config/app_config.dart`](</Volumes/PRO-G40/FANZONE/lib/config/app_config.dart:21>)

Required changes:

- Resolve the missing `TeamAvatar` dependency or import path in membership screens.
- Reconcile the feature-flag contract between code and tests.

Acceptance criteria:

- `flutter analyze` exits 0
- `flutter test` exits 0

### B2. Add integration coverage for the launch-critical flows

Problem:

- There is no `integration_test/` directory.
- A product with auth, wallet, prediction, rewards, and alerts needs end-to-end confidence.

Target flows:

- onboarding to home
- open match and create prediction
- join or create pool
- open wallet and start transfer flow
- open rewards and redemption flow
- enable match alerts

Required changes:

- Create `integration_test/`
- add environment-safe test fixtures or stubs
- add CI execution for at least smoke E2E

Acceptance criteria:

- At least one happy-path integration suite runs in CI for the six critical flows above.

### B3. Enforce repository boundaries around Supabase access

Problem:

- Supabase access is distributed across `providers` and `services`.

Evidence:

- [`wallet_service.dart`](</Volumes/PRO-G40/FANZONE/lib/services/wallet_service.dart:18>)
- [`pool_service.dart`](</Volumes/PRO-G40/FANZONE/lib/services/pool_service.dart:18>)
- [`notification_service.dart`](</Volumes/PRO-G40/FANZONE/lib/services/notification_service.dart:25>)
- [`teams_provider.dart`](</Volumes/PRO-G40/FANZONE/lib/providers/teams_provider.dart:12>)

Required changes:

- Define a repository boundary for:
  - matches
  - challenges/pools
  - wallet
  - identity/community
  - notifications
- Move raw table queries behind repositories.
- Keep providers focused on composition and state, not data ownership.

Acceptance criteria:

- Launch-critical features no longer query Supabase tables directly from both provider and service layers.

### B4. Production observability and environment discipline

Files:

- [`env/production.json`](</Volumes/PRO-G40/FANZONE/env/production.json:1>)
- [`pubspec.yaml`](</Volumes/PRO-G40/FANZONE/pubspec.yaml:31>)

Required changes:

- Enable real production Sentry DSN.
- document environment validation
- add startup guardrails for missing critical defines

Acceptance criteria:

- Production build reports startup, fatal, and screen-level crashes to Sentry.

## Workstream C: Data and settlement hardening

### C1. Remove AI-search extraction from any launch-critical football data path

Problem:

- `gemini-sports-data` asks Gemini plus Google Search for live match state and 1X2 odds ([`gemini.ts`](</Volumes/PRO-G40/FANZONE/supabase/functions/gemini-sports-data/gemini.ts:24>)).

Files:

- [`supabase/functions/gemini-sports-data/gemini.ts`](</Volumes/PRO-G40/FANZONE/supabase/functions/gemini-sports-data/gemini.ts:24>)
- [`supabase/functions/gemini-sports-data/handler.ts`](</Volumes/PRO-G40/FANZONE/supabase/functions/gemini-sports-data/handler.ts:27>)

Required changes:

- Reclassify this function as enrichment-only or internal fallback tooling.
- Do not use it as the primary source for:
  - live match score/state
  - event timeline
  - anything settlement-adjacent
  - any user-facing odds-like framing used for trust-critical decisions
- Introduce a source strategy abstraction so authoritative sports feeds can become the primary provider.

Acceptance criteria:

- Launch-critical football objects are sourced from an authoritative data provider or clearly labeled non-authoritative content enrichments.

### C2. Reconcile settlement logic with token governance

Problem:

- The original hardening migration used integer division for payout ([`20260418031500_fullstack_hardening.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260418031500_fullstack_hardening.sql:67>)).
- The authoritative settlement implementation now distributes dust deterministically in [`20260418121500_p0_hardening_fixups.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:667>).
- The remaining launch requirement is operator-grade reconciliation against the governance rules ([`fet-supply-governance.md`](</Volumes/PRO-G40/FANZONE/docs/fet-supply-governance.md:31>)).

Files:

- [`supabase/migrations/20260418121500_p0_hardening_fixups.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:667>)
- [`supabase/migrations/20260419150000_pool_settlement_reconciliation.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260419150000_pool_settlement_reconciliation.sql:1>)
- [`docs/fet-supply-governance.md`](</Volumes/PRO-G40/FANZONE/docs/fet-supply-governance.md:25>)

Required changes:

- Keep the deterministic extra-unit distribution policy as the authoritative rule.
- Expose a repeatable reconciliation report for settled and cancelled pools.
- Update governance and ops docs to point to the authoritative implementation.

Acceptance criteria:

- For every settled or cancelled pool, total entry payouts and total wallet credits reconcile exactly with `total_pool_fet`.
- Operators can query settlement integrity without direct table mutation access.

### C3. Add reconciliation and integrity tooling

Required changes:

- Create repeatable admin-safe or ops-safe scripts/RPCs for:
  - wallet balance reconciliation
  - supply reconciliation
  - challenge settlement reconciliation
  - redemption accounting reconciliation

Acceptance criteria:

- Operators can produce a deterministic reconciliation report on demand.

## Workstream D: Admin and back-office hardening

### D1. Move redemptions to server-side admin commands

Problem:

- Redemptions are updated directly from the client:
  - approve
  - reject
  - fulfill

Evidence:

- [`admin/src/features/redemptions/useRedemptions.ts`](</Volumes/PRO-G40/FANZONE/admin/src/features/redemptions/useRedemptions.ts:46>)

Required changes:

- Replace direct updates with admin RPCs or edge functions:
  - `admin_approve_redemption`
  - `admin_reject_redemption`
  - `admin_fulfill_redemption`
- centralize validation, code generation, audit logging, and role checks server-side

Acceptance criteria:

- Browser cannot directly change redemption status through raw table update for launch-critical workflows.

### D2. Replace client-authored audit logging

Problem:

- The current admin hook inserts directly into `admin_audit_logs` from the browser ([`useAuditLog.ts`](</Volumes/PRO-G40/FANZONE/admin/src/hooks/useAuditLog.ts:33>)).

Required changes:

- Audit log entries for sensitive workflows must be emitted by the server-side mutation path itself.
- Client may still emit low-risk view events if desired, but not authoritative operator actions.

Acceptance criteria:

- Every sensitive admin action has a server-authored audit entry.

### D3. Expand global search into a real operator search

Problem:

- Current search only looks at `matches` and `partners` ([`useGlobalSearch.ts`](</Volumes/PRO-G40/FANZONE/admin/src/hooks/useGlobalSearch.ts:91>)).

Required changes:

- Expand search coverage to:
  - users
  - wallets
  - token transactions
  - redemptions
  - challenges
  - moderation cases
  - partners
  - fixtures
- add result grouping and direct deep links

Acceptance criteria:

- An operator can locate a user, wallet, redemption, pool, or flagged transfer from one search bar.

### D4. Make the dashboard investigation-first

Files:

- [`admin/src/features/dashboard`](</Volumes/PRO-G40/FANZONE/admin/src/features/dashboard>)

Required changes:

- Every alert card should deep-link to a filtered operational queue.
- Promote:
  - suspicious transfers
  - redemption disputes
  - settlement failures
  - ingestion freshness failures
  - notification delivery failures

Acceptance criteria:

- The dashboard is not just KPIs. It is a real morning operations console.

## Workstream E: Malta-first launch packaging

### E1. Local reward and partner trust layer

Required changes:

- On user-facing reward and redemption surfaces:
  - show partner identity clearly
  - show redemption rules clearly
  - show dispute/support path clearly

Acceptance criteria:

- A Malta user understands exactly what is redeemable, where, and what happens if something goes wrong.

### E2. Non-gambling language and rule system

Required changes:

- Audit all user-facing copy for sportsbook bleed:
  - odds-like tone
  - staking ambiguity
  - payout phrasing that sounds cash-equivalent
- clarify:
  - free-to-play
  - non-cash
  - FET fan engagement token semantics
  - social challenge rules
  - settlement source and void conditions

Acceptance criteria:

- Legal/compliance review can clearly distinguish FANZONE from gambling positioning.

## Repo-backed backlog

### P0 launch blockers

| Priority | Task | Files | Definition of done |
| --- | --- | --- | --- |
| P0 | Fix `TeamAvatar` compile issue in membership hub | [`membership_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/community/screens/membership_hub_screen.dart:542>), [`match_list_widgets.dart`](</Volumes/PRO-G40/FANZONE/lib/widgets/match/match_list_widgets.dart:14>) | analyze and tests green |
| P0 | Reconcile feature-flag defaults and tests | [`app_config.dart`](</Volumes/PRO-G40/FANZONE/lib/config/app_config.dart:21>), [`app_config_test.dart`](</Volumes/PRO-G40/FANZONE/test/app_config_test.dart:17>) | test suite green and config contract documented |
| P0 | Reorder home to match the reference product center | [`matchday_hub_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/home/screens/matchday_hub_screen.dart:67>) | live/upcoming prediction value appears above non-core explainer cards |
| P0 | Elevate club split model in wallet | [`wallet_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/wallet/screens/wallet_screen.dart:41>) | split visible without scrolling |
| P0 | Remove client-side redemption mutations | [`useRedemptions.ts`](</Volumes/PRO-G40/FANZONE/admin/src/features/redemptions/useRedemptions.ts:41>) plus new server-side command surface | browser cannot directly update redemption status |
| P0 | Remove client-authored sensitive audit logging | [`useAuditLog.ts`](</Volumes/PRO-G40/FANZONE/admin/src/hooks/useAuditLog.ts:7>) plus server mutation paths | sensitive audit events are server-authored |
| P0 | Ship pool settlement reconciliation surfaces | [`20260418121500_p0_hardening_fixups.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260418121500_p0_hardening_fixups.sql:667>), [`20260419150000_pool_settlement_reconciliation.sql`](</Volumes/PRO-G40/FANZONE/supabase/migrations/20260419150000_pool_settlement_reconciliation.sql:1>), [`fet-supply-governance.md`](</Volumes/PRO-G40/FANZONE/docs/fet-supply-governance.md:25>) | settlement totals reconcile exactly and operators can report on demand |
| P0 | Remove AI-search ingestion from launch-critical match state | [`gemini-sports-data/gemini.ts`](</Volumes/PRO-G40/FANZONE/supabase/functions/gemini-sports-data/gemini.ts:24>), [`handler.ts`](</Volumes/PRO-G40/FANZONE/supabase/functions/gemini-sports-data/handler.ts:27>) | no launch-critical football state depends on Gemini search extraction |
| P0 | Enable production crash reporting | [`env/production.json`](</Volumes/PRO-G40/FANZONE/env/production.json:1>) | Sentry events visible from production build |
| P0 | Add integration smoke tests | new `integration_test/` | critical mobile flows covered end to end |

### P1 immediately after blockers

| Priority | Task | Files | Definition of done |
| --- | --- | --- | --- |
| P1 | Clean route and IA residue from legacy scores-first model | [`app_router.dart`](</Volumes/PRO-G40/FANZONE/lib/app_router.dart:113>) | no unnecessary compatibility IA remains |
| P1 | Tighten match detail density and trust cues | [`match_detail_screen.dart`](</Volumes/PRO-G40/FANZONE/lib/features/home/screens/match_detail_screen.dart:69>) | faster scan and clearer availability/settlement semantics |
| P1 | Build repository boundaries around Supabase access | `lib/services`, `lib/providers`, `lib/data` | launch-critical domains query through repositories |
| P1 | Expand admin global search | [`useGlobalSearch.ts`](</Volumes/PRO-G40/FANZONE/admin/src/hooks/useGlobalSearch.ts:91>) | user, wallet, redemption, challenge, moderation search works |
| P1 | Add dashboard deep links from alerts to queues | `admin/src/features/dashboard` | alert cards open actionable filtered queues |
| P1 | Strengthen Fan ID / membership / clubs progression | community and identity screens | next-step progression visible across surfaces |

### P2 after launch-safe baseline

| Priority | Task | Files | Definition of done |
| --- | --- | --- | --- |
| P2 | Introduce real friend graph and social presence | social features and backend | social is relationship-driven, not pool-adjacent |
| P2 | Add country-aware localization and campaign ops | mobile, admin, backend config | first EU market variant can be introduced safely |
| P2 | Build fraud investigation workspace | moderation, wallets, redemptions, transactions | linked-case operations exist |
| P2 | Add reconciliation and anomaly dashboards | admin analytics and backend jobs | operators can detect and explain risk states quickly |

## Suggested owners

### Product and UX

- home realignment
- wallet split clarity
- identity progression
- reward trust UX
- copy audit for non-gambling semantics

### Flutter

- compile/test green
- integration suite
- repository boundary refactor
- crash reporting
- performance and caching discipline

### Backend and data

- authoritative sports data strategy
- settlement remainder policy
- ledger reconciliation
- notification reliability

### Admin and ops

- redemption RPCs
- audit hardening
- operator search
- risk dashboard deep links

## Recommended immediate next move

Start with a short P0 branch focused only on launch blockers:

1. make mobile green
2. realign the home and wallet to the reference
3. move redemptions and audit logging server-side
4. fix settlement remainder handling
5. disable or demote AI-search match-state ingestion from launch-critical use

Only after those five are closed should the team spend time on richer social, analytics, or EU expansion work.
