# FANZONE Comprehensive Handover Report

Report date: 2026-06-02  
Repository: `/Volumes/PRO-G40/FANZONE`  
Branch reviewed: `main`  
HEAD reviewed: `de8f85f`  
Working tree state at review time: dirty, with 117 changed or untracked paths

## 1. Purpose

This report is a full stakeholder handover for FANZONE: the production sports-bar and hospitality platform in this repository. It is intended for product, business, venue operations, customer support, engineering, security, QA, release, and executive stakeholders.

The report consolidates the project model, active product boundaries, repository layout, app surfaces, backend design, security controls, operational workflows, validation gates, release blockers, and ownership actions needed for continued development and launch governance.

This report is not a production launch approval. It is a repository-grounded handover snapshot. Launch approval still depends on the release evidence and go-live gates listed in this document.

## 2. Executive Summary

FANZONE is a multi-surface platform for sports bars, fan zones, lounges, restaurants, and hospitality operators. The platform combines venue discovery, table-number ordering, off-platform payment guidance, audited manual payment confirmation, FET non-cash loyalty rewards, match challenges, centralized venue games, venue operations, admin controls, and TV display experiences.

The production architecture currently includes:

| Surface | Path | Primary audience | Role |
| --- | --- | --- | --- |
| Flutter mobile app | `lib/` | Guests and mobile users | Venue discovery, ordering, loyalty rewards, challenges, profile, settings |
| Admin console | `apps/admin/` | Platform operators | Curation, platform controls, rewards oversight, moderation, audit |
| Venue portal | `apps/venue-portal/` | Venue owners, managers, staff | Orders, menu, pools, games, teams, screen control, insights, staff workflows |
| Website PWA | `apps/website/` | Guests and public users | Public web/PWA ordering, pools, loyalty, profile, legal pages |
| TV display PWA | `apps/tv-display/` | Venue screens | Pairing, live venue display, join screens, leaderboards, game/pool screens |
| Shared TypeScript package | `packages/core/` | Web workspaces and Edge contract tests | Shared domain contracts and lifecycle helpers |
| Supabase backend | `supabase/` | All runtime surfaces | Auth, database, RLS, RPCs, Edge Functions, SQL verification |

The strongest business constraint is product boundary discipline. FANZONE is not betting, gambling, a wallet, a cash-out product, a payment processor, or a fintech stored-value platform. FET is a non-cash loyalty and rewards ledger. Customer payments remain off-platform through cash, MoMo/USSD instructions, Revolut-link guidance, or a future explicitly approved provider integration.

The strongest technical constraint is trust-boundary discipline. Client apps use anon-safe Supabase access only. Sensitive mutations must happen through audited RPCs or Edge Functions. Venue/staff/admin actions must enforce server-side role and venue membership checks. RLS and SQL/Edge tests are first-class release requirements.

## 3. Current Status Snapshot

The repository is in an active development state. The working tree reviewed for this handover had 117 changed or untracked paths. The changes span Flutter, React workspaces, docs, Supabase migrations/tests/functions, shared contracts, and validation tooling.

Key current-state observations:

| Area | Status |
| --- | --- |
| Branch | `main` |
| Last reviewed commit | `de8f85f` |
| Working tree | Dirty, broad active work in progress |
| Product boundary | Strongly documented and guarded by scan scripts |
| Release readiness | Not automatically confirmed by this report |
| Live Supabase Phase 2 status | Existing evidence says several Phase 2 migrations require application and rerun evidence before live signoff |
| Existing active blockers | Secret rotation evidence, full P0/P1 release evidence, production metadata, live Supabase migration proof, UAT, mobile signing/install proof, operational monitoring |

Because the tree is dirty, any release manager should treat this report as a handover document, not as final release evidence. Release proof must be regenerated after changes are committed or explicitly frozen.

## 4. Product Model

### 4.1 Business Proposition

FANZONE helps sports hospitality venues run a better match-day and in-venue experience. The platform provides:

- guest venue discovery;
- menu browsing and table-number ordering;
- external payment instructions and manual confirmation;
- non-cash FET loyalty rewards;
- match-based prediction challenges;
- venue entertainment sessions;
- team-based participation;
- venue staff operations;
- platform admin controls;
- TV display experiences for venue screens;
- audit and release tooling for controlled operations.

### 4.2 Target Customers

Primary customers:

- sports bars;
- hospitality venues;
- fan zones;
- lounges;
- restaurants that host live sports;
- event venues that want controlled entertainment and loyalty mechanics.

Primary end users:

- guests placing orders and joining engagement activities;
- venue staff managing orders and staff calls;
- venue managers controlling menus, screens, rewards, and daily reconciliation;
- platform operators managing venues, competitions, curation, rewards rules, audit logs, and abuse controls.

### 4.3 Non-Negotiable Product Boundaries

FANZONE must remain inside these boundaries:

- no betting;
- no gambling;
- no odds;
- no wagering;
- no cash-out;
- no cash prizes;
- no pooled-wager model;
- no stored-value wallet positioning;
- no customer-facing payment execution by the platform in the current MVP;
- no service-role or privileged integration secret exposure in clients;
- no required open QR ordering dependency;
- no direct client mutation of sensitive state that requires server validation and audit.

