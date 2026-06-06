# Scheduler And Observability Readiness

This document defines the evidence required before the scheduler, cron
monitoring, observability, and alerting launch controls can move to `PASS`.

Current release status: `PENDING`. The 2026-06-06 evidence run proved deployed
web surfaces, Supabase validation, backup evidence, production env isolation,
unauthorized scheduler endpoint protection, credential-free scheduler payload
dry-runs, credentialed cron smoke for `settle-match-pools`,
`dispatch-match-alerts`, and `sync-livescore-football`, and code-owned runtime
telemetry hardening for bounded/redacted Supabase RPC writes and nested
metadata/property redaction, including linked SQL proof at
`output/release-evidence/observability-telemetry-hardening/20260606T060909Z.log`.
The scheduler workflow code evidence also verifies the repo-owned scheduled
workflows for explicit cron cadence, manual dispatch fallback, main-branch
gating, production-operations environment approval, concurrency, secret
preflight, expected Edge targets, and credential-free workflow storage.
`release/operations/scheduler-platform-cron-manifest.json` is the
credential-free platform-cron setup contract for provider activation. It pins
each scheduler job to the expected provider, cron expression, Edge target,
payload, max lag, severity, and `CRON_SECRET` secret name while keeping each job
marked `PENDING_PROVIDER_ACTIVATION` until provider evidence is captured.
`release/operations/scheduler-provider-state-evidence.json` captures the current
GitHub Actions provider state without writing tokens or run URLs. The current
provider evidence is `BLOCKED_PROVIDER_STATE`: the two default-branch scheduler
workflows have recent failed scheduled runs and the LiveScore workflow is not
present on the default branch yet.
The scheduled Edge functions also write database-backed run-history records via
`cron_job_start` and `cron_job_finish`, with `admin_scheduler_health_snapshot`
providing an admin-only missed-run and alert-required view over
`scheduler_job_expectations` and `cron_job_log`.
This linked Supabase proof passed at
`output/release-evidence/scheduler-history-alerts/20260606T065024Z.log`, and
the updated scheduler Edge functions were deployed with inventory proof at
`output/release-evidence/scheduler-deployments/20260606T065218Z.log`.
The admin-only operations snapshot RPC is also deployed and verified at
`output/release-evidence/operations-observability-snapshot/20260606T061251Z.log`.
Scheduler provider history, missed-run alert proof, observability dashboards,
alert routes, incident evidence, rollback evidence, and owner signoff are still
required before launch approval.

Structured evidence must be recorded in
`release/operations/operations-readiness-evidence.json` and validated with:

```bash
node tool/validate_operations_readiness_evidence.mjs
```

The validator is intentionally fail-closed. It must not pass until all required
scheduler jobs, observability surfaces, alert routes, monitoring signals,
incident-readiness checks, and owner signoffs are present with redacted evidence
references.

The evidence file must also be bound to the release source commit, production
target URLs, tested Supabase project ref, evidence capture window, and durable
redacted evidence bundle roots for scheduler, observability, and incident
readiness evidence.

## Scheduler Evidence Required

Required jobs:

- `settle-match-pools`
- `dispatch-match-alerts`
- `sync-livescore-football`

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
- `sync-livescore-football-smoke.log`: output from
  `tool/run_supabase_cron_job.sh sync-livescore-football`.
- `scheduler-history-redacted.txt`: provider history showing recent successful
  runs for each job.
- `missed-run-alert-redacted.txt`: alert rule, destination, severity, and owner.
- `incident-routing-redacted.txt`: escalation channel and backup owner.

The same evidence references must be copied into the relevant `schedulerJobs`
entries in `release/operations/operations-readiness-evidence.json`.
Each scheduler entry must keep the expected smoke command:
`tool/run_supabase_cron_job.sh settle-match-pools` or
`tool/run_supabase_cron_job.sh dispatch-match-alerts` or
`tool/run_supabase_cron_job.sh sync-livescore-football`.

Current smoke evidence:

- `output/release-evidence/20260606T040524Z/scheduler_payload_smoke.log`
- `release/operations/cron-smoke-evidence-20260606T043304Z.json`
- `release/operations/scheduler-workflow-code-evidence.json`
- `release/operations/scheduler-platform-cron-manifest.json`
- `release/operations/scheduler-provider-state-evidence.json`
- `output/release-evidence/scheduler-workflow-code/20260606T062319Z.json`
- `node tool/validate_cron_smoke_evidence.mjs`
- `node tool/validate_scheduler_platform_manifest.mjs`
- `node tool/capture_scheduler_provider_state.mjs`
- `node tool/validate_scheduler_provider_state_evidence.mjs`
- `node tool/validate_scheduler_workflow_code_evidence.mjs`

