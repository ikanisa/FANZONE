# FANZONE Repository Audit and Refactor Plan

Date: 2026-04-18

## Scope And Method

This audit was based on the actual workspace contents under `/Volumes/PRO-G40/FANZONE`.

Inspected surfaces:

- Flutter mobile app under `lib/`, `android/`, `ios/`, `assets/`, `test/`
- React/Vite admin console under `admin/`
- Supabase SQL, tests, and Edge Functions under `supabase/`
- CI/CD and operational tooling under `.github/` and `tool/`
- Environment/configuration and release docs under `env/`, root config files, and `docs/`

Validation executed during the audit:

- `flutter test` -> passed
- `flutter analyze` -> no blocking errors after targeted fixes, but many warnings remain
- `npm --prefix admin run build` -> passed
- `npm --prefix admin run lint` -> fails with 22 real code-quality/type issues
- `npm --prefix admin audit --omit=dev --audit-level=high` -> 0 high vulnerabilities found
- `flutter pub outdated` / `npm --prefix admin outdated` -> dependency lag confirmed

Current codebase size snapshot:

- `lib/`: 176 Dart files
- Generated Dart files: 32 `*.g.dart` / `*.freezed.dart`
- `admin/src/`: 68 TS/TSX files
- `supabase/functions/`: 5 TypeScript Edge Functions
- Source line volume sampled by audit command: ~61k lines across inspected source paths

## A. Executive Audit Summary

FANZONE is not a single Flutter app. It is a multi-surface product with:

- a Flutter mobile client
- a browser-based admin console
- a Supabase-backed data plane
- several Edge Functions and shell-based operational probes

The repository is functional, but its architecture has drifted. The biggest pattern repeated across the repo is partial abstraction:

- mobile has the beginnings of a layered architecture, but most business flows bypass it and call Supabase directly
- admin has reusable hooks, but they are too generic, stringly-typed, and rely on `any`
- Edge Functions exist, but several are large single-file handlers with manual auth, manual parsing, and weak typing

The codebase is production-capable in parts, but it is not yet production-ready as a system. The main gaps are:

- boundary drift between presentation, orchestration, and data access
- very large feature screens and handlers
- inconsistent typing and validation
- admin-side sensitive data access patterns that are too browser-centric
- weak test coverage outside Flutter models/smoke tests
- CI duplication and release-process inconsistency
- artifact/config sprawl in the workspace

This pass already completed a first cleanup and structural simplification:

- corrected the root README to reflect the real multi-surface repo
- tightened `.gitignore` for admin/mobile/Supabase artifacts and local env files
- removed unused dependencies from Flutter and admin
- removed an orphaned mobile domain/repository layer that was no longer connected to runtime behavior
- fixed the resulting logger-import compile breakage
- removed empty scaffold directories
- fixed one admin build blocker and one render purity issue

The next step is not more cosmetic cleanup. The next step is architectural convergence: choose one real boundary pattern per surface and refactor toward it feature by feature.

## 1. Repository Map

### Top-Level Structure

- `lib/`: Flutter mobile app
- `admin/`: React 19 + Vite + Supabase admin console
- `supabase/`: migrations, SQL tests, archive SQL, and Edge Functions
- `tool/`: shell probes and release scripts
- `.github/workflows/`: CI, mobile CI, admin deployment
- `env/`: mobile environment JSON templates and a production JSON file
- `docs/`: release docs plus multiple point-in-time gap-analysis/implementation-plan documents

### Major Runtime Modules

Mobile:

- `lib/features/`: screen-led product features
- `lib/providers/`: Riverpod async access and orchestration
- `lib/services/`: RPC/data/business logic with direct Supabase usage
- `lib/models/`: app models and generated classes
- `lib/core/`: logging, network provider, utilities, market bootstrap
- `lib/widgets/`: shared UI pieces

Admin:

- `admin/src/features/`: page-level feature modules
- `admin/src/hooks/`: auth, search, query, toast, and data hooks
- `admin/src/components/`: layout and UI building blocks
- `admin/src/lib/`: Supabase client bootstrap
- `admin/src/types/`: mostly centralized type dump