FET must always be described and implemented as non-cash loyalty/rewards points. Internal legacy names such as wallet tables or routes may still exist, but customer-facing copy must avoid fintech-wallet language.

## 5. Repository Map

| Path | Handover notes |
| --- | --- |
| `README.md` | Main product and architecture introduction. |
| `PRODUCT_RULES.md` | Product-boundary source of truth for stakeholders and implementers. |
| `FET_LEDGER.md` | FET loyalty ledger documentation. |
| `QA_CHECKLIST.md` | QA checklist surface. |
| `lib/` | Flutter mobile app using feature-first modules. |
| `apps/admin/` | React/Vite platform admin console. Keep active while any replacement is built in parallel. |
| `apps/venue-portal/` | React/Vite venue operations console. |
| `apps/website/` | React/Vite guest web/PWA surface. |
| `apps/tv-display/` | React/Vite venue TV display surface. |
| `packages/core/` | Shared TypeScript contracts and lifecycle helpers. |
| `supabase/migrations/` | Append-only migration chain for deployed schema, RLS, RPCs, triggers, views, grants. |
| `supabase/functions/` | Supabase Edge Functions. |
| `supabase/tests/` | SQL readiness, contract, RLS, and backend verification scripts. |
| `tool/` | Validation, release, Supabase, evidence, and boundary scan scripts. |
| `docs/` | Architecture, operations, testing, security, release, and readiness documentation. |
| `release/` | Store metadata, QA evidence, legal pages, security evidence, release notes. |
| `env/*.example.json` | Example Flutter runtime config. Real `env/*.json` files stay ignored. |
| `.github/workflows/` | CI, deployments, cron jobs, and secret scan workflows. |

## 6. Technology Stack

### 6.1 Mobile

Flutter app:

- Flutter with Dart SDK `^3.10.8`;
- `go_router` for app routes, guarded navigation, and deep links;
- Riverpod for state management and dependency injection;
- Supabase Flutter for backend access;
- Firebase Messaging for notifications;
- generated immutable models through `freezed` and `json_serializable`;
- local storage through Shared Preferences, Hive, secure storage, and cache helpers;
- design assets and vendored fonts for deterministic UI tests/builds.

### 6.2 Web

React/Vite workspaces:

- React `19.2.x`;
- Vite `8.x`;
- TypeScript `~6.0.2`;
- React Router `7.x`;
- Supabase JS `2.x`;
- TanStack Query in admin;
- Zustand in guest/venue surfaces where applicable;
- lucide-react icons;
- Vitest and Testing Library for targeted tests.

### 6.3 Backend

Supabase:

- Postgres schema;
- RLS policies;
- audited RPCs;
- triggers and views;
- Edge Functions written in TypeScript/Deno;
- SQL verification scripts;
- scheduled jobs for pool settlement and match alerts;
- manual/off-platform payment confirmation and reconciliation;
- WhatsApp OTP endpoint and custom session issuance.

## 7. App Surface Handover

### 7.1 Flutter Mobile App

Path: `lib/`

Audience: guests and mobile venue users.

Primary responsibilities:

- splash and runtime session bootstrap;
- onboarding;
- WhatsApp login;
- venue entry;
- venue discovery;
- venue detail and menu browsing;
- checkout;
- order success, receipt, and tracking;
- external payment handoff guidance;
- order-linked staff call;
- home feed;
- match detail;
- pools/challenges list, creation, detail, join, and share entry;
- games list and detail;
- FET rewards ledger display;
- profile;
- notifications;
- privacy and settings;
- feature-unavailable states for disabled platform features.

Primary route groups:

| Route | Meaning |
| --- | --- |
| `/splash` | Session/runtime bootstrap. |
| `/onboarding` | Guest onboarding. |
| `/login` | WhatsApp login. |
| `/v/:venueSlug` | Venue entry by slug. |
| `/bar` | Venue menu or venue entry by query. |
| `/venue/:venueId` | Venue details. |
| `/venues` | Browse venues. |
| `/venues/location` | Location access flow. |
| `/checkout` | Checkout. |
| `/order/:orderId/success` | Order success. |
| `/order/:orderId/receipt` | Order receipt. |
| `/order/:orderId` | Order tracking. |
| `/home` | Home feed. |
| `/search` | Global search. |
| `/match/:id` | Match detail. |
| `/pools` | Challenges/pools. |
| `/pools/create` | Create challenge. |
| `/pool/:poolId` | Challenge detail. |
| `/pool/:poolId/join` | Join challenge. |
| `/pools/:shareSlug` | Shared challenge entry. |
| `/games` | Games list. |
| `/game/:gameId` | Game detail. |
| `/orders` | User orders. |
| `/wallet` | FET rewards ledger surface. |
| `/wallet/transaction/:transactionId` | Transaction detail. |
| `/profile` | Profile. |
| `/notifications` | Notifications. |
| `/settings` | Settings. |
| `/settings/privacy` | Privacy settings. |
| `/feature-unavailable` | Controlled unavailable state. |

