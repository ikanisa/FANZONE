# FANZONE Fullstack Platform 100% Completion Checklist

Date: 2026-06-21  
Scope: Flutter customer app, venue/bar PWA, TV games PWA, admin panels, backend, database policies, Malta/Rwanda market architecture, permissions, chat, games, and release evidence.

This checklist expands the Flutter-only UX remediation into the full platform goal. It is intentionally strict: a `100%` claim is blocked until the machine-readable matrix at `release/qa/fullstack-platform-completion-matrix.json` is complete, strict UX evidence passes, and the release evidence gate is green.

## Product Boundaries

- FANZONE remains a sports hospitality, venue operations, games, and loyalty platform.
- No betting, gambling, odds, wagering, cash-out, customer wallet, or platform payment execution.
- FET remains a non-cash loyalty and rewards ledger.
- Customer payments remain off-platform unless a future provider integration is explicitly approved and separately audited.
- Malta and Rwanda are the two target countries for this platform scope.

## Research Baseline

- Flutter localization should use Flutter's official internationalization flow, generated localization resources, and locale-aware formatting.
- Mobile permissions must follow native platform rules for foreground/background location, notification authorization, denied/permanently denied states, and settings recovery.
- Web/PWA notifications and installability require service-worker and push evidence per web-push provider constraints.
- Supabase tables, views, realtime channels, RPCs, and Edge Functions must enforce RLS or equivalent server-side authorization; UI guards are not sufficient.
- AI-generated games must use structured output validation, safety review, versioning, admin approval, and audit before publication.

## Required Surfaces

| Surface | Required completion scope |
| --- | --- |
| Flutter customer app | Native-quality mobile UX, Malta/Rwanda localization, location and notification permissions, order/payment recovery, support, chat, games, rewards, accessibility, and evidence |
| Venue/bar PWA | Staff operations, orders, menu, manual payments, venue support/chat, games controls, rewards, localization, realtime, and venue-scoped security |
| Admin panels | Country/market controls, venues, users/roles, weekly AI game generation, game approval, bar assignment, audit, moderation, feature flags, rewards, and evidence |
| TV games PWA | Pairing, venue display, game lobby, questions, leaderboard, join instructions, locale/venue branding, and venue-safe realtime reads |
| Backend and database | Append-only migrations, RLS, RPCs/Edge Functions, audit, abuse controls, SQL/Edge tests, and linked Supabase validation |

## Completion Matrix

The authoritative checklist is `release/qa/fullstack-platform-completion-matrix.json`.

Required evidence buckets for every row:

- `frontend`
- `backend`
- `databasePolicy`
- `testCoverage`
- `releaseEvidence`
- `owner`
- `nextAction`

Rows may declare `notApplicableEvidenceKeys` only when a bucket is structurally irrelevant, such as `frontend` for a pure backend/database security row. A row still cannot pass until all applicable buckets contain strict evidence.

Rows currently cover:

- Flutter customer app UX
- Venue/bar PWA operations
- Admin panels and platform operations
- TV games PWA display
- Malta/Rwanda market architecture
- Location and notification permissions
- Client-to-bar in-app chat
- Weekly AI game generation
- Random per-bar game assignment
- Three core games end-to-end
- Database policy quality
- Release quality evidence

## Gates

Inventory gate:

```bash
node tool/validate_fullstack_platform_completion_matrix.mjs
```

Strict final gate:

```bash
node tool/validate_fullstack_platform_completion_matrix.mjs --require-pass
node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass
./tool/check_world_class_evidence.sh
```

## Current State

The fullstack matrix is not pass-ready. It is an implementation and evidence contract that keeps the expanded goal visible while code-owned work continues.

Current known blockers:

- Strict Flutter UX matrix still has incomplete P0/P1 rows.
- Venue/bar PWA, TV PWA, and admin panels need their own route/state/evidence inventories.
- Malta/Rwanda architecture must be proven across Flutter, web apps, backend config, database constraints, payment copy, phone formats, currency, and timezone behavior.
- Location and notification permission flows need native device evidence.
- Client-to-bar chat now has an additive MVP across Supabase schema/RPC/RLS, Flutter, and venue PWA, but it still needs linked SQL execution, realtime proof, screenshots, notification/read-state evidence, moderation workflow, and abuse tests before it can pass.
- Weekly AI game generation and random per-bar assignment are not yet implemented end-to-end.
- Supabase dry-run currently requires valid database credentials/connectivity.
- World-class evidence gate still fails on external release/signoff/artifact freshness blockers.
