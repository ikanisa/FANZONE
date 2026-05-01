# Rollback

Rollback must protect customer orders, wallet ledger rows, pool settlements, and audit history.

## Before Release

- Tag the commit being released.
- Record migration list and deployed Edge Function versions.
- Take a database backup for high-risk schema changes.
- Save current deploy artifacts or hosting rollback identifiers.
- Record current app store build numbers.

## Web Rollback

1. Revert Cloudflare/Vercel/Netlify deployment to the previous successful artifact.
2. Confirm `/`, `/pools`, `/ordering`, admin, and venue portal routes return `200`.
3. Confirm environment variables still point to the intended Supabase project.
4. Re-run smoke checks for login, order read, and pool read.

## Mobile Rollback

1. Stop rollout in Play Console/App Store Connect if staged.
2. Promote previous stable build if supported by the store.
3. If binary rollback is unavailable, use feature flags to disable affected flows.
4. Confirm deep links and auth still work on previous build.

## Supabase Migration Rollback

Prefer forward fixes for already-applied production migrations. Direct rollback is allowed only with explicit backup/restore approval.

Safe rollback order:

1. Disable affected UI route or feature flag.
2. Disable affected cron trigger.
3. Deploy a forward migration that restores compatibility.
4. Re-run SQL verification.
5. Re-enable traffic gradually.

Never delete wallet ledger, audit, order, or settlement history to roll back a release.

## Edge Function Rollback

1. Deploy previous function source from the tagged commit.
2. Confirm secrets did not change unexpectedly.
3. Run targeted smoke script or curl probe.
4. Watch function logs for 30 minutes.

## Emergency Feature Disables

Use admin platform controls or remote app config to disable:

- pool entry;
- pool settlement cron;
- manual wallet adjustments;
- menu OCR import;
- push notifications;
- reward campaigns;
- FET spending at venues.

## Post-Rollback

- Create incident record.
- Record customer impact and affected IDs.
- Reconcile wallet ledger and settlements.
- Confirm audit logs captured the rollback actions.
- Schedule a root-cause review before relaunch.