Mobile handover risks:

- route guards must preserve pending deep links safely during splash/auth;
- retired QR/table query paths must stay cleaned and not reintroduce required QR ordering;
- service-role keys must never enter Flutter config;
- FET copy must remain loyalty/rewards oriented;
- order realtime subscriptions must stay scoped to the single order or current venue context;
- release builds require ignored production env and signing files.

### 7.2 Venue Portal

Path: `apps/venue-portal/`

Audience: venue owners, managers, and staff.

Primary responsibilities:

- venue context and staff auth;
- operations overview;
- live order queue;
- order detail and order lifecycle actions;
- audited manual payment confirmation;
- menu architecture and item editing;
- venue pools/challenges;
- venue games and team management;
- participants;
- screen control for TV display;
- FET rewards-ledger operations;
- operational insights;
- daily manual payment reconciliation;
- settings, staff permissions, screen setup, FET rewards config;
- notifications.

Primary routes:

| Route | Meaning |
| --- | --- |
| `/overview` | Venue operations overview. |
| `/orders` | Live order queue. |
| `/orders/:orderId` | Order detail. |
| `/menu` | Menu management. |
| `/menu/items/new` | Create menu item. |
| `/menu/items/:itemId` | Edit menu item. |
| `/pools` | Venue challenges. |
| `/pools/new` | Create venue challenge. |
| `/pools/:poolId` | Challenge detail. |
| `/pools/:poolId/settle` | Settlement operation. |
| `/games` | Games. |
| `/games/new` | Start game. |
| `/games/:sessionId/control` | Game control. |
| `/teams` | Teams. |
| `/teams/:teamId` | Team detail. |
| `/participants` | Participants. |
| `/screen` | TV display control. |
| `/wallet` | FET rewards-ledger overview. |
| `/wallet/buy` | Venue-side FET operations route. Product copy must stay non-cash and approved. |
| `/wallet/ledger` | Ledger detail. |
| `/insights` | Operations insights and reconciliation. |
| `/settings` | Settings overview. |
| `/settings/profile` | Venue profile settings. |
| `/settings/payments` | Payment instructions/settings. |
| `/settings/permissions` | Staff permissions. |
| `/settings/screen` | Screen settings. |
| `/settings/fet-rewards` | Rewards configuration. |
| `/notifications` | Notifications. |

Venue portal handover risks:

- role guards are not the real security boundary; DB policies and RPC checks are;
- direct writes to `orders`, `payment_events`, `order_state_events`, and `bell_requests` must remain blocked where the canonical RPC exists;
- staff calls must be acknowledged through `venue_acknowledge_bell_request`;
- daily close must use audited payment evidence, not payment-provider execution assumptions;
- realtime subscriptions must stay venue-scoped;
- production uses BFF/privileged session mode where configured, not local demo/browser shortcuts.

### 7.3 Admin Console

Path: `apps/admin/`

Audience: platform operators.

Primary responsibilities:

- dashboard/overview;
- countries;
- venues;
- competitions;
- teams;
- curated matches;
- pool/challenge operations;
- settlement queue and failed settlement processing;
- wallet/FET rewards-ledger oversight;
- reward rules;
- risk and abuse moderation;
- feature flags/platform controls;
- audit logs;
- admin authentication and role guard UI.

Primary routes:

| Route | Meaning |
| --- | --- |
| `/login` | Admin login. |
| `/` | Dashboard. |
| `/countries` | Country management. |
| `/venues` | Venue management. |
| `/competitions` | Competition management. |
| `/teams` | Team management. |
| `/matches` | Match curation. |
| `/pools` | Pool/challenge operations. |
| `/wallets` | FET ledger oversight. |
| `/settlements` | Settlement operations. |
| `/rewards` | Reward rules. |
| `/risk` | Moderation. |
| `/flags` | Platform controls. |
| `/audit` | Audit logs. |

Admin handover risks:

- admin UI guards are convenience controls only;
- admin mutations require admin RPCs or audited Edge Functions;
- demo mode must not be enabled in production;
- reward and moderation actions require audit evidence;
- platform-control changes should be tracked as release-affecting operations.

### 7.4 Website PWA

Path: `apps/website/`

Audience: public/guest web users.

Primary responsibilities:

- public landing and guest web entry;
- legal pages;
- onboarding;
- bar/ordering web flow;
- pools/challenges;
- match detail;
- FET rewards ledger hub;
- profile;
- settings and privacy;
- notifications;
- feature-control unavailable states.

Primary routes:

| Route | Meaning |
| --- | --- |
| `/onboarding` | Web onboarding. |
| `/privacy` | Privacy policy page. |
| `/terms` | Terms page. |
| `/fet-terms` | FET reward terms. |
| `/help` | Help page. |
| `/bar` | Bar ordering. |
| `/v/:slug` | Venue-specific bar entry. |
| `/pools` | Challenge discovery. |
| `/pools/:slug` | Challenge by slug. |
| `/match/:id` | Match detail. |
| `/wallet` | Rewards ledger hub. |
| `/profile` | Profile. |
| `/settings` | Settings. |
| `/privacy-settings` | Privacy controls. |
| `/notifications` | Notifications. |

