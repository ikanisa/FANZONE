# Lean Prediction Migration Notes

## Cutover Strategy

This was a replacement refactor, not a backward-compatibility expansion.

The migration prioritized:

- dropping obsolete tables and RPCs
- normalizing the core football schema
- preserving only useful operational continuity
- keeping the live app on one clear prediction contract

## Main Migration Files

- `20260422130000_lean_prediction_domain_reset.sql`
- `20260422143000_lean_prediction_admin_policies.sql`

## Backend Changes

- old prediction challenge, slip, market, and odds structures were dropped
- lean football catalog tables were created or normalized
- new views were rebuilt on top of the lean schema
- scoring and prediction generation RPCs replaced pool settlement flows

## App Changes

- prediction entry consolidated around `/predict` and match detail
- old pool and jackpot routes now redirect away from the live path
- match detail moved to engine output, consensus, recent form, and saved picks
- admin predictions and fixtures pages were rewritten around the new contract

## Data Preservation Approach

- keep existing competitions, teams, and reusable match history where possible
- map legacy display fields into the lean match schema where they still had value
- discard structures that only existed to support odds, pools, slips, or settlement sidecars

## Rollback Awareness

This migration is intentionally decisive. A full rollback would require restoring old migrations and data snapshots. Treat the lean schema as the forward path and use database backups rather than partial table resurrection.
