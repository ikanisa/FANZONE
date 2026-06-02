# FANZONE Production Go-Live Task Register

Last updated: 2026-06-02

This register turns the production-readiness findings into launch tasks with
required evidence. FANZONE must remain `NO-GO` until every P0 and P1 task is
complete with evidence. The platform must also satisfy the world-class benchmark
in `docs/release/world-class-production-benchmark.md` across the Flutter app,
bars/venue PWA, admin PWA, and TV PWA.

## P0 Launch Blockers

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P0-01 | Rotate every exposed or chat-shared Supabase anon key, service-role key, DB password/connection string, Supabase PAT, CI secret, deployment provider variable, and local operator env copy. | Release owner | Source commit, rotation window, redacted evidence bundle root, provider screenshots or export showing new creation/rotation timestamps, confirmation old values no longer work, post-rotation smoke refs, and release/security-owner signoff. | `release/security/secret-rotation-evidence.json`; `node tool/validate_secret_rotation_evidence.mjs`; `docs/secret-rotation-runbook.md` |
| P0-02 | Re-run secret scans after rotation, including tracked-file regex scan, repo-owned full-history scan, and external `gitleaks` or `trufflehog` evidence where available. | Security owner | Clean scan logs stored outside git or in redacted release evidence. | `tool/go_live_readiness.sh --local`; `tool/full_history_secret_scan.sh`; external scanner output |
| P0-03 | Prove Flutter release gate is green. | Mobile owner | 2026-06-02 local gate at `7cc4e3e` passed `flutter analyze` and `flutter test` with 249 tests; keep release-candidate rerun evidence for final signoff. | `docs/release/go-live-current-state-2026-06-02.md`; `flutter analyze`; `flutter test` |
| P0-04 | Prove web/admin/venue/TV workspaces are green. | Web owner | 2026-06-02 local gate at `7cc4e3e` passed workspace typecheck, lint, test, and build; keep release-candidate rerun evidence for final signoff. | `docs/release/go-live-current-state-2026-06-02.md`; `npm run typecheck --workspaces --if-present`; `npm run lint --workspaces --if-present`; `npm run test --workspaces --if-present`; `npm run build --workspaces --if-present` |
| P0-05 | Prove Supabase Edge Functions and SQL authorization are release-target clean. | Backend owner | Deno test logs, deployed function versions, target project ref, RLS/grant audit output, FET supply smoke output, and Hospitality Core Phase 2 readiness/contract output after migrations are applied. | `deno test --allow-env supabase/functions`; `tool/supabase_live_validation.sh`; `tool/supabase_hospitality_core_phase2.sh --readiness`; `tool/supabase_hospitality_core_phase2.sh --contract` |
| P0-06 | Back up production database and record restore point before release. | Backend owner | Backup timestamp, restore point, owner approval, rollback decision path. | `tool/create_supabase_backup_evidence.sh`; `docs/release/rollback.md` |
| P0-07 | Verify production client envs never expose service-role or backend secrets. | Release owner | Passing release env validation for mobile and web env files without printing values. | `tool/verify_production_envs.sh .env.production` |
| P0-08 | Complete the world-class benchmark across Flutter app, bars/venue PWA, admin PWA, and TV PWA. | Release owner | 100% PASS evidence for every applicable row and surface; no P0/P1 waivers. | `docs/release/world-class-production-benchmark.md`; `docs/release/world-class-evidence-matrix.md`; `tool/check_world_class_evidence.sh` |