Website handover risks:

- `npm run build` runs canonical source drift checks;
- release metadata validation must pass before deployment;
- Android `assetlinks.json` must use production SHA-256 fingerprints;
- website copy must not drift back to wallet/cash-out/payment-execution positioning.

### 7.5 TV Display PWA

Path: `apps/tv-display/`

Audience: venue screens and venue operators.

Primary responsibilities:

- public pairing entry;
- venue screen display by venue key;
- live display states;
- join screens;
- active pool/challenge displays;
- game lobby and live question states;
- leaderboard and winner reveal;
- menu/promo display.

Primary routes:

| Route | Meaning |
| --- | --- |
| `/` | Pairing page. |
| `/venue/:venueKey` | Venue screen route. |
| `/screen/:venueKey` | Venue screen route. |
| `/v/:venueKey` | Venue screen route. |

TV handover risks:

- the TV display is unauthenticated and must only read screen-safe, venue-scoped data;
- cross-venue display leakage is a P0 security/product issue;
- joins must resolve to the correct venue/pool/game context;
- TV deployment metadata must pass the PWA release metadata validator.

## 8. Backend Handover

### 8.1 Backend Responsibilities

Supabase owns:

- authentication and session flows;
- profile and `fan_id` identity model;
- venue, table, menu, order, and payment state;
- payment status and manual/off-platform payment evidence;
- FET reward balances and ledger transactions;
- match catalog and curation;
- pools/challenges, camps, entries, invites, settlements;
- games, teams, and answers where implemented;
- audit logs;
- feature flags and runtime config;
- Edge Functions for runtime operations;
- RLS and grant enforcement.

### 8.2 Migration Policy

The normal migration chain is append-only. Destructive changes must not enter the normal chain unless there is:

- a backup plan;
- a rollback plan;
- explicit release note;
- approval from release/backend owners;
- validation evidence after application.

The repository currently contains 95 SQL migration files under `supabase/migrations/`. It also contains `supabase/destructive/20260501_retired_dinein_fanzone_cleanup.sql`, which is intentionally separate from the normal migration chain.

### 8.3 Key Database Domains

| Domain | Important objects |
| --- | --- |
| Identity | Supabase Auth, profile tables, immutable six-digit `fan_id` |
| Venue membership | `venue_users`, owner/manager/staff roles |
| Venue/order model | `venues`, `tables`, `menu_categories`, `menu_items`, `orders`, `order_items` |
| Manual payment | `orders.payment_status`, `payment_events`, `venue_update_order_payment_status`, reconciliation RPCs |
| Order lifecycle | `order_state_events`, `venue_transition_order_status`, status enums and Edge wrappers |
| Staff calls | `bell_requests`, `ring_bell`, `venue_acknowledge_bell_request` |
| FET rewards | `fet_wallets`, `fet_wallet_transactions`, ledger-backed RPCs/functions |
| Match catalog | `competitions`, `seasons`, `teams`, `team_aliases`, `matches`, `standings`, `curated_matches` |
| Pools/challenges | `match_pools`, `match_pool_camps`, `match_pool_entries`, `match_pool_invites`, `match_pool_settlements` |
| Games | game templates, game sessions, game session questions, teams, answers, scoring |
| Audit | `audit_logs` and operation-specific audit rows |
| Config | `app_config_remote`, feature flags, venue `features_json` |

### 8.4 Edge Function Inventory

Active Edge Functions found in this checkout:

| Function | Handover purpose |
| --- | --- |
| `admin_approve_onboarding` | Admin approval of venue onboarding. |
| `admin_user_management` | Admin user and role operations. |
| `approve_claim` | Venue claim approval. |
| `bar_onboarding_submit` | Venue onboarding submission. |
| `bar_search` | Client-safe venue search. |
| `dispatch-match-alerts` | Scheduled kickoff/final-score notification dispatch. |
| `generate-pool-social-card` | Social card payload/storage for challenge sharing. |
| `import-football-data` | Football data import. |
| `menu_ingest_create` | Persistent menu image import jobs. |
| `menu_ingest_worker` | OCR/import worker for menu ingestion. |
| `menu_ocr_parse` | Stateless menu OCR endpoint. |
| `order_create` | Customer order creation through validated server boundary. |
| `order_mark_paid` | Compatibility wrapper for audited manual payment confirmation. |
| `order_update_status` | Compatibility wrapper for lifecycle transitions. |
| `payment-hub` | Off-platform payment guidance/status helper. |
| `push-notify` | Push notification dispatch. |
| `ring_bell` | Customer staff-call requests. |
| `settle-match-pools` | Idempotent challenge/pool settlement. |
| `submit_claim` | Venue claim submission. |
| `venue_claim` | Venue claim workflow. |
| `whatsapp-otp` | WhatsApp OTP send/verify and custom session issuance. |

### 8.5 Critical Backend Invariants

