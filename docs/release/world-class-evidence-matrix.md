# FANZONE World-Class Evidence Matrix

Last updated: 2026-06-02

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
| Credential rotation and secret inventory | PENDING | PENDING | PENDING | PENDING | `release/security/secret-rotation-evidence.json`; `tool/validate_secret_rotation_evidence.mjs`; `docs/secret-rotation-runbook.md`; source-commit-bound provider rotation, old-key revocation, rotation window, redacted evidence bundle, post-rotation smoke, and owner signoff evidence required |
| Tracked and full-history secret scanning | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/full_history_secret_scan.sh` passed |
| Repo-local quality gates | PASS | PASS | PASS | PASS | 2026-06-02 clean checkout at `7cc4e3e`: `./tool/go_live_readiness.sh --local` passed; see `docs/release/go-live-current-state-2026-06-02.md` |
| Production Supabase RLS/RPC authorization | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/supabase_live_validation.sh` passed |
| Production backup and restore point | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; backup manifest `output/release-evidence/20260521T094051Z/backup/backup-manifest.txt`; restore list `output/release-evidence/20260521T094051Z/backup/restore-list.txt` |
| Production client env secret isolation | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `tool/verify_production_envs.sh .env.production` passed |
| World-class benchmark completion | PENDING | PENDING | PENDING | PENDING | This matrix must be 100% PASS for all applicable P0/P1 controls |

## P1 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Deployed BFF/runtime verification | N/A | PASS | PASS | N/A | `output/release-evidence/20260521T094013Z/summary.txt`; `release/web/venue-portal-web-perf-readiness-2026-05-21.md`; `release/web/admin-web-perf-readiness-2026-05-21.md`; admin `https://fanzoneadmin.ikanisa.com`; venue `https://fanzone.venue.ikanisa.com`; `/api/health` and unauthenticated session smoke passed |
| Deployed CORS and security headers | PASS | PASS | PASS | PASS | `output/release-evidence/20260521T094013Z/summary.txt`; `release/web/venue-portal-web-perf-readiness-2026-05-21.md`; `release/web/admin-web-perf-readiness-2026-05-21.md`; `release/web/tv-display-web-perf-readiness-2026-05-21.md`; website `https://fanzone.ikanisa.com`; admin `https://fanzoneadmin.ikanisa.com`; venue `https://fanzone.venue.ikanisa.com`; TV `https://fanzonetv.ikanisa.com` |
| Scheduler and cron monitoring | PENDING | PENDING | PENDING | PENDING | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; `output/release-evidence/20260521T094013Z/summary.txt` shows cron smoke pending because `CRON_SECRET` is missing; `docs/operations/scheduler-observability.md`; source-commit-bound scheduler command, history, smoke, missed-run alert, target environment, evidence window, and owner evidence required |
| Android release artifact | PARTIAL | N/A | N/A | N/A | `release/android/android-release-readiness.json`; `node tool/validate_android_release_evidence.mjs`; `release/qa/flutter-client-production-readiness-2026-05-21.md`; fresh signed AAB/APK, signature verification, artifact freshness, physical-device install/deep-link/core-flow smoke, and Google Play internal-test evidence required |
| iOS archive/TestFlight readiness | PARTIAL | N/A | N/A | N/A | `release/ios/testflight-readiness.json`; `node tool/validate_ios_testflight_evidence.mjs`; `release/qa/flutter-client-production-readiness-2026-05-21.md`; production config and Firebase plist pass, but source-commit-bound signed archive, signed IPA, artifact hashes, physical iPhone install, push smoke, App Store Connect build status, TestFlight, export compliance, test information, and App Review metadata evidence remain required |
| Critical user-flow UAT | PENDING | PENDING | PENDING | PENDING | `release/qa/critical-user-flow-uat.json`; `tool/validate_critical_uat_signoff.mjs`; source-commit-bound signed UAT for the exact required Flutter, venue, admin, TV, realtime, and backend isolation flow IDs; target URLs, Supabase project ref, test window, evidence bundle root, tester/timestamp, and PASS evidence refs required |
| Production observability and alerting | PENDING | PENDING | PENDING | PENDING | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; `docs/operations/scheduler-observability.md`; `tool/collect_world_class_evidence.sh`; source-commit-bound Sentry/equivalent, dashboards, alert routes, evidence window, evidence bundle, and post-deploy watch evidence required |
| Incident response and rollback readiness | PENDING | PENDING | PENDING | PENDING | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; source-commit-bound incident owner, escalation channel, rollback tag, DB restore plan, runbook review, post-deploy watch, sample alert test, and incident evidence bundle required |

## P2 Evidence Matrix

| Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence |
| --- | --- | --- | --- | --- | --- |
| Dependency update automation | PASS | PASS | PASS | PASS | `.github/dependabot.yml` |
| MASVS-style mobile security review | PARTIAL | N/A | N/A | N/A | `tool/mobile_release_static_audit.sh`; static repo checks pass, but real-device security review and crash-reporting evidence remain required |
| API authorization abuse tests | PARTIAL | PARTIAL | PARTIAL | PARTIAL | `tool/supabase_api_authorization_abuse_tests.sh`; existing RLS audit and Hospitality Core Phase 2 contracts cover negative client grants, restricted functions, cross-venue staff/order/reconciliation/staff-call access, customer mutation rejection, direct table mutation denial, unsupported payment rejection, and admin-only surface checks; requires release-target `--contract` evidence before `PASS` |
| Load and reliability smoke | PENDING | PENDING | PENDING | PENDING | `release/performance/load-reliability-evidence.json`; `node tool/validate_load_reliability_evidence.mjs`; source-commit-bound release-target ordering, staff calls, FET ledger, rewards, entertainment, admin queues, TV recovery, realtime, Edge Function error-budget, RLS-under-load, threshold, rollback, evidence bundle, and owner signoff evidence required |
| Privacy/legal review | PENDING | PENDING | PENDING | PENDING | `release/legal/privacy-legal-readiness-evidence.json`; `node tool/validate_privacy_legal_readiness_evidence.mjs`; retention, deletion, export, support access, public policy URL, Google Play Data Safety, Apple privacy labels, and human legal review evidence required |
