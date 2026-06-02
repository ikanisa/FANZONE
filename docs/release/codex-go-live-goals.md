# FANZONE Codex Go-Live Goal Pack

Date prepared: 2026-06-02  
Repository: `/Volumes/PRO-G40/FANZONE`  
Current basis: `5d0d348` on `main`  
Source report: `docs/FANZONE_HANDOVER_REPORT.md`  
Release posture at preparation time: `NO-GO`

## Purpose

This goal pack converts the FANZONE handover findings, release registers, and
current fail-closed validation results into executable Codex goals. Each goal is
written as a handoff packet that can be used in a future Codex run to implement
or prove the required readiness work.

The pack is deliberately evidence-first. A goal is not complete because code was
changed or a command was attempted. A goal is complete only when the acceptance
evidence named in that goal exists, validators pass, and the release evidence
matrix can honestly move closer to `PASS`.

## Current Blocker Summary

The following lightweight validators were run while preparing this goal pack:

```bash
./tool/check_world_class_evidence.sh
node tool/validate_secret_rotation_evidence.mjs
node tool/validate_critical_uat_signoff.mjs
node tool/validate_ios_testflight_evidence.mjs
```

Current fail-closed blockers:

| Area | Current result |
| --- | --- |
| Credential rotation and secret inventory | `PENDING` across all surfaces. |
| World-class benchmark completion | `PENDING`. |
| Scheduler and cron monitoring | `PENDING`. |
| Android release artifact | `PARTIAL`; fresh signed production build/install proof required. |
| iOS archive/TestFlight readiness | `PARTIAL`; signed archive, IPA, install, push, TestFlight, and review evidence required. |
| Critical user-flow UAT | `PENDING`; all flow rows require `PASS`. |
| Production observability and alerting | `PENDING`. |
| Incident response and rollback readiness | `PENDING`. |
| Secret rotation validator | Fails because every credential class and post-rotation check is pending. |
| Critical UAT validator | Fails because sign-off metadata and every critical flow are pending. |
| iOS validator | Fails because owner signoff and six required iOS checks are pending. |

## Operating Rules For All Goals

- Preserve FANZONE product boundaries: no betting, gambling, odds, wagering,
  cash-out, cash prizes, or fintech/stored-value wallet positioning.
- Keep FET as non-cash loyalty and rewards points.
- Keep customer payment execution off-platform unless a separate approved
  product decision and implementation plan exists.
- Work additively and preserve active Flutter, React/Vite, Supabase, docs, and
  release surfaces.
- Use append-only migrations for deployed schema changes.
- Do not expose service-role keys, DB URLs, provider secrets, signing files, or
  Firebase service files in tracked code or client configs.
- Keep release claims conservative: local green checks, linked Supabase proof,
  deployed proof, and provider proof are separate facts.
- Do not mark any goal complete while `docs/release/world-class-evidence-matrix.md`
  still contradicts the claimed state.

## Recommended Tooling By Goal Type

| Goal type | Recommended tools/plugins |
| --- | --- |
| Supabase migrations, RLS, RPCs, Edge Functions | Supabase plugin/MCP, Supabase CLI, `supabase/tests`, `tool/supabase_*`. |
| Web/PWA deployment and CORS | Cloudflare plugin/Wrangler, Browser/Chrome plugin for deployed smoke, `tool/verify_deployed_web_surface.sh`. |
| GitHub CI, Actions, secrets, dependency automation | GitHub plugin/CLI, `.github/workflows`, Dependabot. |
| iOS simulator/build/debug tasks | Build iOS Apps plugin/XcodeBuildMCP when available, `tool/build_ios_release_from_env.sh`. |
| Browser UAT and deployed visual proof | Browser or Chrome plugin, Playwright, screenshot evidence under `output/release-evidence/`. |
| Security review | Codex Security skills, OWASP ASVS, OWASP MASVS, OWASP API Security Top 10, repo scanners. |
| Documentation artifacts | Documents plugin for DOCX/Google Docs-targeted deliverables. |

External provider work may require credentials or dashboard access that Codex
does not have by default. In those cases, the goal must stop at a clear
approval/evidence boundary, produce redacted evidence templates, and never fake
provider proof.

## Goal Execution Order