- RLS must isolate users, venues, countries, and admin-only data.
- Client-exposed tables must have RLS enabled and tested.
- Venue/staff/admin mutations must enforce server-side membership or platform-admin roles.
- Ledger balances must not mutate without ledger transaction rows.
- FET amounts and balances must never go negative.
- Manual payment confirmation must write audit evidence.
- Order lifecycle changes must go through canonical RPC/Edge paths.
- Staff-call acknowledgement must go through canonical audited RPC.
- Settlement must be idempotent.
- Edge Functions must validate auth, origin/CORS, input shape, and privileged operations.
- Service-role secrets must remain server-side only.

## 9. User Journeys And Workflows

### 9.1 Guest Ordering Journey

1. Guest opens mobile app or website.
2. Guest enters or discovers a venue.
3. Guest browses menu categories/items.
4. Guest places a table-number order.
5. `order_create` validates venue/menu/table/order payload server-side.
6. Guest receives payment guidance for cash, MoMo/USSD, or Revolut link.
7. Guest marks payment intent where applicable.
8. Venue staff manually confirms payment through audited workflow.
9. Order status progresses through submitted, accepted, preparing, ready, served, completed.
10. Customer tracks status with scoped realtime.
11. If needed, customer calls staff through order-linked `ring_bell`.
12. Eligible paid orders can unlock FET reward settlement.

### 9.2 Venue Staff Order Workflow

1. Staff logs into venue portal.
2. Staff selects active venue context.
3. Staff views live order queue.
4. Staff opens order detail.
5. Staff updates lifecycle through allowed actions.
6. Status changes delegate to canonical RPC/Edge path.
7. Staff records required reason for sensitive transitions such as cancellation/refund/dispute.
8. Staff confirms manual/off-platform payment with method, amount/reference, and notes where required.
9. Reconciliation summaries support daily close.
10. Audit logs provide after-the-fact evidence.

### 9.3 Challenge/Pool Journey

1. Admin or venue curates competitions, matches, and approved challenge context.
2. Customer discovers a challenge through mobile/web.
3. Customer joins a challenge/camp or uses a shared link/invite.
4. Customer picks allowed outcome options.
5. Eligibility can depend on venue-linked qualifying paid order within the configured time window.
6. Finished matches trigger settlement.
7. Eligible winners receive non-cash FET loyalty credits.
8. Ineligible logical winners may remain visible but uncredited.
9. Settlement evidence is logged and idempotent.

### 9.4 Game And Team Journey

1. Venue starts a game from approved templates.
2. Participants create or join teams within the venue session.
3. Question games select exactly 20 active approved questions at session creation.
4. Selected questions are persisted for the session.
5. Teams submit answers with race protection in database/backend logic.
6. Scoring awards non-cash FET loyalty score/reward outcomes.
7. TV display can show lobby, live questions, leaderboard, and winner reveal.

### 9.5 Admin Operations Journey

1. Platform operator logs into admin console.
2. Operator manages countries, competitions, teams, and venues.
3. Operator curates match content and approved discovery.
4. Operator oversees challenges, settlement queues, rewards rules, and ledgers.
5. Operator reviews audit logs and abuse/moderation surfaces.
6. Operator changes platform controls/feature flags only with release awareness.

### 9.6 TV Display Journey

1. Venue opens display pairing route.
2. Venue portal controls target venue screen state.
3. TV display reads only venue-safe display state.
4. Guests can join by app link/QR-style public link where appropriate.
5. Display transitions through welcome, join, game/challenge, leaderboard, winner, or promo states.

## 10. Security And Compliance Handover

### 10.1 Main Security Boundaries

| Boundary | Requirement |
| --- | --- |
| Client secrets | Clients receive anon keys only. No service-role secrets. |
| Admin/venue roles | UI role guards are not enough; DB and Edge checks are required. |
| RLS | Must be enabled and tested on client-exposed tables. |
| Cross-venue isolation | Venue data and mutations must be scoped to membership. |
| Cross-user isolation | Customer reads/writes must be scoped to own profile/order/session/public data. |
| Sensitive state | Order status, payment, refund/void/dispute, reward settlement, staff/admin override, role changes, config changes require audit evidence. |
| CORS | Production Edge Functions must use explicit origins and `FANZONE_EDGE_ALLOW_WILDCARD_CORS=false`. |
| Payments | No platform payment execution unless separately approved and implemented. |
| FET | No cash-equivalent, cash-out, or wallet positioning. |

### 10.2 Current Known Security/Release Issues

The existing docs identify these release-blocking concerns:

- Supabase credentials were previously shared in assistant conversation context during release work. Production launch requires rotation of access token, database password, anon key, service-role key, and any copied local/CI provider variables.
- Secret scan evidence must be regenerated after rotation.
- Production `env/*.json`, signing files, Firebase service files, database URLs, service-role keys, and provider tokens must remain ignored and outside git.
- Production metadata such as Android asset links must use real production fingerprints.
- Live Supabase evidence must be refreshed after applying pending migrations.

### 10.3 Security Validation Commands

Important repo-owned gates:

```bash
./tool/product_boundary_scan.sh
./tool/go_live_readiness.sh --local
./tool/check_world_class_evidence.sh
./tool/full_history_secret_scan.sh
node tool/validate_secret_rotation_evidence.mjs
./tool/supabase_rls_audit.sh
./tool/supabase_live_validation.sh
./tool/supabase_fet_supply_smoke.sh
```

Boundary-specific scan scripts currently include:

```bash
node tool/scoped_realtime_scan.mjs
node tool/order_edge_boundary_scan.mjs
node tool/order_lifecycle_parity_scan.mjs
node tool/venue_portal_hospitality_scan.mjs
node tool/entertainment_reward_boundary_scan.mjs
node tool/flutter_ordering_boundary_scan.mjs
```

## 11. Release And Validation Handover

### 11.1 Release Decision Rule

FANZONE should remain `NO-GO` until:

- all P0 and P1 tasks in `docs/release/production-go-live-task-register.md` have evidence;
- the world-class benchmark is 100% PASS across Flutter, venue PWA, admin PWA, and TV PWA;
- `tool/check_world_class_evidence.sh` passes;
- `tool/go_live_readiness.sh --local` passes on a clean checkout;
- production credentials are rotated and stored only in approved secret stores;
- production backup, rollback, monitoring, and incident ownership are proven;
- critical UAT is signed off with evidence.

### 11.2 Core Validation Commands

