# Pool Operations

This is the production operating guide for the sports-bar pool engine.

## Runtime Jobs

- `settle-match-pools` is the only scheduled gaming settlement job.
- The GitHub workflow `.github/workflows/cron-settle.yml` calls it every 15 minutes with `x-cron-secret`.
- Admins can manually run the same settlement path from Admin -> Pool Operations. The UI calls `admin_run_pool_settlement`, which authenticates the admin, executes `settle_finished_match_pools`, and writes `pool_operation_audit_logs`.
- Required secrets:
  - `SUPABASE_URL`
  - `CRON_SECRET`

Manual run:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: $CRON_SECRET" \
  "$SUPABASE_URL/functions/v1/settle-match-pools" \
  -d '{"limit":50}'
```

## Curation

- Admins curate discoverable fixtures in Admin -> Match Curation.
- `curated_matches` controls country, venue, priority, active status, and display window.
- Do not hardcode World Cup or local league fixtures in app code. Import match data, then curate rows.
- Venue owners/managers create official venue pools only from curated options returned by `venue_pool_match_options`.
- Official venue creation uses `create_venue_official_match_pool`, which enforces venue ownership/management, curation eligibility, and the one-official-pool-per-venue-match unique rule.
- Direct venue pool creation through `create_match_pool` also requires active curation for non-admin venue pools.

## Abuse Controls

- Global and country pools are admin-only.
- Venue pools require an active venue and either venue owner/manager permissions or explicit venue feature flags.
- Guest-created linked venue pools are disabled by default and, when enabled, are limited by venue feature keys:
  - `allow_user_pool_creation`
  - `guest_pool_daily_limit` default `3`, max `25`
  - `guest_pool_match_limit` default `1`, max `5`
  - `guest_pool_entry_cap_fet` default `500`, max `100000`
- Official venue pools are still protected by the unique `(venue_id, match_id)` official-pool rule.
- Pool creation, settlement runs, and social-card URL changes are auditable through `pool_operation_audit_logs` and admin audit logs where applicable.

## Operations Dashboard

- Admin -> Pool Operations shows:
  - open, locked, settling, stale settling, failed settlement, and pending-final counts;
  - open FET stake, recent settlements, invite reward volume, and missing social cards;
  - the pool operations queue from `admin_pool_operations_queue`.
- Every insert/update/delete on `match_pools` writes `pool_operation_audit_logs`.
- Operators should investigate:
  - `failedSettlements > 0`;
  - `staleSettlingPools > 0`;
  - final matches with pools still marked `open`, `locked`, or `settling`;
  - pools missing social cards before high-traffic campaigns.

## Invite Rewards

- Pool creator rewards are activated through `match_pool_invites`.
- `create_match_pool_invite(pool_id)` creates a tracked invite code.
- `join_match_pool(..., p_invite_code)` credits the creator only after a qualified invited participant joins and stakes FET.
- Reward credits are written to `fet_wallet_transactions` with `source = 'pool_creator_reward'`.

## Social Cards

- `get_match_pool_social_card_payload(pool_id)` returns the canonical payload for a renderer.
- `set_match_pool_social_card_url(pool_id, url, metadata)` stores a generated HTTPS or site-relative image URL.
- `generate-pool-social-card` renders a deterministic SVG social card, uploads it to the public `pool-social-cards` bucket, then stores the generated URL through `set_match_pool_social_card_url`.
- The Edge Function requires an authenticated admin or venue operator. If URL registration fails authorization, the uploaded object is removed.
- Social-card payload access is limited to visible pools, admins, or venue operators.
- Store generated images in the controlled bucket/path; do not accept arbitrary unvalidated user URLs.

## Rollback

- Disable scheduled calls by disabling the GitHub workflow or removing `CRON_SECRET`.
- Disable user-facing pool routes through the platform feature registry by setting `pools` inactive.
- Additive tables can remain idle; do not drop pool tables until wallet ledger and settlement exports are backed up.
