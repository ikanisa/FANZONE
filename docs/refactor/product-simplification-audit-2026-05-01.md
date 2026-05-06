# Product Simplification Audit - 2026-05-01

Scope: merged DineIn plus FANZONE repository at `/Volumes/PRO-G40/FANZONE`.

Target product: sports-bar entertainment platform for venue menu ordering, FET wallet rewards, curated match pools, venue operations, admin control, QR/deep-link entry, pool sharing, and settlement.

## Executive Summary

The repository is refactored toward the simplified sports-bar product. The strongest completed areas are the Supabase baseline, wallet/settlement migrations, venue portal IA, admin route IA, website guest IA, and Flutter pool/order/wallet screens. The main remaining cleanup risk is destructive database retirement, which now has a guarded script and runbook but must not be executed without backup and dependency review.

No destructive database migration should be applied without a backup. The current database cleanup should stay additive or compatibility-based because the baseline contains live tables and RPC aliases used by older remote projects.

## KEEP / REFACTOR / REMOVE

| Area | Classification | Reason |
| --- | --- | --- |
| Flutter `ordering` feature | KEEP | Supports venue/table context, menu, cart, order creation, status, payment guidance, and FET earn preview. |
| Flutter `pools` feature | KEEP | Supports pool list, create, join/stake, detail, share entry, and pool stats. |
| Flutter `wallet` feature | KEEP | Connects guest wallet UI to Supabase wallet balance and ledger services. |
| Flutter `profile` feature | KEEP | Supports profile, country/favorite-team personalization, notifications, and responsible settings surface. |
| Flutter Home screen | KEEP | FANZONEUI-aligned launch surface for FET balance, venue discovery, Arena entry, profile, and featured matches. |
| Flutter `venue_dashboard` feature | REMOVE | Mobile guest app must not contain venue console operations; venue operations live in `apps/venue-portal`. |
| Flutter bell/ring-bell models/gateway | KEEP | Guest table assistance is part of the venue ordering flow and is handled through the `ring_bell` Edge Function plus venue portal acknowledgement. |
| Flutter standings providers/widgets | REMOVE | Deleted from the mobile guest app; standings are not part of pool-only gameplay. |
| Flutter competition/followed-competition preferences | REMOVE | Public competition following was replaced by country/favorite-team personalization and pool discovery. |
| Flutter legacy routes `/league`, `/fixtures`, `/team`, `/today`, `/venue-dashboard` | REMOVE | Removed from the production router; app-generated destinations now point to Home, Venues, Arena, Orders, Wallet, Match detail, or Pool detail. |
| Venue portal Orders/Menu/Pools/FET Rewards/Tables/Insights/Settings | KEEP | Matches required venue dashboard navigation. |
| Venue portal menu OCR/magic | REFACTOR | Useful if it accelerates menu setup, but keep behind venue-only controls. |
| Admin Overview/Countries/Venues/Competitions/Teams/Curated Matches/Pools/FET Wallets/Settlements/Reward Rules/Risk/Feature Flags/Audit | KEEP | Matches required admin PWA IA. |
| Admin `analytics`, `tokens`, `users`, `admin-access`, `account-deletions` pages | REMOVE | Dead screens outside the route tree or old generic admin surfaces. Wallet oversight and audit logs replace token/user clutter. |
| Admin `hospitality-audit/useHospitality` | REFACTOR | `VenuesPage` still uses its venue hook; move/rename later instead of deleting immediately. |
| Admin `settings/useSettings` | REFACTOR | `PlatformControlPage` still uses settings hooks; move under feature flags/platform control later. |
| Public website PWA | REFACTOR | Keep as web fallback/share/deep-link PWA; simplify navigation around Home, Venues, Arena, Orders, and Wallet. |
| Supabase pool engine tables/RPCs | KEEP | `match_pools`, camps, entries, invites, settlement, sharing, aliases, and tests support pool-only gameplay. |
| Supabase wallet ledger | KEEP | `fet_wallets` plus `fet_wallet_transactions`/`fet_ledger` view are the wallet source of truth. |
| Supabase curation model | KEEP | `countries`, `competitions`, `teams`, `matches`, `curated_matches`, and curation RPCs support curated match discovery. |
| Supabase `bell_requests` and `ring_bell` | KEEP | Staff call requests are restored as an active ordering/venue-ops surface. Do not include these objects in destructive cleanup. |
| Supabase standings/team form features | REMOVE | Mobile helpers are removed; database drops are gated because they are destructive. |

## Route Cleanup Map