Flutter:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool
./tool/flutter_analyze_release.sh
flutter test
flutter build apk --debug
```

Web workspaces:

```bash
npm ci
npm run typecheck --workspaces --if-present
npm run lint --workspaces --if-present
npm run test --workspaces --if-present
npm run build --workspaces --if-present
```

Supabase and Edge Functions:

```bash
supabase db push --dry-run
./tool/supabase_rls_audit.sh
./tool/supabase_fet_supply_smoke.sh
deno fmt --check supabase/functions
find supabase/functions -name '*.ts' -print0 | xargs -0 deno check
deno test --allow-env supabase/functions
```

Release checks:

```bash
./tool/product_boundary_scan.sh
./tool/go_live_readiness.sh --local
./tool/check_world_class_evidence.sh
```

### 11.3 Current Phase 2 Evidence Caveat

The existing `docs/release/hospitality-core-phase2-evidence.md` states that local code and scan work existed for order lifecycle, manual payment reconciliation, staff-call acknowledgement, scoped realtime, and product-boundary hardening. It also states that the linked Supabase project still required application of these migrations before live signoff:

- `20260522150000_order_lifecycle_hardening.sql`;
- `20260523120000_manual_payment_reconciliation.sql`;
- `20260523130000_staff_call_acknowledgement_rpc.sql`;
- `20260523140000_manual_payment_note_requirement.sql`.

Release owners must refresh this evidence before relying on it because this handover was prepared on 2026-06-02 and the evidence document is dated 2026-05-23.

## 12. Operations Handover

### 12.1 Required Operational Roles

| Role | Responsibilities |
| --- | --- |
| Executive sponsor | Launch approval, commercial priority, risk acceptance. |
| Product owner | Product boundary, roadmap, market priorities, stakeholder alignment. |
| Release owner | Go/no-go decision, evidence register, rollback tag, deployment sequencing. |
| Backend owner | Supabase migrations, RLS, RPCs, Edge Functions, cron jobs, backups. |
| Mobile owner | Flutter app, Android/iOS signing, deep links, device UAT. |
| Web owner | Admin, venue portal, website, TV display, Cloudflare/deploy evidence. |
| QA owner | Critical user flow UAT, regression evidence, manual scenario signoff. |
| Security owner | Secret rotation, scans, RLS/authorization review, abuse tests. |
| Operations owner | Monitoring, incident response, cron schedules, venue support. |
| Venue onboarding owner | Venue setup, staff accounts, table/menu data, payment instructions. |
| Customer support owner | Guest issues, refunds/disputes routing, account deletion/privacy support. |

### 12.2 Operational Runbooks And Docs

| Document | Use |
| --- | --- |
| `docs/operations/admin-guide.md` | Admin/operator workflows. |
| `docs/operations/incident-runbooks.md` | Incident response and escalation. |
| `docs/operations/scheduler-observability.md` | Scheduled job monitoring. |
| `docs/operations/livescore-ingest.md` | Match/score ingest operations. |
| `docs/menu-operations.md` | Menu operations. |
| `docs/pool-operations.md` | Challenge/pool operations. |
| `docs/off-platform-payments.md` | Payment handoff model. |
| `docs/release/deployment-readme.md` | Deployment process. |
| `docs/release/rollback.md` | Rollback planning. |
| `docs/secret-rotation-runbook.md` | Secret rotation. |

### 12.3 Monitoring Targets

At launch and after every major release, operations should monitor:

- Edge Function errors;
- Auth and OTP failure rate;
- order creation failures;
- order lifecycle transition failures;
- manual payment confirmation failures;
- staff-call acknowledgement failures;
- pool settlement success/failure;
- FET ledger anomalies;
- push notification failures;
- database CPU, connections, and slow queries;
- Realtime load and subscription errors;
- PWA deploy health and CORS failures;
- mobile crash/analytics signal if configured.

## 13. QA And UAT Handover

### 13.1 Test Surfaces

QA must cover:

- Flutter unit/widget tests;
- Flutter integration tests;
- route guards and deep links;
- provider/gateway tests;
- order model and lifecycle tests;
- checkout payment handoff tests;
- order tracking tests;
- wallet/rewards ledger model tests;
- design system tests/goldens;
- web/admin/venue/TV typecheck/lint/build tests;
- React route guards and role checks;
- Supabase SQL contract tests;
- RLS and cross-venue/cross-user isolation tests;
- Edge Function auth/input/failure tests;
- release metadata validation;
- product-boundary text and behavior scans.

### 13.2 Critical UAT Scenarios

Before production signoff, capture evidence for:

- anonymous guest session;
- WhatsApp OTP upgrade;
- venue discovery;
- table-number order placement;
- cash/MoMo/Revolut instruction display;
- unsupported card/payment-provider execution rejection;
- "I paid" or equivalent guest handoff;
- staff manual payment confirmation with audit trail;
- order lifecycle transitions with valid and invalid paths;
- cancellation/refund/dispute reason requirement;
- order tracking realtime updates scoped to the order;
- order-linked staff call;
- staff-call acknowledgement through RPC;
- daily manual payment reconciliation;
- FET rewards earning from qualifying paid order;
- no customer FET transfer UX;
- free-to-play challenge entry;
- eligibility-gated settlement;
- admin curation;
- venue screen pairing/display;
- cross-venue access denial;
- cross-user access denial;
- production-origin CORS;
- rollback path.

## 14. CI, Deployment, And Automation

Workflows present under `.github/workflows/`:

| Workflow | Purpose |
| --- | --- |
| `ci.yml` | Main CI workflow. |
| `secret-regex-scan.yml` | Secret pattern scan. |
| `deploy-admin.yml` | Admin deployment. |
| `deploy-website.yml` | Website deployment. |
| `deploy-venue-portal.yml` | Venue portal deployment. |
| `deploy-tv-display.yml` | TV display deployment. |
| `cron-settle.yml` | Pool settlement schedule. |
| `cron-match-alerts.yml` | Match alert schedule. |

Deployment handover notes:

- Cloudflare Pages or configured hosting must provide runtime variables safely.
- Admin and venue portal production privileged-session behavior must be validated.
- Edge Function CORS must include all production origins.
- Store signing and Firebase files must be supplied through secure storage, not git.
- Release metadata must be validated per surface.
- Linked Supabase validation should be used when local Docker/Supabase is unavailable.

## 15. Product And Roadmap Handover

### 15.1 Current Product Pillars

1. Hospitality ordering: venue menus, table-number orders, lifecycle, staff operations.
2. Off-platform payment guidance: cash, MoMo/USSD, Revolut link, manual confirmation.
3. FET non-cash rewards: earning, ledger, rewards rules, oversight, no cash-out.
4. Sports engagement: curated matches, challenges, teams, games, leaderboards.
5. Venue operations: portal, screen control, insights, reconciliation.
6. Platform operations: admin, audit, moderation, controls, release gates.

### 15.2 Immediate Roadmap Priorities

High priority:

- finish and verify live Supabase Phase 2 migration application;
- rotate and prove all exposed/shared secrets;
- regenerate go-live evidence on a clean checkout;
- complete critical UAT evidence;
- prove Android/iOS release artifacts and production envs;
- verify deployed web/PWA surfaces and production CORS;
- finish production asset links and release metadata;
- document named incident owners and rollback tag;
- keep FET customer copy consistently in rewards-ledger language.

Medium priority:

- strengthen load/reliability tests for ordering, staff calls, rewards, and settlement;
- expand abuse tests for admin/venue/guest object-level authorization;
- improve operational dashboards for settlement, order conversion, auth, and Edge errors;
- document venue onboarding templates and country-specific payment instruction playbooks;
- complete privacy/legal review for retention, deletion, export, and support access.

## 16. Risk Register

| Risk | Severity | Owner | Mitigation |
| --- | --- | --- | --- |
| Dirty working tree hides incomplete changes | High | Release owner | Freeze branch, commit intentionally, rerun all gates before release. |
| Supabase credentials previously exposed/shared outside approved stores | Critical | Security owner | Rotate all affected credentials, validate rotation evidence, rerun secret scans. |
| Pending live Supabase migration evidence may be stale | High | Backend owner | Confirm current linked project, apply migrations through release process, rerun readiness/contract checks. |
| FET copy drifts into wallet/cash-like language | High | Product + QA | Run product-boundary scans and review customer copy. |
| Manual payment confirmation lacks audit evidence | Critical | Backend + venue portal owner | Keep canonical RPC path and tests; require notes for sensitive statuses. |
| Staff-call direct table updates reintroduced | High | Backend + venue portal owner | Keep `venue_acknowledge_bell_request` path and readiness checks. |
| Cross-venue data leakage through realtime or TV display | Critical | Web + backend owner | Enforce scoped realtime and TV venue-safe queries; run scans and RLS tests. |
| Admin role guard treated as security boundary | Critical | Backend + admin owner | Enforce role checks server-side through RLS/RPC/Edge. |
| Payment provider execution added without product/legal approval | Critical | Product + backend owner | Keep off-platform payment contract and boundary scan coverage. |
| Android/iOS production builds lack signing/env proof | High | Mobile owner | Use ignored production envs and secure signing scripts; capture device/install evidence. |
| Production CORS wildcard enabled | Critical | Backend + web owner | Verify explicit origins and `FANZONE_EDGE_ALLOW_WILDCARD_CORS=false`. |
| UAT evidence incomplete | High | QA owner | Use critical UAT signoff artifact and validate with repo script. |

## 17. First 30 Days After Handover

### Week 1: Stabilize Ownership And Evidence

- Assign named owners for product, release, backend, mobile, web, security, QA, operations, and support.
- Freeze current scope for launch-critical work.
- Review dirty working tree and separate committed release work from exploratory changes.
- Confirm current linked Supabase project ref.
- Rotate required credentials and capture evidence.
- Update release evidence matrix with current facts only.

### Week 2: Close Backend And Security Gates

- Apply pending Supabase migrations through approved process if still pending.
- Rerun SQL readiness and contract gates.
- Rerun Edge Function checks and tests.
- Run full secret scans after rotation.
- Verify RLS and grants on client-exposed tables.
- Confirm CORS production-origin configuration.

### Week 3: Complete Multi-Surface Release Proof

- Run Flutter analysis, tests, and release builds.
- Run workspace typecheck, lint, tests, and builds.
- Validate admin, venue portal, website, and TV metadata.
- Verify deployed web surfaces.
- Capture Android/iOS signing and install evidence.
- Complete critical UAT scenarios.

### Week 4: Launch Governance

- Review incident runbooks and assign escalation channels.
- Confirm backup and rollback point.
- Confirm scheduler/cron monitoring.
- Confirm operations dashboards.
- Review go/no-go with evidence, not verbal status.
- Launch only if all P0/P1 gates are closed.

## 18. Stakeholder Reading Guide

| Stakeholder | Read first |
| --- | --- |
| Executive sponsor | Sections 2, 3, 4, 16, 17 |
| Product owner | Sections 4, 7, 9, 15, 16 |
| Engineering lead | Sections 5, 6, 7, 8, 11 |
| Backend owner | Sections 8, 10, 11, 16 |
| Mobile owner | Sections 7.1, 11, 13 |
| Web owner | Sections 7.2 through 7.5, 11, 14 |
| Security owner | Sections 10, 11, 16 |
| QA owner | Sections 11, 13, 16 |
| Operations owner | Sections 12, 14, 17 |
| Venue onboarding/support | Sections 4, 7.2, 9, 12, 13 |

## 19. Source Documents To Keep Close

| Document | Why it matters |
| --- | --- |
| `README.md` | High-level platform introduction and quick start. |
| `PRODUCT_RULES.md` | Product boundary rules. |
| `docs/README.md` | Production documentation index. |
| `docs/architecture/overview.md` | Architecture summary and invariants. |
| `docs/architecture/apps.md` | App surface inventory. |
| `docs/architecture/backend.md` | Backend, migrations, Edge Functions, and verification. |
| `docs/security/permissions-rls.md` | RLS and permissions model. |
| `docs/security/audit-logs.md` | Audit expectations. |
| `docs/release/go-live-checklist.md` | Launch checklist. |
| `docs/release/production-go-live-task-register.md` | P0/P1/P2 readiness tasks. |
| `docs/release/hospitality-core-phase2-evidence.md` | Phase 2 local evidence and linked Supabase blockers. |
| `docs/release/world-class-production-benchmark.md` | Cross-surface benchmark. |
| `docs/release/world-class-evidence-matrix.md` | Evidence tracker. |
| `docs/operations/incident-runbooks.md` | Incident handling. |
| `docs/release/rollback.md` | Rollback path. |
| `release/qa/critical-user-flow-uat.json` | Critical flow evidence target. |

## 20. Final Handover Position

FANZONE is a serious, multi-surface production platform with strong existing architecture, product-boundary documentation, security expectations, release gates, and operations material. The most important handover message is that the platform must be managed as one integrated hospitality system, not as a single Flutter app or a single web app.

The team taking over should preserve these principles:

- keep active Flutter, React/Vite, Supabase, and documentation surfaces intact;
- work additively unless a migration and validation plan exists;
- keep table-number ordering as the production default;
- keep payment execution off-platform until explicitly approved;
- keep FET as a non-cash rewards ledger;
- enforce venue/admin/customer security server-side;
- use append-only migrations;
- keep release claims evidence-based;
- do not launch from a dirty or unverified tree;
- separate local green checks from live production proof.

The immediate handover priority is to convert this snapshot into a current evidence-backed go/no-go decision by freezing the tree, resolving the active work, rerunning the documented validation gates, applying or confirming pending backend migrations, and closing the P0/P1 release task register with dated proof.