## P1 Deployment Readiness

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P1-01 | Verify Cloudflare Pages BFF runtime variables for admin and venue portal. | Web owner | Deployed admin/venue login, refresh, logout, Supabase REST/RPC, and Edge Function smoke logs. | `tool/verify_deployed_web_surface.sh admin <url>`; `tool/verify_deployed_web_surface.sh venue-portal <url>`; `docs/release/deployment-readme.md` |
| P1-02 | Verify deployed CORS and headers for website, admin, venue portal, and TV origins. | Web owner | `curl -I` output for each origin and browser smoke evidence. | `tool/verify_deployed_web_surface.sh <surface> <url>`; `FANZONE_EDGE_ALLOWED_ORIGINS`; `FANZONE_EDGE_ALLOW_WILDCARD_CORS=false` |
| P1-03 | Prove production cron/scheduler jobs are active and monitored. | Operations owner | Source commit, production target metadata, evidence capture window, scheduler evidence bundle, expected cron command, scheduler history, missed-run alert configuration, incident owner, and successful smoke run. | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; `tool/run_supabase_cron_job.sh settle-match-pools`; `tool/run_supabase_cron_job.sh dispatch-match-alerts` |
| P1-04 | Prove Android release artifact is signed, installable, fresh for the release commit, and uses production env. | Mobile owner | AAB/APK build logs, SHA-256 hashes, size, build timestamp, upload/app signing evidence, signature verification, physical-device install smoke, deep-link smoke, core-flow smoke, Play internal-test evidence, and reviewer metadata evidence. | `release/android/android-release-readiness.json`; `node tool/validate_android_release_evidence.mjs`; `tool/preflight_build_check.sh production`; `tool/build_android_aab_from_env.sh production`; `tool/build_android_release_from_env.sh production` |
| P1-05 | Prove iOS archive/TestFlight readiness for the release commit. | Mobile owner | Production config, signed archive log, signed IPA export, artifact hashes and timestamps, physical iPhone install, push smoke, App Store Connect build processing/status, TestFlight internal or external testing evidence, export compliance, beta test information, and App Review metadata. | `release/ios/testflight-readiness.json`; `node tool/validate_ios_testflight_evidence.mjs`; `tool/build_ios_release_from_env.sh production` |
| P1-06 | Complete critical user-flow UAT. | QA owner | Source commit, release candidate, target URLs, tested Supabase project ref, test window, evidence bundle root, QA/release-owner signoff, and PASS evidence for anonymous session, WhatsApp OTP upgrade, rewards ledger, table-number ordering, MoMo/Revolut external handoff, "I paid", staff confirmation, staff-call acknowledgement, daily-close reconciliation, free-to-play entertainment, rewards, admin moderation, TV live display, realtime propagation, and backend isolation. | `release/qa/critical-user-flow-uat.json`; `node tool/validate_critical_uat_signoff.mjs`; `docs/release/go-live-checklist.md` |
| P1-07 | Verify production observability. | Operations owner | Source commit, production target metadata, evidence capture window, observability evidence bundle, Sentry or equivalent DSNs configured, alert routes, dashboard links, monitored launch signals, sample alert test, and post-deploy watch schedule. | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; `tool/collect_world_class_evidence.sh`; `SENTRY_DSN`; provider dashboard evidence |
| P1-08 | Verify incident response and rollback readiness. | Release owner | Source commit, production target metadata, evidence capture window, incident-readiness evidence bundle, named incident owner, escalation channel, reviewed runbooks, rollback tag, database restore plan, post-deploy watch owner, and sample alert test. | `release/operations/operations-readiness-evidence.json`; `node tool/validate_operations_readiness_evidence.mjs`; `docs/operations/incident-runbooks.md`; `docs/release/rollback.md` |

## P2 Hardening Before Scale

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P2-01 | Add dependency update automation and scheduled vulnerability reporting. | Security owner | Enabled provider workflow or bot configuration. | GitHub Dependabot or equivalent |
| P2-02 | Run mobile MASVS-style review for local storage, network, platform permissions, privacy, and resilience. | Security owner | Static repo audit plus findings and remediations tracked before broad public scale; real-device and crash-reporting evidence still required before marking complete. | `tool/mobile_release_static_audit.sh`; `pubspec.yaml`; `android/`; `ios/`; secure-storage code |
| P2-03 | Run API authorization abuse tests for object-level and function-level access. | Backend owner | 2026-06-02 repo now has a single entrypoint that composes the RLS audit and rollback-based Hospitality Core Phase 2 contracts; release-target evidence still requires a `--contract` run and Edge Function auth-abuse evidence. | `tool/supabase_api_authorization_abuse_tests.sh --contract`; Supabase SQL/RLS tests; Edge Function auth tests |
| P2-04 | Run load and reliability smoke on ordering, FET rewards ledger, free-to-play entertainment, staff-call acknowledgement, admin queues, TV recovery, realtime propagation, Edge Functions, and RLS-under-load behavior. | Operations owner | Source commit, production target URLs, tested Supabase project ref, test window, durable evidence bundle root, load-test summary, scenario-level latency/error budget, sample sizes, rollback thresholds, and owner signoff. | `release/performance/load-reliability-evidence.json`; `node tool/validate_load_reliability_evidence.mjs`; external load-test evidence |
| P2-05 | Complete privacy/legal review for retention, deletion, data export, and support access. | Compliance owner | Approved policy links, retention schedule, deletion/export procedure, support access procedure, Google Play Data Safety confirmation, Apple privacy label confirmation, and legal/compliance signoff. | `release/legal/privacy-legal-readiness-evidence.json`; `node tool/validate_privacy_legal_readiness_evidence.mjs`; public policy URLs; admin audit logs |

## Launch Decision Rule

Launch only when:

- all P0 and P1 tasks are complete with evidence;
- the world-class benchmark is 100% PASS for Flutter app, bars/venue PWA, admin PWA, and TV PWA;
- `tool/check_world_class_evidence.sh` passes;
- `tool/go_live_readiness.sh --local` passes on a clean checkout;
- production credentials are rotated and stored only in approved secret stores;
- production backup, rollback, monitoring, and incident ownership are proven.