1. Baseline freeze and evidence inventory.
2. Secret rotation and post-rotation proof.
3. Supabase migration and backend authorization proof.
4. Clean local go-live gate.
5. Web/PWA deployment and CORS proof.
6. Android release proof.
7. iOS/TestFlight proof.
8. Critical UAT signoff.
9. Scheduler, observability, incident, backup, and rollback proof.
10. Security, API abuse, privacy, accessibility, and reliability hardening.
11. Final evidence matrix closure and go/no-go report.

## Goal 00 - Freeze Baseline And Build Current Evidence Inventory

```text
/goal Establish the current FANZONE release baseline and create a complete evidence inventory for go-live execution. Verify the checkout is clean and synced to origin/main, record the release candidate commit/tag, map every P0/P1/P2 row from docs/release/production-go-live-task-register.md and docs/release/world-class-evidence-matrix.md to current evidence, rerun lightweight validators, and produce a dated current-state report under output/release-evidence/<timestamp>/baseline/ plus any necessary docs updates. Do not change product code except for evidence tooling defects found during validation.
```

Why this goal exists:

- The handover report originally saw a dirty tree; it is now committed, but
  go-live work must start from a clean, named release candidate.
- The evidence matrix contains older evidence from 2026-05-21 and must be
  refreshed against the current commit.

Scope:

- Confirm `git status --short` is clean.
- Confirm `git rev-list --left-right --count main...origin/main` is `0 0`.
- Create or identify the release candidate tag/commit.
- Run lightweight validators:
  - `./tool/check_world_class_evidence.sh`
  - `node tool/validate_secret_rotation_evidence.mjs`
  - `node tool/validate_critical_uat_signoff.mjs`
  - `node tool/validate_ios_testflight_evidence.mjs`
- Produce `output/release-evidence/<timestamp>/baseline/current-state.md`.

Acceptance:

- Current-state report lists every open blocker and every existing evidence
  reference.
- No `PASS` claim is made without command output or provider proof.

## Goal 01 - Rotate And Prove All Production Secrets

```text
/goal Complete FANZONE production credential rotation and prove post-rotation security. Rotate or obtain provider evidence for every credential class in release/security/secret-rotation-evidence.json, revoke old credentials, update approved secret stores only, rerun post-rotation scans and smokes, update the evidence JSON with redacted references, and make node tool/validate_secret_rotation_evidence.mjs pass. Do not print, commit, or expose secret values.
```

Why this goal exists:

- The handover identifies previously shared Supabase credentials as a release
  blocker.
- `node tool/validate_secret_rotation_evidence.mjs` currently fails for every
  credential class and post-rotation check.

Required tools:

- Supabase dashboard/CLI or Supabase plugin for Supabase keys and Edge secrets.
- Cloudflare dashboard/Wrangler or Cloudflare plugin for Pages/runtime secrets.
- GitHub plugin/CLI for CI/CD secrets.
- Local shell only for redacted scans and smoke checks.

Implementation scope:

- Rotate/prove:
  - `SUPABASE-ANON-KEY`
  - `SUPABASE-SERVICE-ROLE`
  - `SUPABASE-DB-CREDENTIALS`
  - `SUPABASE-PAT`
  - `CLOUDFLARE-RUNTIME-SECRETS`
  - `SUPABASE-EDGE-SECRETS`
  - `CI-CD-SECRETS`
  - `LOCAL-OPERATOR-SECRETS`
- Run:
  - `tool/full_history_secret_scan.sh`
  - `tool/verify_production_envs.sh .env.production`
  - `tool/supabase_live_validation.sh`
  - `tool/collect_world_class_evidence.sh`
- Update `release/security/secret-rotation-evidence.json`.

Acceptance:

- `node tool/validate_secret_rotation_evidence.mjs` passes.
- The P0 evidence matrix row for credential rotation can be updated to `PASS`
  with redacted provider and smoke references.

External blocker boundary:

- If provider access is unavailable, produce a redacted rotation request packet
  and leave the validator failing. Do not mark the goal complete.

## Goal 02 - Apply And Prove Hospitality Core Phase 2 On Live Supabase

```text
/goal Apply and prove the FANZONE Hospitality Core Phase 2 Supabase migrations on the release target. Confirm the target Supabase project, capture backup evidence, dry-run the pending migrations, apply them through the approved release process, deploy affected Edge Functions, rerun all readiness and rollback-contract checks, and update docs/release/hospitality-core-phase2-evidence.md with current dated live evidence.
```

Why this goal exists:

- The handover and Phase 2 evidence say live signoff requires applying and
  proving four ordered migrations.

Required migrations:

