# FANZONE Production Go-Live Task Register

Last updated: 2026-05-16

This register turns the production-readiness findings into launch tasks with
required evidence. FANZONE must remain `NO-GO` until every P0 and P1 task is
complete with evidence. The platform must also satisfy the world-class benchmark
in `docs/release/world-class-production-benchmark.md` across the Flutter app,
bars/venue PWA, admin PWA, and TV PWA.

## P0 Launch Blockers

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P0-01 | Rotate every exposed or chat-shared Supabase anon key, service-role key, DB password/connection string, Supabase PAT, CI secret, deployment provider variable, and local operator env copy. | Release owner | Provider screenshots or export showing new creation/rotation timestamps, plus confirmation old values no longer work. | `docs/secret-rotation-runbook.md` |
| P0-02 | Re-run secret scans after rotation, including tracked-file regex scan, repo-owned full-history scan, and external `gitleaks` or `trufflehog` evidence where available. | Security owner | Clean scan logs stored outside git or in redacted release evidence. | `tool/go_live_readiness.sh --local`; `tool/full_history_secret_scan.sh`; external scanner output |
| P0-03 | Prove Flutter release gate is green. | Mobile owner | Passing `flutter analyze` and full `flutter test` logs. | `flutter analyze`; `flutter test` |
| P0-04 | Prove web/admin/venue/TV workspaces are green. | Web owner | Passing typecheck, lint, test, and production build logs. | `npm run typecheck --workspaces --if-present`; `npm run lint --workspaces --if-present`; `npm run test --workspaces --if-present`; `npm run build --workspaces --if-present` |
| P0-05 | Prove Supabase Edge Functions and SQL authorization are release-target clean. | Backend owner | Deno test logs, deployed function versions, target project ref, RLS/grant audit output, FET supply smoke output. | `deno test --allow-env supabase/functions`; `tool/supabase_live_validation.sh` |
| P0-06 | Back up production database and record restore point before release. | Backend owner | Backup timestamp, restore point, owner approval, rollback decision path. | `docs/release/rollback.md` |
| P0-07 | Verify production client envs never expose service-role or backend secrets. | Release owner | Passing release env validation for mobile and web env files without printing values. | `tool/validate_release_env.sh production --client`; `tool/validate_web_release_env.sh website`; repeat for admin/venue/TV envs |
| P0-08 | Complete the world-class benchmark across Flutter app, bars/venue PWA, admin PWA, and TV PWA. | Release owner | 100% PASS evidence for every applicable row and surface; no P0/P1 waivers. | `docs/release/world-class-production-benchmark.md` |

## P1 Deployment Readiness

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P1-01 | Verify Cloudflare Pages BFF runtime variables for admin and venue portal. | Web owner | Deployed admin/venue login, refresh, logout, Supabase REST/RPC, and Edge Function smoke logs. | `docs/release/deployment-readme.md` |
| P1-02 | Verify deployed CORS and headers for website, admin, venue portal, and TV origins. | Web owner | `curl -I` output for each origin and browser smoke evidence. | `FANZONE_EDGE_ALLOWED_ORIGINS`; `FANZONE_EDGE_ALLOW_WILDCARD_CORS=false` |
| P1-03 | Prove production cron/scheduler jobs are active and monitored. | Operations owner | Scheduler history, missed-run alert configuration, incident owner, and successful smoke run. | `tool/run_supabase_cron_job.sh settle-match-pools`; `tool/run_supabase_cron_job.sh dispatch-match-alerts` |
| P1-04 | Prove Android release artifact is signed, installable, and uses production env. | Mobile owner | AAB/APK build log, Play signing evidence, device smoke, deep-link smoke. | `tool/build_android_aab_from_env.sh production` |
| P1-05 | Prove iOS archive/TestFlight readiness. | Mobile owner | No-codesign archive or signed archive log, bundle ID, APS environment, TestFlight or App Store Connect evidence. | `tool/build_ios_release_from_env.sh production` |
| P1-06 | Complete critical user-flow UAT. | QA owner | Evidence for anonymous session, WhatsApp OTP upgrade, wallet, ordering, MoMo/Revolut external handoff, "I paid", staff confirmation, pools, rewards, and admin moderation. | `docs/release/go-live-checklist.md` |
| P1-07 | Verify production observability. | Operations owner | Sentry or equivalent DSNs configured, alert routes, dashboard links, and post-deploy watch schedule. | `SENTRY_DSN`; provider dashboard evidence |
| P1-08 | Verify incident response and rollback readiness. | Release owner | Named incident owner, escalation channel, reviewed runbooks, rollback tag, database restore plan. | `docs/operations/incident-runbooks.md`; `docs/release/rollback.md` |

## P2 Hardening Before Scale

| ID | Task | Owner | Evidence required | Repo command or artifact |
| --- | --- | --- | --- | --- |
| P2-01 | Add dependency update automation and scheduled vulnerability reporting. | Security owner | Enabled provider workflow or bot configuration. | GitHub Dependabot or equivalent |
| P2-02 | Run mobile MASVS-style review for local storage, network, platform permissions, privacy, and resilience. | Security owner | Findings and remediations tracked before broad public scale. | `pubspec.yaml`; `android/`; `ios/`; secure-storage code |
| P2-03 | Run API authorization abuse tests for object-level and function-level access. | Backend owner | Negative tests for cross-venue, cross-user, and unauthorized admin access. | Supabase SQL/RLS tests and Edge Function auth tests |
| P2-04 | Run load and reliability smoke on ordering, wallet ledger, pools, and admin queues. | Operations owner | Load-test summary, latency/error budget, rollback threshold. | External load-test evidence |
| P2-05 | Complete privacy/legal review for retention, deletion, data export, and support access. | Compliance owner | Approved policy links, retention schedule, support access procedure. | Public policy URLs and admin audit logs |

## Launch Decision Rule

Launch only when:

- all P0 and P1 tasks are complete with evidence;
- the world-class benchmark is 100% PASS for Flutter app, bars/venue PWA, admin PWA, and TV PWA;
- `tool/go_live_readiness.sh --local` passes on a clean checkout;
- production credentials are rotated and stored only in approved secret stores;
- production backup, rollback, monitoring, and incident ownership are proven.