Supabase:

- `supabase/migrations/`: schema and RLS evolution
- `supabase/tests/`: SQL verification scripts
- `supabase/functions/`: `auto-settle`, `push-notify`, `gemini-team-news`, `gemini-currency-rates`, `gemini-sports-data`
- `supabase/archive/`: old hotfix/reference SQL

Operations:

- `tool/`: Supabase smoke tests, release probes, mobile build scripts
- `.github/workflows/`: mobile build/test, Supabase checks, admin deploy

### Cross-Module Relationships

- Mobile and admin both talk directly to Supabase.
- Mobile uses Riverpod providers but also mixes direct `Supabase.instance.client` access into services.
- Admin uses `createClient(...)` in the browser and reads/writes admin tables and RPCs directly.
- Edge Functions act as side-effect executors for push notifications, Gemini ingestion, and auto-settlement.
- SQL migrations define core access policies, including admin infrastructure and verification queries.

### Technical Hotspots

Mobile hotspots:

- `lib/features/home/screens/match_detail_screen.dart` — 2066 lines
- `lib/features/onboarding/screens/onboarding_screen.dart` — 1678 lines
- `lib/features/predict/screens/predict_screen.dart` — 1434 lines
- `lib/features/wallet/screens/wallet_screen.dart` — 1144 lines
- `lib/data/team_search_database.dart` — 1335 lines

Admin hotspots:

- `admin/src/components/layout/Topbar.tsx` — 343 lines
- `admin/src/types/index.ts` — 334 lines
- `admin/src/hooks/useSupabaseQuery.ts` — 162 lines, central generic query wrapper
- `admin/src/hooks/useAuth.tsx` — 141 lines, auth bootstrap + access validation + demo behavior

Backend hotspots:

- `supabase/functions/gemini-sports-data/index.ts` — 934 lines
- `supabase/functions/push-notify/index.ts` — 323 lines
- `supabase/functions/auto-settle/index.ts` — 283 lines

## B. Current Architecture Summary

### What Is Working

- The repo already separates mobile, admin, and backend concerns at the top level.
- Supabase migrations and SQL verification scripts show deliberate attention to policy and schema integrity.
- Flutter uses Riverpod consistently enough that a converged state model is achievable.
- Admin build/deploy tooling is simple and workable.
- The operational shell tooling under `tool/` is useful and not obviously abandoned.

### What Is Not Coherent

- Mobile has both a direct-Supabase style and a half-built layered/repository style. That split adds mental overhead without delivering isolation.
- Admin relies on a generic data hook abstraction that reduces type safety and hides table-specific semantics behind strings and `any`.
- Backend/business invariants are spread across Flutter services, SQL RPCs, and Edge Functions, with no clear “owning” layer per workflow.
- Several features are organized by screens first, then grow until each screen becomes a god-file containing rendering, orchestration, validation, and side effects.

### Architecture Direction Recommended

Do not rebuild a full clean-architecture stack for its own sake.

Use a narrower, enforceable end-state:

- `core/`: app shell, env/config, logging, networking primitives, theme, routing
- `shared/`: reusable UI primitives and utility types only
- `features/<feature>/presentation`: screens, widgets
- `features/<feature>/application`: Riverpod providers/controllers/use-cases
- `features/<feature>/data`: Supabase gateways, DTO mapping, cache helpers

For admin:

- `features/<feature>/api.ts`
- `features/<feature>/hooks.ts`
- `features/<feature>/components/*.tsx`
- `features/<feature>/types.ts`

For Edge Functions:

- one directory per function with small internal modules:
  - `auth.ts`
  - `schema.ts`
  - `repo.ts`
  - `handler.ts`
  - `index.ts`

## C. Repo Structure Problems

### Findings

1. The root README described the repo as Flutter-only even though `admin/` has active source, CI, and deployment.
Severity: high
Impact area: onboarding, ownership, release operations
Root cause: documentation drift
Status: fixed in this pass