- `20260522150000_order_lifecycle_hardening.sql`
- `20260523120000_manual_payment_reconciliation.sql`
- `20260523130000_staff_call_acknowledgement_rpc.sql`
- `20260523140000_manual_payment_note_requirement.sql`

Required tools:

- Supabase plugin/MCP or Supabase CLI.
- SQL clients for direct DB checks.

Validation:

```bash
tool/create_supabase_backup_evidence.sh
supabase db push --dry-run --db-url "$SUPABASE_DB_URL"
supabase db push --db-url "$SUPABASE_DB_URL"
supabase functions deploy order_create
supabase functions deploy order_mark_paid
supabase functions deploy order_update_status
tool/supabase_hospitality_core_phase2.sh --readiness
tool/supabase_hospitality_core_phase2.sh --contract
tool/supabase_live_validation.sh
```

Acceptance:

- Live readiness and contract checks pass.
- Evidence covers valid/invalid order transitions, cross-venue rejection,
  customer read-only lifecycle visibility, manual payment audit rows,
  reconciliation access, unsupported card rejection, staff-call acknowledgement,
  and audit logging.

## Goal 03 - Close Backend Authorization And API Abuse Gaps

```text
/goal Complete FANZONE backend authorization hardening and API abuse coverage. Expand negative tests for cross-user, cross-venue, anonymous, role-escalation, direct table mutation, Edge Function auth, and RPC grants across ordering, staff calls, manual payments, rewards ledger, pools, games, admin, and TV-safe reads. Keep sensitive mutations routed through audited RPCs or Edge Functions and update release evidence when tests pass.
```

Why this goal exists:

- World-class benchmark requires authorization and object isolation across all
  surfaces.
- P2 evidence matrix has API authorization abuse tests as `PENDING`.

Required tools:

- Codex Security skills.
- Supabase tests and Edge Function tests.
- Supabase plugin/CLI for linked/live validation.

Validation:

```bash
./tool/product_boundary_scan.sh
./tool/supabase_rls_audit.sh
./tool/supabase_live_validation.sh
deno test --allow-env supabase/functions
psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql
```

Acceptance:

- Negative authorization tests exist and pass for every critical object class.
- No client path can directly mutate order lifecycle events, payment events,
  staff-call acknowledgements, ledger balances, settlement rows, or admin-only
  state.

## Goal 04 - Make The Clean Local Go-Live Gate Pass

```text
/goal Make ./tool/go_live_readiness.sh --local pass from a clean FANZONE checkout. Fix any code, test, lint, formatting, product-boundary, secret-scan, mobile-audit, Flutter, web workspace, Deno, or script-validation failures without weakening gates or hiding failures. Commit only evidence-backed fixes and leave provider-only blockers documented separately.
```

Why this goal exists:

- The launch rule requires the clean local go-live gate.

Validation:

```bash
./tool/go_live_readiness.sh --local
```

Acceptance:

- The command passes on a clean working tree.
- Any local evidence bundle references the exact commit.
- Provider-only blockers remain clearly separated.

## Goal 05 - Prove Web/PWA Deployments, BFF Runtime, CORS, Headers, And Metadata

```text
/goal Prove FANZONE website, admin PWA, venue portal PWA, and TV display PWA are production-deployed, metadata-clean, CORS-safe, and BFF-safe. Validate browser-safe envs, build and deploy all four surfaces, verify deployed headers and health routes, exercise admin/venue BFF session behavior, smoke TV read-only venue scoping, and update release evidence with URLs, command logs, and screenshots.
```

Why this goal exists:

- P1 deployed CORS and BFF evidence must be current for the release candidate.
- Admin and venue portal must use `VITE_PRIVILEGED_SESSION_MODE=bff` in
  production.

Required tools:

- Cloudflare plugin/Wrangler.
- Browser/Chrome plugin or Playwright for deployed smoke and screenshots.

Validation:

```bash
tool/validate_web_release_env.sh website
tool/validate_web_release_env.sh admin
tool/validate_web_release_env.sh venue-portal
tool/validate_web_release_env.sh tv-display
npm run typecheck --workspaces --if-present
npm run lint --workspaces --if-present
npm run test --workspaces --if-present
npm run build --workspaces --if-present
tool/deploy_cloudflare_pages.sh website venue-portal tv-display admin
tool/verify_deployed_web_surface.sh website https://fanzone.ikanisa.com
tool/verify_deployed_web_surface.sh admin https://fanzoneadmin.ikanisa.com
tool/verify_deployed_web_surface.sh venue-portal https://fanzone.venue.ikanisa.com
tool/verify_deployed_web_surface.sh tv-display https://fanzonetv.ikanisa.com
```

