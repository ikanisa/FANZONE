# Architecture Overview

FANZONE is a production sports-bar entertainment platform. Guests scan table QR codes, browse a venue menu, place orders, receive FET rewards, join match pools, and keep or spend FET where a venue allows it.

The platform intentionally excludes betting, odds, individual prediction scoring, fantasy modes, badge clutter, and payment APIs.

## Product Boundaries

Core product:

- venue menu browsing and order placement;
- manual off-platform payment confirmation;
- FET reward earning from orders;
- FET wallet ledger;
- match curation;
- pool creation, joining, live stats, sharing, and settlement;
- venue console operations;
- admin operations, audit, and release controls.

Payments:

- customer money movement is off-system;
- the app may show cash, MoMo/USSD, or Revolut-link instructions;
- staff or admins manually confirm payment status;
- every sensitive confirmation must write audit state.

## Runtime Surfaces

```text
Flutter mobile app
  -> Riverpod providers and gateways
  -> Supabase client
  -> guest ordering, wallet, pools, profile, notifications

Website PWA
  -> Vite, React, Zustand
  -> Supabase browser client and Edge Functions
  -> public guest web, QR ordering, pools, wallet

Venue portal
  -> Vite, React
  -> Supabase browser client, RPCs, Edge Functions
  -> orders, menu, pools, FET rewards, QR, insights

Admin console
  -> Vite, React
  -> Supabase browser client, admin RPCs, Edge Functions
  -> curation, platform controls, wallet oversight, audit

Supabase
  -> Postgres schema, RLS, triggers, RPCs
  -> Edge Functions for imports, orders, notifications, settlement, OTP
```

## Source Of Truth

| Domain | Source of truth |
| --- | --- |
| Users and sessions | Supabase Auth plus profile tables. |
| Venue membership | `venue_users` with owner, manager, staff roles. |
| Menus and orders | `venues`, `menu_categories`, `menu_items`, `tables`, `orders`, `order_items`. |
| Payment status | `orders.payment_status` plus `payment_events` and `audit_logs`. |
| FET wallet | `fet_wallets` and `fet_wallet_transactions`; no duplicate wallet state. |
| Match data | `competitions`, `seasons`, `teams`, `matches`, `curated_matches`. |
| Pools | `match_pools`, `match_pool_camps`, `match_pool_entries`, `match_pool_settlements`. |
| Audit | `audit_logs` and pool operation audit tables. |
| Runtime config | `app_config_remote`, feature flag tables, venue `features_json`. |

## Non-Negotiable Invariants

- RLS must isolate venues, users, countries, and admin-only operations.
- Sensitive writes use audited RPCs or Edge Functions.
- Settlement is idempotent and wallet-ledger backed.
- Pool gameplay is the only game mechanic.
- No payment provider API is used for customer payment execution.
- Client apps never receive service-role keys.
- Production paths must not depend on mock data or hidden demo-only flows.