2. The workspace contained large generated/local artifacts:
- `.dart_tool/` ~619M
- `build/` ~5.4G
- `admin/node_modules/` ~221M
- `ios/Pods/` ~5.6M
- `android/vendor/` ~26M
- root `node_modules/` ~824K with no root `package.json`
Severity: medium
Impact area: developer experience, accidental commit risk
Root cause: weak ignore coverage and mixed tooling usage
Status: ignore rules tightened; artifacts remain cleanup candidates

3. Empty scaffold directories were spread across mobile and admin features, creating the appearance of modularity without actual modular code.
Severity: medium
Impact area: navigability
Root cause: feature scaffolding without follow-through
Status: empty directories removed in this pass

4. `supabase/archive/` retains historical hotfixes and reference SQL without a clear retention policy.
Severity: low
Impact area: migration clarity
Root cause: no archive lifecycle rule

5. `docs/` contains multiple overlapping implementation plans and gap analyses from the same date range with no index or archive boundary.
Severity: low
Impact area: operational clarity
Root cause: planning documents accumulated faster than they were curated

### What Belongs / What Does Not

Keep:

- `lib/`, `admin/`, `supabase/`, `tool/`, `.github/workflows/`

Move or reorganize:

- release-oriented shell scripts under `tool/release/`
- Supabase probes under `tool/supabase/`
- planning docs into `docs/plans/archive/` once superseded

Delete or archive:

- stale local artifacts under `build/`, root `node_modules/`, `admin/dist/`, `.dart_tool/` when not needed locally
- `supabase/archive/` hotfix SQL once the active migration history is confirmed authoritative

## D. Code Quality Problems

### Mobile

1. Very large screen files mix rendering, orchestration, feature toggles, and workflow logic.

Examples:

- `match_detail_screen.dart` contains hero rendering, tabs, predictions, standings, AI analysis, H2H, and chat in one file.
- `onboarding_screen.dart` contains the entire 7-step journey, local persistence, market preference creation, and team search UI.
- `predict_screen.dart` contains tabs, filtering, pool cards, join/create sheets, and submission logic.
- `wallet_screen.dart` contains wallet overview, fan ID, transfer and receive sheets, and formatting logic.

Severity: high
Impact area: maintainability, testability, merge safety
Root cause: feature growth without file decomposition
Refactor difficulty: medium-high
Production blocker: indirect

2. `lib/data/team_search_database.dart` is a giant in-memory runtime catalog.

Problems:

- 1335 lines of hardcoded domain data
- includes external crest URLs
- search logic and seed data are co-located
- changes require app rebuilds rather than data updates

Severity: high
Impact area: performance, maintainability, localization, data ownership
Root cause: onboarding MVP data source never replaced
Refactor difficulty: medium
Production blocker: no, but it is a strategic liability

3. Mobile data access patterns are inconsistent.

Evidence:

- direct Supabase usage across at least 33 mobile files
- duplicated `Supabase.instance.client` access across services/providers
- local cache logic repeated across SharedPreferences consumers

Severity: high
Impact area: consistency, test seams, bug isolation
Root cause: multiple architectural styles coexisting
Refactor difficulty: medium
Production blocker: no, but it slows every future change

4. Analyzer warnings show widespread style and maintainability debt:

- `prefer_relative_imports`
- deprecated Riverpod ref types
- `use_build_context_synchronously`
- deprecated widget properties
- const opportunities and small structural issues

Severity: medium
Impact area: maintainability and future upgrade friction
Root cause: low enforcement threshold in day-to-day work

### Admin

1. `admin/src/hooks/useSupabaseQuery.ts` is over-generic and type-eroding.

Problems:

- string table names and select expressions
- `any` in query wrappers
- feature semantics pushed into hook callers
- weak return-shape guarantees

Severity: high
Impact area: admin correctness, refactor safety
Root cause: generic abstraction introduced before stable feature contracts
Refactor difficulty: medium
Production blocker: yes for long-term maintainability

2. `admin/src/hooks/useAuth.tsx` mixes too many concerns.

Problems:

- React context definition
- session bootstrap
- admin profile verification
- demo-mode fallback
- synchronous `setState` inside effect
- exported non-component symbols tripping `react-refresh/only-export-components`

Severity: high
Impact area: auth correctness and React behavior
Root cause: auth bootstrap kept in one convenience file
Refactor difficulty: medium
Production blocker: yes for code-quality baseline

3. Admin lint currently fails with 22 errors.

Main categories:

- explicit `any` usage in 12 admin files
- effect-driven state churn in `useAuth.tsx`
- `react-refresh/only-export-components` violations in `useAuth.tsx` and `useToast.tsx`

Severity: high
Impact area: release quality and regression risk
Root cause: build is green without a lint gate, so debt accumulates
Refactor difficulty: medium
Production blocker: yes if admin quality bar is to be enforced

4. `admin/src/types/index.ts` is a single shared type dump.
Severity: medium
Impact area: ownership clarity and coupling
Root cause: convenience aggregation
Refactor difficulty: low-medium

5. `admin/src/components/layout/Topbar.tsx` contains global search behavior plus UI plus style-heavy structure in one file.
Severity: medium
Impact area: component reusability and readability
Root cause: layout feature growth
Refactor difficulty: low-medium

## E. Dependency Problems

### Flutter

Confirmed by `flutter pub outdated`:

- 18 dependencies are constrained below a resolvable newer version
- major lag exists in Riverpod, GoRouter, Google Fonts, Freezed, build_runner, and related tooling
- `build_resolvers` and `build_runner_core` are flagged as discontinued in the current dependency tree

Severity: medium
Impact area: upgrade cost, tooling stability
Root cause: dependencies pinned and not incrementally upgraded
Production blocker: not immediate, but it increases future migration risk

Dependency cleanup already executed:

- removed unused `firebase_analytics`

### Admin

Confirmed by `npm outdated`:

- minor/major lag in `@eslint/js`, `eslint`, `@types/node`, and `@tanstack/react-query`

Severity: low-medium
Impact area: tooling freshness
Root cause: standard dependency drift

Dependency cleanup already executed:

- removed unused `@tanstack/react-table`

### Overlap / Redundancy Findings

- Mobile has both provider-level queries and service-level queries hitting similar data sources.
- Admin uses a general-purpose Supabase wrapper and feature hooks, but the generic wrapper is not buying enough safety to justify its abstraction cost.
- Generated model code volume is high relative to handwritten domain boundaries, but the larger issue is not the generated code itself; it is the lack of a stable handwritten layer around it.

## F. Backend / Data / Security Problems

1. Admin is browser-first against sensitive admin surfaces.

Evidence:

- `admin/src/lib/supabase.ts` creates a browser client with anon key
- feature hooks call tables/RPCs directly from the frontend
- migrations do define admin helper functions and RLS protections, which is good, but the security posture still depends heavily on policy correctness

Severity: high
Impact area: security, auditability, least privilege
Root cause: no dedicated backend-for-admin command layer
Refactor difficulty: high
Production blocker: yes

Recommendation:

- keep read-only dashboards on secured views if needed
- move state-changing admin operations behind dedicated Edge Functions or a trusted backend layer
- ensure every admin write path is auditable and role-checked server-side

2. Edge Functions are too monolithic and weakly typed.

Evidence:

- `push-notify/index.ts` uses manual service-account parsing and `any`
- `auto-settle/index.ts` performs auth, orchestration, settlement, and notification fan-out in one handler
- `gemini-sports-data/index.ts` is 934 lines and mixes ingestion, mapping, and writes

Severity: high
Impact area: reliability, incident response, safe change velocity
Root cause: feature-by-feature growth in single files
Refactor difficulty: medium
Production blocker: no, but this is a major operational risk

3. Validation is not consistently explicit at boundaries.

Examples:

- admin query wrappers return casted data
- Edge Functions accept JSON payloads with minimal schema enforcement
- mobile services often assume specific row shapes from Supabase

Severity: high
Impact area: runtime failures and schema drift handling
Root cause: optimistic casting rather than explicit validation
Refactor difficulty: medium

