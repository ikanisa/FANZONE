# FET Supply Governance

This document defines the backend accounting rules for FANZONE's internal FET ledger.

## Cap

- Operational hard cap: `100,000,000 FET`.
- The hard cap is a release gate, not just a dashboard metric.
- Minting RPCs now enforce the cap in SQL through `public.assert_fet_mint_within_cap(...)`.
- `public.fet_supply_overview` exposes both `supply_cap` and `remaining_mintable` for operator checks.

## Allowed Minting Paths

- `ensure_user_foundation(p_user_id)` may mint the one-time onboarding grant currently set to `5,000 FET`.
- `admin_credit_fet(p_target_user_id, p_amount, p_reason)` may mint discretionary credits for support, remediation, or controlled promotions.
- `settle_prediction_slips_for_match(...)` may mint rewards for winning free prediction slips.
- `settle_daily_challenge(...)` may mint daily challenge rewards and exact-score bonuses.

## Non-Minting Paths

- `create_pool`, `join_pool`, `settle_pool`, and `void_pool` only redistribute already-issued FET between locked stakes and participant wallets.
- `transfer_fet` only moves FET between user wallets.
- `contribute_fet_to_team` only debits an existing user wallet and records the contribution.

## Required Ledger Rules

- Every mint or redistribution must write a matching `fet_wallet_transactions` row in the same transaction as the wallet update.
- Direct writes to `fet_wallets` outside approved RPCs are prohibited.
- Admin-issued credits must include a human-readable reason in both the RPC input and the resulting transaction title.
- Refund flows must restore balances from recorded stake values and never mint extra FET.
- Integer division dust from pool settlement must be fully distributed to winners; no silent remainder burn is allowed.
- `settle_pool(...)` must distribute any integer remainder deterministically by awarding `+1 FET` to the earliest winning entries until the remainder is exhausted.

## Operational Checks

- Review `public.fet_supply_overview` before any bulk credit or promotional mint.
- Confirm `remaining_mintable >= expected_mint_amount` before running any manual or scheduled minting flow.
- Record the expected post-mint total supply in the release or incident ticket before running `admin_credit_fet` at scale.
- Treat any mismatch between wallet balances and transaction history as a launch-blocking issue.
- Use `public.get_pool_settlement_reconciliation(...)` for pool-by-pool settlement checks before and after settlement incidents.
- Use `public.get_pool_settlement_integrity_summary(...)` for dashboard-grade monitoring of recent settlement integrity.

## Current Enforcement

- `public.fet_supply_cap()` is the database constant for the current hard cap.
- `public.assert_fet_mint_within_cap(...)` serializes minting transactions and rejects any mint that would push total issued FET above the cap.
- The enforced minting paths are `ensure_user_foundation`, `admin_credit_fet`, `settle_prediction_slips_for_match`, and `settle_daily_challenge`.
- `public.settle_pool(...)` redistributes the full pool with deterministic remainder handling in `20260418121500_p0_hardening_fixups.sql`.
- `public.get_pool_settlement_reconciliation(...)` and `public.get_pool_settlement_integrity_summary(...)` expose admin-safe reconciliation reports in `20260419150000_pool_settlement_reconciliation.sql`.