Acceptance:

- Production origins pass CORS/header checks.
- Admin and venue portal BFF health/session smokes pass.
- TV display remains read-only and venue-scoped.
- PWA metadata validators pass.

## Goal 06 - Produce Fresh Android Release Artifact And Play Evidence

```text
/goal Produce and prove a fresh FANZONE Android production release artifact for the current commit. Validate production env and signing config, build the signed AAB/APK, verify signatures and artifact freshness, install and smoke on a physical Android device, verify deep links and core flows, update Android release evidence and Play metadata, and resolve any product-copy or store-policy issues without changing FANZONE product boundaries.
```

Why this goal exists:

- Android release artifact is currently `PARTIAL`; old May artifacts are not
  enough for current go-live.

Required tools:

- Android SDK/Flutter toolchain.
- Physical Android device or approved device farm.
- Google Play Console access for internal testing proof.

Validation:

```bash
tool/preflight_build_check.sh production
flutter clean
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
tool/build_android_aab_from_env.sh production
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Acceptance:

- Fresh AAB/APK hashes are recorded.
- Signed artifact is installable and uses production env.
- Physical-device smoke covers auth, deep links, venue ordering, payment
  guidance, rewards ledger, and challenge entry.
- Google Play internal-test or upload evidence is captured.

## Goal 07 - Complete iOS Archive, IPA, Physical Device, Push, And TestFlight Proof

```text
/goal Complete FANZONE iOS TestFlight readiness for the current release candidate. Validate production iOS config, build a signed archive, export a signed IPA, install and launch on a physical iPhone, verify production push permission/delivery/tap routing, upload to App Store Connect/TestFlight, complete review metadata, update release/ios/testflight-readiness.json, and make node tool/validate_ios_testflight_evidence.mjs pass.
```

Why this goal exists:

- `node tool/validate_ios_testflight_evidence.mjs` currently fails on owner
  signoff and six required pending checks.

Required tools:

- Build iOS Apps plugin/XcodeBuildMCP where configured.
- Xcode, Apple Developer account, signing certificates/profiles.
- Physical iPhone for install/push proof.

Validation:

```bash
tool/build_ios_release_from_env.sh production
node tool/validate_ios_testflight_evidence.mjs
```

Acceptance:

- `release/ios/testflight-readiness.json` has all required checks as `PASS`.
- Signed archive and IPA paths exist.
- TestFlight/App Store Connect evidence references are redacted and durable.

## Goal 08 - Complete Critical End-To-End UAT Signoff

```text
/goal Execute and sign off FANZONE critical user-flow UAT across Flutter app, venue PWA, admin PWA, TV PWA, and Supabase backend. Use production or approved staging release-candidate environments, capture evidence for every flow in release/qa/critical-user-flow-uat.json, update every applicable flow to PASS with tester, timestamp, and evidence refs, and make node tool/validate_critical_uat_signoff.mjs pass.
```

Why this goal exists:

- Critical UAT is currently fully pending.

Required tools:

- Browser/Chrome plugin or Playwright for web/PWA evidence.
- Android/iOS devices for mobile evidence.
- Supabase CLI/plugin for backend evidence.

Must cover:

- anonymous session and WhatsApp OTP;
- venue discovery and table-number ordering;
- MoMo/Revolut/cash external handoff;
- staff manual payment confirmation and audit trail;
- order lifecycle transitions and invalid transition rejection;
- staff call and acknowledgement;
- daily payment reconciliation;
- FET reward earning and no customer transfer UX;
- challenge/game/free-to-play flows;
- admin curation/moderation/settlement;
- TV pairing/live display/recovery;
- cross-venue and cross-user denial;
- realtime propagation.

Validation:

```bash
node tool/validate_critical_uat_signoff.mjs
```

Acceptance:

- Every required UAT flow is `PASS`.
- Signoff metadata names QA owner and release owner.

## Goal 09 - Prove Scheduler, Cron, And Runtime Observability

```text
/goal Prove FANZONE production scheduler, cron, and observability readiness. Configure or verify CRON_SECRET and production scheduler routes for settle-match-pools and dispatch-match-alerts, run successful cron smokes, define missed-run and failure alerts, prove dashboards for auth, orders, payment confirmation, staff calls, settlements, FET ledger anomalies, Edge errors, database health, and PWA deploy health, and update scheduler/observability evidence.
```

Why this goal exists:

- Scheduler and production observability are `PENDING` in the evidence matrix.

Required tools:

- Supabase dashboard/CLI/plugin.
- Cloudflare logs/analytics.
- Sentry or equivalent observability provider.

Validation:

```bash
tool/run_supabase_cron_job.sh settle-match-pools
tool/run_supabase_cron_job.sh dispatch-match-alerts
tool/collect_world_class_evidence.sh
node tool/validate_operations_readiness_evidence.mjs
```

Acceptance:

- Evidence bundle exists under `output/release-evidence/<timestamp>/scheduler/`
  and `output/release-evidence/<timestamp>/observability/`.
- `release/operations/operations-readiness-evidence.json` records scheduler,
  observability surface, signal, alert-route, owner, and signoff evidence.
- `node tool/validate_operations_readiness_evidence.mjs` passes.
- Evidence matrix rows can move from `PENDING` to `PASS`.

## Goal 10 - Prove Backup, Restore, Incident Response, And Rollback Readiness

```text
/goal Prove FANZONE production backup, restore, incident response, and rollback readiness. Capture a production backup, document restore validation, tag the release candidate, record deploy rollback identifiers, name incident owners and escalation channels, review incident runbooks, create post-deploy watch instructions, and produce the redacted evidence bundle required by docs/operations/incident-runbooks.md and docs/release/rollback.md.
```

Why this goal exists:

- Incident response and rollback readiness is `PENDING`.
- Backup/restore evidence must be tied to the current release candidate.

Validation:

```bash
tool/create_supabase_backup_evidence.sh
git tag <release-tag>
tool/collect_world_class_evidence.sh
node tool/validate_operations_readiness_evidence.mjs
```

Acceptance:

- Evidence exists for owners, escalation, rollback tag, DB restore plan,
  runbook review, post-deploy watch, backup manifest, and restore validation.
- Incident and rollback evidence is recorded in
  `release/operations/operations-readiness-evidence.json`.
- `node tool/validate_operations_readiness_evidence.mjs` passes.
- No private phone numbers, private emails, customer data, or secret values are
  committed.

## Goal 11 - Complete Mobile MASVS-Style Security And Privacy Review

```text
/goal Complete the FANZONE mobile MASVS-style security and privacy review. Audit Flutter, Android, and iOS storage, transport security, permissions, logs, crash reporting, privacy prompts, secure session handling, deep links, notification handling, and release signing posture; remediate code-owned findings; capture real-device evidence; and update the evidence matrix from PARTIAL only when the review is complete.
```

Why this goal exists:

- Mobile security review is currently `PARTIAL`.
- FANZONE stores session and notification state and depends on deep links,
  secure storage, and production signing.

Required tools:

- Codex Security skills.
- Build iOS Apps plugin/Xcode tools where applicable.
- Physical devices for Android/iOS.

Validation:

```bash
tool/mobile_release_static_audit.sh
flutter analyze
flutter test
```

Acceptance:

- Static audit and real-device review evidence exist.
- Crash-reporting/telemetry posture is documented.
- No sensitive data appears in logs, screenshots, or tracked evidence.

## Goal 12 - Complete Accessibility, Performance, And Reliability Evidence

```text
/goal Complete FANZONE accessibility, performance, and reliability readiness across Flutter, website, admin, venue portal, and TV display. Run WCAG-oriented web checks, mobile accessibility checks, keyboard/screen-reader/tap-target/contrast reviews, PWA installability checks, cold-start and runtime smoke tests, load/reliability smoke for ordering, staff calls, FET rewards ledger, free-to-play entertainment, admin queues, and TV display recovery. Fix code-owned issues and capture evidence.
```

Why this goal exists:

- The world-class benchmark requires accessibility and performance evidence.
- Load and reliability smoke is `PENDING`.

Required tools:

- Browser/Chrome plugin, Playwright, Lighthouse/DevTools where available.
- Flutter integration/device testing.
- External load-test tool where approved.

Acceptance:

- Evidence covers every production surface.
- Latency/error-budget thresholds and rollback thresholds are documented.
- Code-owned accessibility/performance regressions are fixed.

## Goal 13 - Complete Privacy, Legal, Store Policy, And Support-Access Review

```text
/goal Complete FANZONE privacy, legal, store-policy, and support-access readiness. Review public terms, privacy policy, FET reward terms, Android Data Safety notes, Apple privacy labels, account deletion, retention, export, support access, contest/game disclosures, no-cash-out language, off-platform payment language, and reviewer instructions. Fix repo-owned policy/copy gaps and capture human-review evidence for legal/compliance-owned items.
```

Why this goal exists:

- Privacy/legal review is `PENDING`.
- App-store submission depends on accurate product boundaries and reviewer
  instructions.

Validation:

```bash
./tool/product_boundary_scan.sh
npm run validate:release-metadata -w @fanzone/website
node tool/validate_pwa_release_metadata.mjs admin
node tool/validate_pwa_release_metadata.mjs venue-portal
node tool/validate_pwa_release_metadata.mjs tv-display
node tool/validate_privacy_legal_readiness_evidence.mjs
```

Acceptance:

- Public policy URLs are final.
- Android and iOS store metadata are consistent with no-cash-out, no-betting,
  off-platform payment, and FET rewards-ledger boundaries.
- `release/legal/privacy-legal-readiness-evidence.json` records public policy,
  Data Safety, Apple privacy label, deletion/export, retention, support access,
  SDK inventory, and legal signoff evidence.
- `node tool/validate_privacy_legal_readiness_evidence.mjs` passes.
- Human-review blockers are explicitly recorded.

## Goal 14 - Close The World-Class Evidence Matrix And Produce Final Go/No-Go

```text
/goal Close FANZONE world-class go-live evidence and produce the final go/no-go report. After all prerequisite goals complete, update docs/release/world-class-evidence-matrix.md and docs/release/production-go-live-task-register.md with current evidence references, rerun all release validators, run ./tool/go_live_readiness.sh --local from a clean checkout, run ./tool/check_world_class_evidence.sh, collect the final evidence bundle, and produce a dated final go/no-go report with an honest GO only if every P0/P1 control passes.
```

Why this goal exists:

- This is the final release decision gate. It should not start until goals 00
  through 13 are complete or explicitly blocked with external evidence.

Validation:

```bash
./tool/go_live_readiness.sh --local
./tool/check_world_class_evidence.sh
node tool/validate_secret_rotation_evidence.mjs
node tool/validate_critical_uat_signoff.mjs
node tool/validate_ios_testflight_evidence.mjs
node tool/validate_operations_readiness_evidence.mjs
node tool/validate_privacy_legal_readiness_evidence.mjs
tool/collect_world_class_evidence.sh
git status --short
git rev-list --left-right --count main...origin/main
```

Acceptance:

- P0 and P1 rows are all `PASS` with evidence.
- Current release candidate is clean, tagged, and synced.
- Final report states `GO` only if all gates pass. Otherwise it states `NO-GO`
  with exact blockers and owners.

## External Standards To Use During Execution

Use the current official standards and guidance below when executing the
security, accessibility, mobile, and store-release goals:

- OWASP ASVS for web and service security verification:
  `https://owasp.org/www-project-application-security-verification-standard/`
