# FET Ledger Contract

FET is an internal reward balance. It is auditable, venue-aware where required,
and not cash-redeemable.

## Client Rules

- Flutter and web clients must not update wallet tables directly.
- Clients use scoped RPCs/functions such as:
  - `get_wallet_balance`
  - `transfer_fet_by_fan_id`
  - `spend_fet_on_order`
  - `stake_fet`
  - `get_venue_fet_wallet`
  - `request_venue_fet_top_up`
  - `venue_settle_match_pool`
- User transfers require an authenticated session and a 6-digit recipient Fan ID.
- Anonymous users must not execute wallet transfer RPCs.

## Database Rules

- Wallet changes must be transactional.
- Debit paths must lock wallet state before mutation.
- A debit cannot create a negative balance.
- Every wallet movement must write a ledger/transaction row with an idempotency
  key or traceable reference.
- Duplicate payouts must be prevented with idempotency keys and settlement state.
- Raw settlement helpers remain backend/service-role only.

## Settlement Rules

- Prediction pool settlement must validate the linked venue and scheduled start.
- Winners are split by eligible winning entries only.
- Ineligible winners are recorded/shown but paid `0`.
- Venue settlement actions must be staff/owner/manager scoped.
- Settlement writes audit metadata and ledger references.

## Current Hardening

- `supabase/migrations/20260504100000_wallet_transfer_grant_hardening.sql`
  removes anonymous execution from `transfer_fet` and
  `transfer_fet_by_fan_id`.
- `supabase/tests/release_readiness_hardening.sql` asserts that anonymous users
  cannot execute wallet transfer RPCs while authenticated users can still use
  the Fan ID transfer RPC.