These prove the cron endpoints respond correctly with redacted credential
handling and that scheduled workflow controls are wired, but they do not replace
provider run history, missed-run alerts, or operator signoff.

Run locally only after `SUPABASE_URL` and `CRON_SECRET` are available in the
environment or ignored `.env`:

```bash
tool/run_supabase_cron_job.sh settle-match-pools
tool/run_supabase_cron_job.sh dispatch-match-alerts
tool/run_supabase_cron_job.sh sync-livescore-football
```

After scheduler Edge deployments, run the audit-aware smoke to prove the
deployed functions are writing database-backed `cron_job_log` run ids:

```bash
CRON_SECRET=... node tool/scheduler_post_deploy_audit_smoke.mjs
node tool/validate_scheduler_post_deploy_audit_smoke.mjs \
  output/release-evidence/scheduler-post-deploy-smoke/<timestamp>.json
```

Use a process-local `CRON_SECRET`, `EDGE_SERVICE_ROLE_KEY`, or
`SUPABASE_SERVICE_ROLE_KEY`; do not write the value to tracked files or evidence.
The current credentialed post-deploy audit smoke passed at
`release/operations/scheduler-post-deploy-audit-smoke-evidence.json`, with the
generated copy stored at
`output/release-evidence/scheduler-post-deploy-smoke/20260606T070551Z.json`.

`CRON_SECRET` is the production scheduler credential. For a controlled operator
smoke where the scheduler secret exists in Supabase but is not readable locally,
the same script can use `EDGE_SERVICE_ROLE_KEY` or `SUPABASE_SERVICE_ROLE_KEY`
as a bearer credential. Do not place either key in tracked evidence; the smoke
log must stay redacted and only show HTTP status plus non-secret response body.

Then rerun the aggregate collector:

```bash
FANZONE_WEBSITE_URL=https://fanzone.ikanisa.com \
FANZONE_ADMIN_URL=https://fanzoneadmin.ikanisa.com \
FANZONE_VENUE_PORTAL_URL=https://fanzone.venue.ikanisa.com \
FANZONE_TV_DISPLAY_URL=https://fanzonetv.ikanisa.com \
tool/collect_world_class_evidence.sh
```

The aggregate collector fails by default if any required evidence remains
`PENDING` or `FAIL`. Use `tool/collect_world_class_evidence.sh --allow-pending`
only when creating an inventory snapshot during remediation; that output is not
launch approval evidence.

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

The same evidence references must be copied into the relevant
`observabilitySurfaces` and `observabilitySignals` entries in
`release/operations/operations-readiness-evidence.json`.

## Code-Owned Telemetry Hardening

The Flutter app captures framework, platform, and runtime telemetry through
`AppTelemetry` and queues it locally before flushing to
`log_app_runtime_errors_batch`. Product analytics uses
`log_product_events_batch` only after a user session exists.

The repository-owned hardening proof is:

```bash
node tool/validate_observability_telemetry_code_evidence.mjs
tool/supabase_observability_telemetry_hardening.sh
```

The validator checks `release/operations/observability-telemetry-code-evidence.json`,
the append-only migration, SQL readiness test, Flutter telemetry wiring, and
release gate integration. The SQL runner passed against the linked project at
`output/release-evidence/observability-telemetry-hardening/20260606T060909Z.log`.
This proves RPC/grant hardening, bounded payloads, token-like value redaction in
top-level telemetry fields and nested metadata/properties, safe timestamp
parsing, and runtime event metadata storage.

This code-owned proof does not replace provider dashboard evidence, alert-route
testing, scheduler history, post-deploy watch evidence, or owner signoff.

## Admin Operations Snapshot

The code-owned dashboard data plane is:

```bash
node tool/validate_operations_observability_snapshot_evidence.mjs
tool/supabase_operations_observability_snapshot.sh
```

The deployed `admin_operations_observability_snapshot()` RPC is admin-only and
returns aggregate JSON for runtime errors, product events, ordering, manual
payments, FET ledger activity, pools, staff calls, push notifications, database
activity, and LiveScore scheduler freshness. It does not expose raw telemetry,
order, payment, or ledger rows to client roles.

This proof gives operators a real Supabase-backed dashboard contract. It still
does not replace provider dashboard screenshots/exports, alert-route test
evidence, scheduler provider history, missed-run alerts, or owner signoff.

## PASS Criteria

Do not mark `Scheduler and cron monitoring` or `Production observability and
alerting` as `PASS` in `docs/release/world-class-evidence-matrix.md` until:

- all cron smoke commands pass against the production target;
- provider scheduler history proves recent successful runs;
- evidence is tied to the release source commit, production URLs, tested
  Supabase project ref, and evidence capture window;
- missed-run alerts are configured and tested;
- telemetry and dashboards cover all launch surfaces;
- alert routing has named primary and backup owners;
- the post-deploy watch plan is reviewed and assigned.