- OWASP MASVS and MASTG for mobile application security:
  `https://mas.owasp.org/MASVS/`
- OWASP API Security Top 10 2023 for API abuse/authorization review:
  `https://owasp.org/API-Security/editions/2023/en/0x00-header/`
- NIST Cybersecurity Framework 2.0 for governance, detection, response, and
  recovery evidence:
  `https://www.nist.gov/cyberframework`
- W3C WCAG 2.2 for accessibility:
  `https://www.w3.org/TR/WCAG22/`
- Android core app quality and Google Play release guidance:
  `https://developer.android.com/tools/testing/what_to_test`
- Apple App Store Review Guidelines:
  `https://developer.apple.com/app-store/review/guidelines/`

## Completion Definition For The Whole Goal Pack

The goal pack is complete only when:

- `git status --short` is clean.
- `main...origin/main` is `0 0`.
- `./tool/go_live_readiness.sh --local` passes.
- `./tool/check_world_class_evidence.sh` passes.
- `node tool/validate_secret_rotation_evidence.mjs` passes.
- `node tool/validate_critical_uat_signoff.mjs` passes.
- `node tool/validate_ios_testflight_evidence.mjs` passes.
- `node tool/validate_operations_readiness_evidence.mjs` passes.
- `node tool/validate_privacy_legal_readiness_evidence.mjs` passes.
- `tool/collect_world_class_evidence.sh` produces no P0/P1 `PENDING` or `FAIL`
  entries.
- The final go/no-go report is committed, pushed, and tied to the release
  candidate.