| Surface | Current | Target | Action |
| --- | --- | --- | --- |
| Flutter primary nav | Home, Venues, Arena, Orders, Wallet | same | Keep the FANZONEUI-aligned bottom nav. |
| Flutter root | `/` -> `/home` | same | Splash routes to QR/current venue context when present; otherwise Home. |
| Flutter legacy football routes | removed | removed | Production app code no longer generates `/league`, `/fixtures`, or `/team` destinations. |
| Flutter venue dashboard route | removed | removed | Venue operations live in `apps/venue-portal`; the mobile app keeps guest venue discovery only. |
| Venue portal | `/orders`, `/menu`, `/pools`, `/rewards`, `/tables`, `/insights`, `/settings` | same | Keep. |
| Admin | `/`, `/countries`, `/venues`, `/competitions`, `/teams`, `/matches`, `/pools`, `/wallets`, `/settlements`, `/rewards`, `/risk`, `/flags`, `/audit` | same | Keep. |
| Website | Home/Venues/Arena/Orders/Wallet-oriented guest PWA | same | Guest PWA should stay aligned to the simplified mobile journeys and pool share fallback. |

## Component Cleanup Map

| Component group | Classification | Action |
| --- | --- | --- |
| `lib/widgets/common/*` design system | KEEP | Reusable for simplified product; unused legacy widgets were deleted. |
| `lib/widgets/match/match_list_widgets.dart` | REMOVE | Deleted after active match surfaces moved to FANZONEUI cards and `TeamCrest`. |
| `lib/widgets/match/standings_table.dart` | REMOVE | Deleted from the mobile guest app. |
| Flutter pool/order/wallet widgets | KEEP | Direct product value. |
| Flutter `venue_dashboard/*` | REMOVE | Replaced by venue PWA. |
| Admin layout and UI components | KEEP | Shared admin console primitives. |
| Admin dead feature page components | REMOVE | Delete unreferenced old pages. |
| Website UI components | REFACTOR | Keep reusable cards/status/FET components; remove product-drift screens later. |

## Service Cleanup Map

| Service/gateway | Classification | Action |
| --- | --- | --- |
| Supabase auth/session services | KEEP | Required for guest/auth wallet and protected operations. |
| `order_gateway`, `venue_gateway`, cart/order providers | KEEP | Guest ordering and venue context. |
| `pools_repository` | KEEP | Pool list/detail/create/join/share. |
| `wallet_gateway`, `wallet_service` | KEEP | Wallet reads and RPC-backed writes. |
| `bell_gateway` | KEEP | Guest ordering uses it to call `ring_bell`; venue portal reads `bell_requests` for staff acknowledgement. |
| competition catalog/search gateways | KEEP | Curated match discovery remains; public standings/full competition browsing paths were removed. |
| Admin data hooks for active IA | KEEP | Admin PWA operations. |
| Admin token/user/analytics hooks | REMOVE | Replaced by wallet oversight, audit logs, and overview. |

## Database Cleanup Map

| Data object | Classification | Notes |
| --- | --- | --- |
| `countries`, `venues`, `tables`/`venue_tables`, menu/order tables | KEEP | Required for rollout, QR, ordering, venue operations. |
| `competitions`, `teams`, `matches`, `curated_matches` | KEEP | Required for data-driven match curation. |
| `match_pools`, `match_pool_camps`, `match_pool_entries` | KEEP | Canonical pool engine; `pools`, `pool_camps`, `pool_entries` views provide requested naming compatibility. |
| `fet_wallets`, `fet_wallet_transactions`, `fet_ledger` | KEEP | Ledger-backed wallet source of truth. |
| `reward_rules`, `settlement_runs`/`match_pool_settlements`, `audit_logs` | KEEP | Required for rewards, settlement monitoring, auditability. |
| `bell_requests`, `ring_bell` | KEEP | Active guest-to-staff assistance flow for table service. |
| `standings`, `team_form_features` | REMOVE | Not in product scope; DB objects are covered by the guarded destructive cleanup script. |
| generic moderation/user/account deletion tables | ADMIN-ONLY / REFACTOR | Keep only where required for risk, privacy, and support obligations. |

## Safe Deletion Plan

1. Delete only files that are unreferenced by active routes/build imports.
2. Replace stale mobile tab structure and remove legacy mobile route aliases.
3. Keep mobile venue-dashboard operations out of the Flutter app; keep the guest bell gateway in the ordering graph.
4. Keep destructive DB drops outside the normal migration chain.
5. Run the live dependency search in `docs/refactor/destructive-cleanup-runbook-2026-05-01.md` before any DB drop.
6. For destructive DB cleanup, require backup, guarded execution, rollback planning, and a production maintenance window.

## First Implementation Phase

- Fix Flutter primary tab stack to exactly Home, Venues, Arena, Orders, Wallet.
- Remove `/today` and other old mobile aliases from production routing.
- Delete dead admin pages not referenced by active admin routes.
- Delete dead mobile venue dashboard files while preserving the guest bell gateway and `ring_bell` Edge Function.
- Restrict backend-only pool locking and order reward helpers to service execution.
- Update documentation and run build/analyze/test where possible.

## Second Implementation Phase

- Simplify website guest PWA navigation to Home, Venues, Arena, Orders, Wallet.
- Remove website/mobile home-feed drift and old route aliases.
- Remove Flutter standings, competition-following helpers, and old competition search routes.
- Add live Supabase verification for the simplified product contract and RLS hardening audit.
- Add a guarded destructive cleanup script and backup runbook for retired database objects.
