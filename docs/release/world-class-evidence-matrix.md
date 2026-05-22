# FANZONE World-Class Evidence Matrix

Last updated: 2026-05-21

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
| Credential rotation and secret inventory | PENDING | PENDING | PENDING | PENDING | `release/security/secret-rotation-evidence.json`; `tool/validate_secret_rotation_evidence.mjs`; `docs/secret-rotation-runbook.md`; provider rotation and old-key revocation evidence required |
| Tracked and full-history secret scanning | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/full_history_secret_scan.sh` passed |
| Repo-local quality gates | PASS | PASS | PASS | PASS | 2026-05-21 local gates passed: `npm run typecheck`; `npm run lint`; `npm run test --workspaces --if-present`; `npm run build`; Flutter analyze/test and Pixel smoke passed; release still requires clean-worktree `tool/go_live_readiness.sh --local` |
| Production Supabase RLS/RPC authorization | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/supabase_live_validation.sh` passed |
| Production backup and restore point | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; backup manifest `output/release-evidence/20260521T094051Z/backup/backup-manifest.txt`; restore list `output/release-evidence/20260521T094051Z/backup/restore-list.txt` |
| Production client env secret isolation | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/verify_production_envs.sh .env.production` passed |
| World-class benchmark completion | PENDING | PENDING | PENDING | PENDING | This matrix must be 100% PASS for all applicable P0/P1 controls |

## P1 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Deployed BFF/runtime verification | N/A | PASS | PASS | N/A | `output/release-evidence/20260521T094013Z/summary.txt`; `release/web/venue-portal-web-perf-readiness-2026-05-21.md`; `release/web/admin-web-perf-readiness-2026-05-21.md`; admin `https://fanzoneadmin.ikanisa.com`; venue `https://fanzone.venue.ikanisa.com`; `/api/health` and unauthenticated session smoke passed |
| Deployed CORS and security headers | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `release/web/venue-portal-web-perf-readiness-2026-05-21.md`; `release/web/admin-web-perf-readiness-2026-05-21.md`; `release/web/tv-display-web-perf-readiness-2026-05-21.md`; website `https://fanzone.ikanisa.com`; admin `https://fanzoneadmin.ikanisa.com`; venue `https://fanzone.venue.ikanisa.com`; TV `https://fanzonetv.ikanisa.com` |
| Scheduler and cron monitoring | PENDING | PENDING | PENDING | PENDING | `output/release-evidence/20260521T094013Z/summary.txt` shows cron smoke pending because `CRON_SECRET` is missing; `docs/operations/scheduler-observability.md`; scheduler history and alert evidence required |
| Android release artifact | PARTIAL | N/A | N/A | N/A | `release/qa/flutter-client-production-readiness-2026-05-21.md`; existing May 18 AAB SHA-256 `c403f29c0ee40e80859ddfa7a9d23602b4e09ff47009001a9acb8efe20dda094`; existing May 18 APK SHA-256 `fcccb0ed949ed4ab8d5ba7b6d4776ad49fdcab154db31949fd72a5e8de88dd55`; `jarsigner -verify` passed; 2026-05-21 fresh Android rebuild stalled and must be rerun on a clean build host |
| iOS archive/TestFlight readiness | PARTIAL | N/A | N/A | N/A | `release/ios/testflight-readiness.json`; `release/qa/flutter-client-production-readiness-2026-05-21.md`; production config and Firebase plist pass, but signed archive, IPA export, physical iPhone install, push smoke, and App Store Connect/TestFlight evidence remain required |
| Critical user-flow UAT | PENDING | PENDING | PENDING | PENDING | `release/qa/critical-user-flow-uat.json`; `tool/validate_critical_uat_signoff.mjs`; signed UAT for auth, ordering, payments, wallet, pools, rewards, admin, TV, realtime, and backend isolation flows |
| Production observability and alerting | PENDING | PENDING | PENDING | PENDING | `docs/operations/scheduler-observability.md`; `tool/collect_world_class_evidence.sh`; Sentry/equivalent, dashboards, alert routes, and post-deploy watch evidence required |
| Incident response and rollback readiness | PENDING | PENDING | PENDING | PENDING | Incident owner, escalation channel, rollback tag, DB restore plan, runbook review required |

## P2 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Dependency update automation | PASS | PASS | PASS | PASS | `.github/dependabot.yml` |
| MASVS-style mobile security review | PARTIAL | N/A | N/A | N/A | `tool/mobile_release_static_audit.sh`; static repo checks pass, but real-device security review and crash-reporting evidence remain required |
| API authorization abuse tests | PENDING | PENDING | PENDING | PENDING | Negative cross-user, cross-venue, and admin-role tests required |
| Load and reliability smoke | PENDING | PENDING | PENDING | PENDING | Latency/error-budget/load-smoke evidence required |
| Privacy/legal review | PENDING | PENDING | PENDING | PENDING | Retention, deletion, export, support access, and public policy evidence required |