4. Local/config hygiene is loose.

Evidence:

- root `.env` and `admin/.env` existed locally with real project values
- `admin/.env` was not ignored before this pass
- `env/production.json` contains production endpoint configuration and an anon key

Severity: medium-high
Impact area: secret hygiene and accidental leakage
Root cause: mixed strategy between JSON env files, `.env`, and CI secrets
Status: ignore coverage improved, but config strategy still needs consolidation

5. Client-side caching with SharedPreferences is repeated and ad hoc.

Evidence:

- at least 10 mobile files import `SharedPreferences`
- onboarding, favorites, market preferences, notification settings, and currency logic all maintain their own cache lifecycle rules

Severity: medium
Impact area: stale data, duplication, testability
Root cause: no common cache policy or storage abstraction

## G. Performance Problems

1. Large widget trees in giant screen files increase rebuild and profiling complexity.
Severity: medium-high
Impact area: mobile rendering and feature iteration

2. `team_search_database.dart` ships large static data and external crest URLs in app code.
Severity: medium-high
Impact area: startup cost, network unpredictability, bundle weight

3. Admin global search and generic query hooks are likely to over-fetch and under-type queries as features grow.
Severity: medium
Impact area: admin responsiveness and correctness

4. Build artifact sprawl in the workspace indicates weak cleanup discipline and can mask actual repository size and change scope.
Severity: low-medium
Impact area: developer experience

5. Repeated direct Supabase calls across providers/services raise the odds of duplicate fetches and inconsistent cache invalidation.
Severity: medium
Impact area: mobile network efficiency and stale state handling

## H. Testing Gaps

Current test posture:

- Flutter tests: 12 files, mostly models/config/smoke tests
- Admin tests: 0
- Edge Function tests: 0
- Supabase SQL verification files exist: 5

Major gaps:

1. No admin component, hook, or integration tests.
Severity: high
Impact area: admin regressions
Production blocker: yes

2. No automated unit/integration tests for Edge Functions.
Severity: high
Impact area: settlement, push, ingestion workflows
Production blocker: yes

3. Flutter tests are concentrated in models and one widget smoke test, not critical flows.
Missing coverage includes:

- onboarding completion and persistence
- wallet transfer flows
- pool join/create flows
- prediction slip submission
- notification preference lifecycle
- admin-facing backend invariants

Severity: high
Impact area: core product flow regression protection
Production blocker: yes

4. The current mobile architecture makes testing harder than it should be because query logic is embedded in providers/services without strong seams.
Severity: medium-high
Impact area: testability

## I. Cleanup / Deletion Candidates

### Removed In This Pass

- orphaned mobile domain/repository layer under:
  - `lib/core/di/providers.dart`
  - `lib/data/datasources/*`
  - `lib/data/repositories/*`
  - `lib/domain/entities/*`
  - `lib/domain/repositories/*`
  - `lib/services/supabase_service.dart`
- unused Flutter dependency: `firebase_analytics`
- unused admin dependency: `@tanstack/react-table`
- empty scaffold directories across `lib/`, `admin/src/`, `supabase/`, `tool/`, and `docs/`

### Strong Cleanup Candidates

- `admin/dist/` if present in working copies
- root `node_modules/` because the repo has no root Node app
- `build/`, `.dart_tool/`, `ios/Pods/`, `android/vendor/` as local-only artifacts
- `supabase/archive/` after confirming no active dependency on those SQL files
- superseded plan docs in `docs/`

### Duplicate / Stale Structure Candidates

- any remaining feature folders that only exist as empty shells after decomposition
- generic admin hooks that duplicate feature-specific semantics
- local cache utilities that repeat the same `SharedPreferences` shape/load/save patterns

## 6. File And Module Level Recommendations

