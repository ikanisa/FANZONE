# Product Simplification Audit - 2026-05-01

Scope: merged DineIn plus FANZONE repository at `/Volumes/PRO-G40/FANZONE`.

Target product: sports-bar entertainment platform for venue menu ordering, FET wallet rewards, curated match pools, venue operations, admin control, QR/deep-link entry, pool sharing, and settlement.

## Executive Summary

The repository is already partially refactored toward the target product. The strongest completed areas are the Supabase baseline, wallet/settlement migrations, venue portal IA, admin route IA, and Flutter pool/order/wallet screens. The main cleanup risks are stale mobile navigation, dead admin screens left outside the route tree, legacy Flutter venue-dashboard/bell code, website guest-PWA drift, and remaining football-data helper code for standings/competition browsing.

No destructive database migration should be applied without a backup. The current database cleanup should stay additive or compatibility-based because the baseline contains live tables and RPC aliases used by older remote projects.

## KEEP / REFACTOR / REMOVE

| Area | Classification | Reason |
| --- | --- | --- |
| Flutter `ordering` feature | KEEP | Supports venue/table context, menu, cart, order creation, status, payment guidance, and FET earn preview. |
| Flutter `pools` feature | KEEP | Supports pool list, create, join/stake, detail, share entry, and pool stats. |
| Flutter `wallet` feature | KEEP | Connects guest wallet UI to Supabase wallet balance and ledger services. |
| Flutter `profile` feature | KEEP | Supports profile, country/favorite-team personalization, notifications, and responsible settings surface. |
| Flutter `home` Today screen | REFACTOR | Useful as launch/session resolver and quick action surface, but it must not occupy a primary bottom-nav branch. |
| Flutter `venue_dashboard` feature | REMOVE | Mobile guest app must not contain venue console operations; venue operations live in `apps/venue-portal`. |
| Flutter bell/ring-bell models/gateway | REMOVE | Table assistance is old DineIn clutter and not part of ordering, wallet, pools, venue ops, or admin ops. |
| Flutter standings providers/widgets | REMOVE PHASE 2 | Not routed in the simplified product; standings are football-data clutter unless admin-only import validation needs them. |
| Flutter competition/followed-competition preferences | REFACTOR | Keep country/favorite-team personalization; remove public competition browsing/following UX. |
| Flutter legacy routes `/league`, `/fixtures`, `/team`, `/venue-dashboard` | REFACTOR | Keep only redirects to product surfaces; no screens. |
| Venue portal Orders/Menu/Pools/FET Rewards/Tables/Insights/Settings | KEEP | Matches required venue dashboard navigation. |
| Venue portal menu OCR/magic | REFACTOR | Useful if it accelerates menu setup, but keep behind venue-only controls. |
| Admin Overview/Countries/Venues/Competitions/Teams/Curated Matches/Pools/FET Wallets/Settlements/Reward Rules/Risk/Feature Flags/Audit | KEEP | Matches required admin PWA IA. |
| Admin `analytics`, `tokens`, `users`, `admin-access`, `account-deletions` pages | REMOVE | Dead screens outside the route tree or old generic admin surfaces. Wallet oversight and audit logs replace token/user clutter. |
| Admin `hospitality-audit/useHospitality` | REFACTOR | `VenuesPage` still uses its venue hook; move/rename later instead of deleting immediately. |
| Admin `settings/useSettings` | REFACTOR | `PlatformControlPage` still uses settings hooks; move under feature flags/platform control later. |
| Public website PWA | REFACTOR | Keep as web fallback/share/deep-link PWA; simplify navigation around Bar, Pools, Wallet, Profile. |
| Supabase pool engine tables/RPCs | KEEP | `match_pools`, camps, entries, invites, settlement, sharing, aliases, and tests support pool-only gameplay. |
| Supabase wallet ledger | KEEP | `fet_wallets` plus `fet_wallet_transactions`/`fet_ledger` view are the wallet source of truth. |
| Supabase curation model | KEEP | `countries`, `competitions`, `teams`, `matches`, `curated_matches`, and curation RPCs support curated match discovery. |
| Supabase `bell_requests` and `ring_bell` | REMOVE PHASE 2 | Old DineIn assistance flow; use safe deprecation before dropping DB objects. |
| Supabase standings/team form features | REMOVE PHASE 2 | Not needed for curated pool product; dropping is destructive and needs backup/compatibility checks. |

## Route Cleanup Map

| Surface | Current | Target | Action |
| --- | --- | --- | --- |
| Flutter primary nav | Branches include `/today`, `/bar`, `/pools`, `/wallet`, `/profile` while nav labels only four tabs | `/bar`, `/pools`, `/wallet`, `/profile` | Remove Today from tab stack; keep `/today` as standalone launch/home route. |
| Flutter root | `/` -> `/today` | `/` -> `/bar` or QR-resolved current bar | Redirect root to `/bar`; splash can still route to QR/current context. |
| Flutter legacy football routes | `/league/:id`, `/fixtures`, `/team/:teamId` | `/pools` | Keep redirects only. |
| Flutter venue dashboard route | `/venue-dashboard` -> `/today` | `/bar` | Redirect to guest product surface. |
| Venue portal | `/orders`, `/menu`, `/pools`, `/rewards`, `/tables`, `/insights`, `/settings` | same | Keep. |
| Admin | `/`, `/countries`, `/venues`, `/competitions`, `/teams`, `/matches`, `/pools`, `/wallets`, `/settlements`, `/rewards`, `/risk`, `/flags`, `/audit` | same | Keep. |
| Website | `/`, `/ordering`, `/v/:slug`, `/pools`, `/wallet`, `/profile`, `/settings` | Bar/Pools/Wallet/Profile plus pool share fallback | Refactor later to avoid independent product drift. |

## Component Cleanup Map

| Component group | Classification | Action |
| --- | --- | --- |
| `lib/widgets/common/*` design system | KEEP | Reusable for simplified product. |
| `lib/widgets/match/match_list_widgets.dart` | KEEP | Used for curated match cards. |
| `lib/widgets/match/standings_table.dart` | REMOVE PHASE 2 | Not needed unless admin-only standings review is reintroduced. |
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
| `bell_gateway` | REMOVE | Old DineIn assistance flow. |
| competition catalog/search/standings gateways | REFACTOR | Keep curated match discovery; remove public standings/full competition browsing paths. |
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
| `bell_requests`, `ring_bell` | REMOVE PHASE 2 | Deprecate first, then drop after live dependency check. |
| `standings`, `team_form_features` | REMOVE PHASE 2 | Not in product scope; destructive drop requires backup and migration review. |
| generic moderation/user/account deletion tables | ADMIN-ONLY / REFACTOR | Keep only where required for risk, privacy, and support obligations. |

## Safe Deletion Plan

1. Delete only files that are unreferenced by active routes/build imports.
2. Replace stale mobile tab structure without removing the Today screen.
3. Remove mobile venue-dashboard and bell code from the Flutter DI graph.
4. Keep all DB objects for now; mark non-product DB objects as phase-2 deprecation instead of dropping them.
5. After tests pass, run a live dependency search before any DB drop migration.
6. For destructive DB cleanup, require backup, migration dry run, rollback SQL, and production read-only window.

## First Implementation Phase

- Fix Flutter primary tab stack to exactly Bar, Pools, Wallet, Profile.
- Keep `/today` as a standalone launch/home screen outside primary nav.
- Delete dead admin pages not referenced by active admin routes.
- Delete dead mobile venue dashboard/bell files and DI provider.
- Restrict backend-only pool locking and order reward helpers to service execution.
- Update documentation and run build/analyze/test where possible.
