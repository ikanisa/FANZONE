# FANZONE World-Class Evidence Matrix

Last updated: 2026-05-16

This is the release evidence matrix for the Flutter app, bars/venue PWA, admin
PWA, and TV PWA. `PASS` requires a concrete evidence reference. `PENDING`,
`PARTIAL`, `WAIVED`, or an empty evidence reference means FANZONE remains
`NO-GO`.

Allowed statuses:

- `PASS`: evidence is captured and reviewed.
- `PENDING`: evidence is not yet captured.
- `PARTIAL`: evidence exists but does not cover the full control.
- `N/A`: control is not applicable and has release-owner justification.
- `WAIVED`: exception approved by the release owner. Waivers are not allowed for
  P0 or P1 launch controls.

## P0 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Credential rotation and secret inventory | PENDING | PENDING | PENDING | PENDING | `docs/secret-rotation-runbook.md`; provider rotation evidence required |
| Tracked and full-history secret scanning | PASS | PASS | PASS | PASS | `tool/full_history_secret_scan.sh`; `tool/go_live_readiness.sh --local` |
| Repo-local quality gates | PASS | PASS | PASS | PASS | `tool/go_live_readiness.sh --local` |
| Production Supabase RLS/RPC authorization | PENDING | PENDING | PENDING | PENDING | `tool/supabase_live_validation.sh` against release target required |
| Production backup and restore point | PENDING | PENDING | PENDING | PENDING | `tool/create_supabase_backup_evidence.sh`; backup timestamp and rollback evidence required |
| Production client env secret isolation | PENDING | PENDING | PENDING | PENDING | `tool/verify_production_envs.sh .env.production`; web env validation per surface |
| World-class benchmark completion | PENDING | PENDING | PENDING | PENDING | This matrix must be 100% PASS for all applicable P0/P1 controls |

## P1 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Deployed BFF/runtime verification | N/A | PENDING | PENDING | N/A | `tool/verify_deployed_web_surface.sh admin <url>`; `tool/verify_deployed_web_surface.sh venue-portal <url>`; login/refresh/logout smoke required |
| Deployed CORS and security headers | PENDING | PENDING | PENDING | PENDING | `tool/verify_deployed_web_surface.sh <surface> <url>` for every production origin required |
| Scheduler and cron monitoring | PENDING | PENDING | PENDING | PENDING | `tool/run_supabase_cron_job.sh settle-match-pools`; `tool/run_supabase_cron_job.sh dispatch-match-alerts`; scheduler history and alert evidence required |
| Android release artifact | PENDING | N/A | N/A | N/A | Signed AAB/APK, Play signing, install, production env, and deep-link smoke required |
| iOS archive/TestFlight readiness | PENDING | N/A | N/A | N/A | Signed/no-codesign archive, bundle ID, APS, and TestFlight/App Store Connect evidence required |
| Critical user-flow UAT | PENDING | PENDING | PENDING | PENDING | Signed UAT for auth, ordering, payments, wallet, pools, rewards, admin, and TV flows |
| Production observability and alerting | PENDING | PENDING | PENDING | PENDING | `tool/collect_world_class_evidence.sh`; Sentry/equivalent, dashboards, alert routes, and post-deploy watch evidence required |
| Incident response and rollback readiness | PENDING | PENDING | PENDING | PENDING | Incident owner, escalation channel, rollback tag, DB restore plan, runbook review required |

## P2 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Dependency update automation | PASS | PASS | PASS | PASS | `.github/dependabot.yml` |
| MASVS-style mobile security review | PENDING | N/A | N/A | N/A | Secure storage, network, permissions, privacy, logging, crash handling review required |
| API authorization abuse tests | PENDING | PENDING | PENDING | PENDING | Negative cross-user, cross-venue, and admin-role tests required |
| Load and reliability smoke | PENDING | PENDING | PENDING | PENDING | Latency/error-budget/load-smoke evidence required |
| Privacy/legal review | PENDING | PENDING | PENDING | PENDING | Retention, deletion, export, support access, and public policy evidence required |