| Module / Folder | Recommendation | Why |
| --- | --- | --- |
| `lib/features/home/screens/match_detail_screen.dart` | Split | Move tabs into separate files; keep only route-level orchestration |
| `lib/features/onboarding/` | Split + move logic | Extract each step into its own widget and move persistence/search orchestration into `application` / `data` files |
| `lib/features/predict/screens/predict_screen.dart` | Split | Separate list view, join/create sheets, and submission logic |
| `lib/features/wallet/screens/wallet_screen.dart` | Split | Isolate transfer/receive/history cards and RPC orchestration |
| `lib/data/team_search_database.dart` | Rewrite | Replace runtime hardcoded catalog with asset-backed or backend-backed seed data |
| `lib/providers/` and `lib/services/` | Normalize | Decide who owns data queries vs orchestration; today both do |
| `admin/src/hooks/useSupabaseQuery.ts` | Rewrite | Replace generic `any`-based wrapper with typed feature APIs |
| `admin/src/hooks/useAuth.tsx` | Split | Separate provider/context, auth bootstrap, demo adapter, and admin profile fetch |
| `admin/src/types/index.ts` | Split | Move types into feature-local modules and a small shared core |
| `admin/src/components/layout/Topbar.tsx` | Split | Extract search palette and styling concerns |
| `supabase/functions/push-notify/` | Split | Separate auth, token loading, payload schema, FCM sender, and logging |
| `supabase/functions/auto-settle/` | Split | Separate auth, match selection, settlement execution, and notification fan-out |
| `supabase/functions/gemini-sports-data/` | Split | Separate ingestion client, mapping, persistence, and telemetry |
| `.github/workflows/` | Merge / simplify | Current workflows overlap and use inconsistent Flutter versions |
| `tool/` | Keep + regroup | Scripts are useful, but should be grouped by function |
| `docs/` | Keep + curate | Introduce index/archive structure |

## 7. Code-Level Refactor Guidance

### Files To Split Immediately

- `lib/features/home/screens/match_detail_screen.dart`
- `lib/features/onboarding/screens/onboarding_screen.dart`
- `lib/features/predict/screens/predict_screen.dart`
- `lib/features/wallet/screens/wallet_screen.dart`
- `admin/src/components/layout/Topbar.tsx`
- `admin/src/hooks/useAuth.tsx`
- `supabase/functions/gemini-sports-data/index.ts`
- `supabase/functions/push-notify/index.ts`
- `supabase/functions/auto-settle/index.ts`

### Duplicated Logic To Centralize

- mobile Supabase client access and timeout/error mapping
- SharedPreferences load/save/error handling
- admin Supabase pagination/list/RPC result handling
- notification and wallet error logging patterns
- admin toast/error formatting after mutations

### Fragile Services To Harden

- `wallet_service.dart`
- `team_community_service.dart`
- `notification_service.dart`
- `marketplace_service.dart`
- `prediction_slip_service.dart`
- `admin/src/hooks/useAuth.tsx`
- `supabase/functions/push-notify/index.ts`
- `supabase/functions/auto-settle/index.ts`

### Abstractions To Introduce Carefully

- a small typed result/error envelope per surface
- feature-local query gateway modules
- boundary validation for Edge Functions and admin writes
- a small cache helper around `SharedPreferences`
- query key factories for admin React Query

### Abstractions To Remove

- dead layered/domain shells that are not used by runtime code
- over-generic admin query helpers that lean on `any`
- empty feature/module skeleton directories with no real ownership

## 8. Standardization Plan

### Naming

- use feature-first naming everywhere
- use `...Service` only for orchestration or external side effects
- use `...Gateway` or `...Api` for direct backend access
- use `...Controller` / `...Notifier` / provider names for state orchestration only

### Folder Structure

Mobile:

- `features/<feature>/presentation/...`
- `features/<feature>/application/...`
- `features/<feature>/data/...`

Admin:

- `features/<feature>/api.ts`
- `features/<feature>/hooks.ts`
- `features/<feature>/types.ts`
- `features/<feature>/components/...`

Edge Functions:

- `functions/<name>/index.ts`
- `functions/<name>/schema.ts`
- `functions/<name>/auth.ts`
- `functions/<name>/repo.ts`
- `functions/<name>/handler.ts`

### Error Handling

