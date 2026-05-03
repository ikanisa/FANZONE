# Destructive Cleanup Runbook - 2026-05-01

Scope: retired DineIn assistance objects, old standings helpers, competition-following tables, prediction tables, and fantasy tables that are outside the simplified sports-bar pool product.

This cleanup is intentionally not part of the normal migration chain. Run it only after backup and dependency review.

## Backup Requirement

1. Capture a logical backup before the cleanup:

```bash
pg_dump "$SUPABASE_DB_URL" \
  --schema=public \
  --format=custom \
  --file "backups/fanzone-public-before-retired-cleanup-2026-05-01.dump"
```

2. Confirm the backup can be listed:

```bash
pg_restore --list "backups/fanzone-public-before-retired-cleanup-2026-05-01.dump" >/tmp/fanzone-cleanup-backup.list
```

## Dependency Check

Run these checks against the target database before executing the cleanup:

```sql
select dependent_schema, dependent_object_name
from information_schema.view_table_usage
where table_schema = 'public'
  and table_name in (
    'bell_requests',
    'standings',
    'team_form_features',
    'user_followed_competitions',
    'predictions',
    'prediction_entries',
    'fantasy_teams'
  );

select routine_schema, routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_definition ilike any (array[
    '%bell_requests%',
    '%standings%',
    '%team_form_features%',
    '%user_followed_competitions%',
    '%predictions%',
    '%prediction_entries%',
    '%fantasy_teams%'
  ]);
```

Stop if any active route, Edge Function, cron job, or venue/admin workflow still depends on these objects.

## Execution

Run only after backup and dependency review:

```bash
psql "$SUPABASE_DB_URL" \
  -v ON_ERROR_STOP=1 \
  -c "set app.confirm_destructive_cleanup = '2026-05-01-backup-complete';" \
  -f supabase/destructive/20260501_retired_dinein_fanzone_cleanup.sql
```

## Validation

```bash
psql "$SUPABASE_DB_URL" -f supabase/tests/sports_bar_simplified_contract.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql
```

Also verify:

- mobile app can open Bar, Pools, Wallet, and Profile;
- venue portal can update orders, menu, rewards, pools, and tables;
- admin can view curated matches, wallets, settlements, audit logs, and feature flags;
- no production jobs reference `ring_bell`, standings, individual predictions, or fantasy tables.

## Rollback

If cleanup breaks a live dependency, restore the affected objects from the backup into a staging database first, inspect the object definitions and rows, then restore only the required objects into production during an incident window.

Do not roll back by reintroducing retired app routes. Restore data only long enough to remove the dependency or build a compatibility view.
