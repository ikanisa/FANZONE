# Scheduler And Observability Readiness

This document defines the evidence required before the scheduler, cron
monitoring, observability, and alerting launch controls can move to `PASS`.

Current release status: `PENDING`. The 2026-05-21 evidence run proved deployed
web surfaces, Supabase validation, backup evidence, and production env
isolation, but cron smoke remained pending because `CRON_SECRET` was not present
in exported env or `.env`.

## Scheduler Evidence Required

Required jobs:

- `settle-match-pools`
- `dispatch-match-alerts`

Required evidence bundle:

```text
output/release-evidence/<timestamp>/scheduler/
```

Required files:

- `scheduler-inventory.txt`: provider, schedule expression, timezone, target
  function URL, secret name, and owner for every production job.
- `settle-match-pools-smoke.log`: output from
  `tool/run_supabase_cron_job.sh settle-match-pools`.
- `dispatch-match-alerts-smoke.log`: output from
  `tool/run_supabase_cron_job.sh dispatch-match-alerts`.
- `scheduler-history-redacted.txt`: provider history showing recent successful
  runs for each job.
- `missed-run-alert-redacted.txt`: alert rule, destination, severity, and owner.
- `incident-routing-redacted.txt`: escalation channel and backup owner.

Run locally only after `SUPABASE_URL` and `CRON_SECRET` are available in the
environment or ignored `.env`:

```bash
tool/run_supabase_cron_job.sh settle-match-pools
tool/run_supabase_cron_job.sh dispatch-match-alerts
```

Then rerun the aggregate collector:

```bash
FANZONE_WEBSITE_URL=https://fanzone.ikanisa.com \
FANZONE_ADMIN_URL=https://fanzoneadmin.ikanisa.com \
FANZONE_VENUE_PORTAL_URL=https://fanzone.venue.ikanisa.com \
FANZONE_TV_DISPLAY_URL=https://fanzonetv.ikanisa.com \
tool/collect_world_class_evidence.sh
```

## Observability Evidence Required

Required evidence bundle:

```text
output/release-evidence/<timestamp>/observability/
```

Required files:

- `runtime-error-telemetry-redacted.txt`: Sentry or equivalent project names,
  DSN presence confirmation, and alert destinations for Flutter, website,
  admin, venue portal, TV display, and Supabase Edge Functions.
- `dashboard-inventory-redacted.txt`: dashboard names and monitored signals for
  auth, ordering, payments, wallet ledger, pools, rewards, admin moderation,
  TV display refresh, Edge Function 5xx, and scheduler failures.
- `alert-routes-redacted.txt`: alert channel, primary owner, backup owner, and
  severity mapping.
- `post-deploy-watch.txt`: watch owner, watch window, dashboards checked, and
  rollback threshold.
- `sample-alert-test-redacted.txt`: proof that at least one non-destructive test
  alert reached the configured route.

## PASS Criteria

Do not mark `Scheduler and cron monitoring` or `Production observability and
alerting` as `PASS` in `docs/release/world-class-evidence-matrix.md` until:

- both cron smoke commands pass against the production target;
- provider scheduler history proves recent successful runs;
- missed-run alerts are configured and tested;
- telemetry and dashboards cover all launch surfaces;
- alert routing has named primary and backup owners;
- the post-deploy watch plan is reviewed and assigned.