- standardize on one typed app error/result shape per surface
- never swallow Supabase errors into raw `dynamic` / `any`
- log once near the boundary, not repeatedly along the stack

### Async Pattern

- no synchronous `setState` inside React effects
- no raw optimistic casting of async payloads
- timeouts and retries only in boundary modules, not scattered in callers

### Logging

- mobile: keep `AppLogger` as the single dev logging surface
- admin: introduce a small logger util and avoid ad hoc `console.*`
- Edge Functions: structured logs with correlation IDs where possible

### API Result Pattern

- parse backend payloads into feature-local DTOs
- expose typed domain/application shapes to UI
- do not pass raw row maps across multiple layers

### State Management

- Flutter: Riverpod for state orchestration, not direct data querying from random screens
- Admin: React Query for fetching, feature hooks for composition, no generic “table string” abstraction as the primary API

### Validation

- validate all Edge Function inputs explicitly
- validate all admin write payloads before submission
- validate key mobile persistence payloads before cache write/read

### Theming / Design Tokens

- keep shared typography/colors in one place
- move repeated inline layout styles out of large components where they hinder reuse

### Test Structure

- mobile: feature tests near `features/<feature>/...`
- admin: hook and page tests per feature
- Supabase: SQL verification + Edge Function unit tests + a few end-to-end integration probes

## 9. Risk Classification

| Issue | Severity | Impact Area | Root Cause | Difficulty | Release Impact | Blocks Production Readiness |
| --- | --- | --- | --- | --- | --- | --- |
| Workspace is not a git checkout in current environment | critical | change safety / rollback | missing VCS context in active workspace | low to fix operationally | high | yes |
| Admin writes/reads sensitive surfaces directly from browser | high | security / auditability | no trusted admin command layer | high | high | yes |
| Admin lint debt and `any` usage | high | admin correctness | no enforced code-quality gate | medium | medium-high | yes |
| No admin automated tests | high | regression protection | manual-first development | medium | high | yes |
| No Edge Function automated tests | high | settlement / notifications | handler growth without test harness | medium | high | yes |
| Mobile giant screens | high | maintainability / velocity | screen-first growth without decomposition | medium-high | medium | no |
| Dead/partial architecture on mobile | high | maintainability | aborted architecture migration | medium | medium | no |
| Hardcoded team search database | high | performance / data ownership | onboarding seed never externalized | medium | medium | no |
| Edge Functions are monolithic and weakly typed | high | ops reliability | one-file implementation style | medium | high | yes |
| Config/env sprawl | high | security / release ops | mixed env strategies | low-medium | high | yes |
| CI duplication / inconsistent Flutter versions | medium-high | release pipeline | overlapping workflows | low | medium-high | yes |
| Dependency lag in Flutter toolchain | medium | upgrade path | slow dependency maintenance | medium | medium | no |
| Docs sprawl / archive clutter | low | team clarity | planning docs not curated | low | low | no |

## J. Phased Refactor Roadmap

### Phase 1: Safety And Blockers

Goals:

- enforce a safe baseline before deeper movement

Actions:

- restore repo to a real git checkout before broader rollout
- make admin lint green and add it to CI
- consolidate CI into one authoritative mobile workflow and one admin workflow
- centralize env handling; keep templates only in repo, secrets only in CI or local ignored files
- add smoke/integration tests for:
  - admin auth bootstrap
  - wallet transfer
  - pool join/create
  - `auto-settle`
  - `push-notify`

### Phase 2: Structural Cleanup

Goals:

- remove ambiguity and dead scaffolding

Actions:

- finish deleting obsolete archives and local artifacts from versioned paths
- introduce a docs index and archive stale plans
- regroup shell scripts by function
- split `admin/src/types/index.ts`
- replace remaining empty or placeholder module shells with real feature ownership

### Phase 3: Architecture Correction

Goals:

- converge on one real boundary pattern per surface

Actions:

- mobile:
  - move Supabase access into feature-local data gateways
  - keep Riverpod providers as application/orchestration only
- admin:
  - replace generic `useSupabaseQuery` with feature APIs
  - move sensitive writes behind trusted server-side endpoints
- backend:
  - refactor Edge Functions into smaller modules with explicit validation

### Phase 4: Code Simplification

Goals:

- cut mental load and reduce god-files

Actions:

- split the four largest mobile screens
- move large local modal/sheet widgets into feature-local presentation files
- centralize repeated cache patterns
- unify error formatting and result handling

### Phase 5: Performance And Security Hardening

Goals:

- reduce fragile runtime behavior

Actions:

- replace `team_search_database.dart` with asset/data-backed seed source
- add request timeouts/retry policy wrappers in backend-facing code
- review admin RLS dependencies and move state-changing operations server-side
- profile mobile heavy screens and remove duplicate fetch churn

### Phase 6: Tests And Release Hardening

Goals:

- make releases predictable

Actions:

- add admin unit/integration tests
- add Edge Function tests
- add critical mobile feature tests
- enforce lint/test/build gates consistently
- document release ownership and rollback steps

## K. Quick Wins

Already completed in this pass:

- fixed root repo documentation drift
- tightened `.gitignore` for admin/mobile/Supabase local artifacts and env files
- removed unused `firebase_analytics`
- removed unused `@tanstack/react-table`
- fixed admin build blocker from unused import
- fixed render-time randomness in admin state views
- removed dead mobile domain/repository layer
- restored mobile compile stability by reconnecting logger imports
- removed empty scaffold directories

Next quick wins with low implementation risk:

- split `useAuth.tsx`
- replace `any` in admin query hooks with feature-specific types
- merge duplicate mobile CI workflows
- move `team_search_database.dart` data into an asset JSON with the same query surface

## L. Release Blockers

- current workspace is not a git checkout, which blocks safe large-scale refactor rollout and review
- admin lint is red
- admin has no automated tests
- Edge Functions have no automated tests
- admin still leans too heavily on browser-side privileged data access patterns
- CI is duplicated and inconsistent across Flutter versions
- config handling remains fragmented across `.env`, JSON env files, and secrets

## M. Recommended End-State Architecture

### Mobile

- feature-first slices
- Riverpod only for application state and orchestration
- typed feature-local gateways for Supabase
- small screens with presentation-only widgets
- shared `AppLogger`, env, and cache helpers in `core/`

### Admin

- feature-local APIs/hooks/types/components
- React Query for fetch orchestration
- no stringly-typed generic table wrapper as the main abstraction
- server-mediated admin mutations for sensitive operations

### Backend

- SQL remains source of truth for schema and policy
- Edge Functions become thin, validated, typed orchestration boundaries
- operational probes remain, but are grouped and documented

## Initial Refactors Executed In This Audit Pass

Files changed or removed during this pass:

- `.gitignore`
- `README.md`
- `pubspec.yaml`
- `admin/package.json`
- `admin/src/components/ui/StateViews.tsx`
- `admin/src/features/events/EventsPage.tsx`
- `lib/main.dart`
- `lib/providers/currency_provider.dart`
- `lib/providers/favourites_provider.dart`
- `lib/services/app_telemetry.dart`
- `lib/services/auth_service.dart`
- `lib/services/market_preferences_service.dart`
- `lib/features/onboarding/providers/onboarding_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/wallet_service.dart`
- `lib/services/team_community_service.dart`
- `lib/services/marketplace_service.dart`
- `lib/services/prediction_slip_service.dart`
- `lib/services/push_notification_service.dart`
- removed orphaned files under `lib/core/di/`, `lib/data/datasources/`, `lib/data/repositories/`, `lib/domain/entities/`, `lib/domain/repositories/`, and `lib/services/supabase_service.dart`

## Verification Snapshot After Refactor Pass

- `flutter test` passed
- `flutter analyze` still reports warnings and modernization debt, but no blocking errors from this pass
- `npm --prefix admin run build` passed
- `npm --prefix admin run lint` still fails and remains a real blocker
- `npm --prefix admin audit --omit=dev --audit-level=high` found 0 vulnerabilities

