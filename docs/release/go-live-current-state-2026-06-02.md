# FANZONE Go-Live Current State - 2026-06-02

## Scope

This note records the current repo-owned go-live evidence captured on
2026-06-02 after the comprehensive handover report and Codex go-live goal pack
were committed to `main`.

This is not a launch approval. FANZONE remains `NO-GO` until every P0 and P1
control in `docs/release/world-class-evidence-matrix.md` is `PASS`, the
fail-closed evidence validators pass, and production/provider signoffs are
complete.

## Mobile Readiness Refresh - Current Checkout

Current local checkout evidence captured during the Flutter deployment-readiness
pass:

| Item | Evidence |
| --- | --- |
| Branch | `main` |
| Current source HEAD before this metadata edit | `c310a6c` (`c310a6cc0581881d80fcc67e19a0a64686307b1f`) |
| Flutter release candidate | `1.1.3+11` from `pubspec.yaml` |
| Linked Supabase project ref | `kjuhheobmdvjwgnzlcwx` from `supabase/.temp/project-ref` |
| Google Play target API check | Android `targetSdk = 35`, matching the current Google Play requirement that new apps and updates target Android 15 / API 35 or higher |
| Apple upload readiness check | iOS readiness still requires fresh archive/TestFlight evidence; current Apple guidance requires contemporary Xcode/iOS SDK upload evidence |

Local Flutter/mobile commands run on this checkout:

```bash
flutter pub get
./tool/mobile_release_static_audit.sh
./tool/product_boundary_scan.sh
flutter analyze
flutter test
flutter doctor -v
flutter build apk --debug
```

Results:

- `flutter pub get` completed with no tracked lockfile change.
- `tool/mobile_release_static_audit.sh` passed.
- `tool/product_boundary_scan.sh` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed with 249 tests.
- `flutter doctor -v` found Android tooling available, but Flutter is on an
  unknown local channel/source and CocoaPods is not installed, so iOS plugin,
  archive, and TestFlight readiness cannot be claimed from this environment.
- `flutter build apk --debug` did not complete in this run. It was terminated
  after 1039.6 seconds with exit code 143 after no fresh debug APK was produced.
  A concurrent unrelated Flutter/Gradle build in another checkout was also
  consuming Gradle resources during this attempt.

Release evidence metadata was refreshed in the fail-closed evidence files to
name release candidate `1.1.3+11`, source commit
`c310a6cc0581881d80fcc67e19a0a64686307b1f`, and production Supabase project ref
`kjuhheobmdvjwgnzlcwx` where applicable. This is metadata hygiene only: no
artifact, UAT, credential, monitoring, privacy/legal, load, or owner-signoff
item was marked `PASS`.

Validator rerun after the metadata refresh:

- `node tool/validate_android_release_evidence.mjs` still fails because signed
  AAB/APK, signature, freshness, install, deep-link, core smoke, Play internal
  test, review metadata, timestamp, and launch approval evidence are missing.
- `node tool/validate_ios_testflight_evidence.mjs` still fails because owner
  signoff, signed archive, signed IPA, iPhone install, push, TestFlight, App
  Store Connect processing, export compliance, beta information, review
  metadata, timestamp, and launch approval evidence are missing.
- `node tool/validate_critical_uat_signoff.mjs` still fails because the UAT
  window, durable evidence bundle, owners, signoff, approval, and every required
  critical flow remain `PENDING`.
- `./tool/check_world_class_evidence.sh` still fails with 19 launch-readiness
  issues. The remaining failures are provider/operator evidence gaps, not stale
  release-candidate or source-commit metadata.

## Previous Full Local-Gate Repository State

| Item | Evidence |
| --- | --- |
| Working tree | Clean before the local go-live gate run |
| Branch | `main` |
| Local HEAD | `7cc4e3e` |
| Remote HEAD | `origin/main` at `7cc4e3e` |
| Divergence | `git rev-list --left-right --count main...origin/main` returned `0 0` |
| Most recent pushed commit | `7cc4e3e chore: record go-live evidence progress` |

## Previous Full Repo-Owned Local Gate

Command:

```bash
./tool/go_live_readiness.sh --local
```

Result: `PASS`

The local go-live gate completed successfully at `7cc4e3e` and reported:

- clean working tree;
- tracked-file secret regex scan passed;
- `tool/full_history_secret_scan.sh` passed;
- `tool/audit_repo_hygiene.sh` passed;
- `tool/product_boundary_scan.sh` passed, including scoped realtime,
  order Edge boundary, order lifecycle parity, venue portal hospitality,
  entertainment/reward boundary, and Flutter ordering boundary checks;
- `tool/mobile_release_static_audit.sh` passed;
- `flutter analyze` passed with no issues;
- `flutter test` passed with 249 tests;
- Node workspace typecheck, lint, test, and build passed for the active web
  workspaces and shared core package;
- BFF health smoke passed;
- Supabase Edge Function formatting, checks, and tests passed;
- core order lifecycle Deno tests passed;
- release script syntax checks passed.

The command ended with:

```text
Local go-live checks passed. External/provider tasks still require evidence in docs/release/production-go-live-task-register.md.
```

## Fail-Closed Evidence Validators

The local gate is green, but the production evidence validators still correctly
fail because external/provider evidence and owner signoffs are not complete.

### World-Class Evidence

Command:

```bash
./tool/check_world_class_evidence.sh
```

Result: `FAIL`

Open blockers:

- P0 credential rotation and secret inventory remains `PENDING`;
- P0 world-class benchmark completion remains `PENDING`;
- P1 scheduler and cron monitoring remains `PENDING`;
- P1 Android release artifact remains `PARTIAL`;
- P1 iOS archive/TestFlight readiness remains `PARTIAL`;
- P1 critical user-flow UAT remains `PENDING`;
- P1 production observability and alerting remains `PENDING`;
- P1 incident response and rollback readiness remains `PENDING`.

The world-class evidence gate now also runs the backing evidence validators for
secret rotation, critical UAT, Android release readiness, iOS/TestFlight
readiness, operations readiness, privacy/legal readiness, and load/reliability
readiness. A future release cannot pass this gate by editing the matrix alone.

The aggregate evidence collector now fails by default when any collected item is
`PENDING` or `FAIL`. `tool/collect_world_class_evidence.sh --allow-pending` is
reserved for partial inventory snapshots and is not launch approval evidence.

Generate a current source-commit-bound baseline inventory with:

```bash
tool/generate_release_baseline_inventory.sh
```

The command writes `output/release-evidence/<timestamp>/baseline/current-state.md`
with repository state, evidence matrix inventory, and validator logs. Use
`--fail-on-blockers` only for final release approval; it must remain non-zero
until all blocker signals are closed.

The repo now also has a release evidence contract check:

```bash
tool/validate_release_evidence_contract.sh
```

This check verifies that the P0/P1 matrix and `tool/check_world_class_evidence.sh`
agree about the current launch state. It is also wired into the GitHub `Release
Evidence Contracts` CI job.

### Secret Rotation Evidence

Command:

```bash
node tool/validate_secret_rotation_evidence.mjs
```

Result: `FAIL`

Open blockers:

- `releaseCandidate` is still `TBD`;
- `sourceCommit` is still `TBD`;
- rotation start/completion timestamps and durable evidence bundle root are not
  populated;
- security owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- all credential classes are still `PENDING`, including Supabase anon key,
  Supabase service-role key, Supabase database credentials, Supabase PAT,
  Cloudflare runtime secrets, Supabase Edge secrets, CI/CD secrets, and local
  operator secrets;
- post-rotation checks still need evidence references for full-history secret
  scanning, production env isolation, Supabase live validation, and deployed
  web surface smoke.

The validator now also rejects missing source-commit metadata, missing or
unordered rotation-window timestamps, missing or unresolved evidence bundle
roots, missing or unresolved provider/smoke evidence references, and live
credential patterns in the evidence file.

### Critical UAT Evidence

Command:

```bash
node tool/validate_critical_uat_signoff.mjs
```

Result: `FAIL`

Open blockers:

- `releaseCandidate` is still `TBD`;
- `sourceCommit` is still `TBD`;
- tested mobile build and Supabase project ref are still `TBD`;
- UAT test window and durable evidence bundle root are not populated;
- QA owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- all listed mobile, venue, admin, TV, realtime, and backend isolation UAT
  flows remain `PENDING`.

The validator now also rejects unknown or misplaced flow IDs, missing required
flow IDs, missing required evidence descriptions, missing or unresolved PASS
evidence references, missing source-commit/environment/test-window metadata,
missing evidence bundle root, and live credential patterns in the evidence file.

### iOS TestFlight Evidence

Command:

```bash
node tool/validate_ios_testflight_evidence.mjs
```

Result: `FAIL`

Open blockers:

- source commit is still `TBD`;
- mobile owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- signed archive, signed IPA, physical iPhone install, push smoke, TestFlight,
  App Store Connect build status, export compliance, beta test information, and
  App Store review metadata checks remain `PENDING`.

## Additional Repo-Owned Hardening Added

After the local gate pass, the repo gained a dedicated Supabase API
authorization-abuse entrypoint:

```bash
./tool/supabase_api_authorization_abuse_tests.sh --readiness
./tool/supabase_api_authorization_abuse_tests.sh --contract
```

The script composes the existing RLS audit and Hospitality Core Phase 2 SQL
contracts. The contract mode is rollback-based and exercises negative
authorization paths already covered by the SQL contracts, including customer
mutation rejection, cross-venue staff/order/reconciliation/staff-call rejection,
direct table mutation denial, unsupported payment rejection, and admin-only
surface checks.

This improves the P2 API authorization-abuse evidence row from `PENDING` to
`PARTIAL`. It must not be marked `PASS` until the script is run against the
release target and Edge Function auth-abuse evidence is attached.

Validation status on 2026-06-02:

- `bash -n tool/supabase_api_authorization_abuse_tests.sh` passed;
- `./tool/supabase_api_authorization_abuse_tests.sh --readiness` could not
  complete in this environment because the linked Supabase CLI connection timed
  out while creating the login role and requested `SUPABASE_DB_PASSWORD` or a
  direct `SUPABASE_DB_URL`;
- `--contract` was not run without a working release-target database
  connection.

## Current Launch Decision

Decision: `NO-GO`

Reason: the repo-owned local gate passes, but FANZONE still lacks required
production/provider proof and owner signoffs for P0/P1 launch controls. The
next implementation work should focus on closing evidence in this order:

1. credential rotation and secret inventory;
2. live production Supabase Phase 2 validation and post-rotation checks;
3. deployed web/PWA runtime, CORS, and header proof;
4. Android release artifact proof;
5. iOS archive, IPA, device, push, and TestFlight proof;
6. critical user-flow UAT;
7. scheduler, observability, incident, and rollback proof;
8. final fail-closed go/no-go rerun.

## Operations Evidence Validator Added

The repo now has a structured operations evidence file:

```bash
release/operations/operations-readiness-evidence.json
```

Validate it with:

```bash
node tool/validate_operations_readiness_evidence.mjs
```

The validator is fail-closed and currently expected to fail until production
scheduler history, cron smoke evidence, observability dashboards, alert routes,
incident ownership, rollback tag, database restore plan, post-deploy watch, a
sample alert test, and release-owner approval are recorded.

The validator now also rejects missing source-commit metadata, missing
production target URLs or Supabase project ref, missing or unordered evidence
window timestamps, missing or unresolved scheduler/observability/incident
evidence bundle roots, incorrect scheduler smoke commands, missing or unresolved
dashboard/alert/smoke/history evidence refs, and live credential patterns in the
evidence file.

## Privacy/Legal Evidence Validator Added

The repo now has a structured privacy and legal evidence file:

```bash
release/legal/privacy-legal-readiness-evidence.json
```

Validate it with:

```bash
node tool/validate_privacy_legal_readiness_evidence.mjs
```

The validator is fail-closed and currently expected to fail until the final
release candidate has reviewed public policy URLs, Android Data Safety, Apple
privacy labels, account deletion, retention, data export/access, support access,
SDK data inventory, no-betting/no-cash-out wording, off-platform payment
wording, and legal/compliance signoff evidence.

The validator now also rejects missing source-commit metadata, missing
production target URLs, missing or unordered review-window timestamps, missing
or unresolved privacy/legal evidence bundle roots, missing official guidance
references, missing public policy URLs, misplaced check surfaces, missing or
unresolved PASS evidence refs, and live credential patterns in the evidence
file.

## Load And Reliability Evidence Validator Added

The repo now has a structured load and reliability evidence file:

```text
release/performance/load-reliability-evidence.json
```

Validate it with:

```bash
node tool/validate_load_reliability_evidence.mjs
```

The validator is fail-closed and currently expected to fail until release-target
load smoke evidence exists for ordering, off-platform payment handoff,
staff-call acknowledgement, FET ledger accrual, reward redemption, free-to-play
entertainment entry and settlement, admin live queues, TV recovery, realtime
propagation, Edge Function error budget, database RLS under concurrent access,
rollback thresholds, and performance/operations/release owner signoff.

The validator now also rejects missing source-commit metadata, missing
production target URLs or Supabase project ref, missing or unordered test-window
timestamps, missing or unresolved evidence bundle roots, misplaced scenario
surfaces, missing or unresolved scenario evidence refs, threshold violations,
and live credential patterns in the evidence file.

## Android Release Evidence Validator Added

The repo now has a structured Android release evidence file:

```text
release/android/android-release-readiness.json
```

Validate it with:

```bash
node tool/validate_android_release_evidence.mjs
```

The validator is fail-closed and currently expected to fail until the release
candidate records a source commit, fresh signed AAB/APK paths, SHA-256 hashes,
build timestamps, signature verification, production preflight, physical-device
install smoke, Android App Link/deep-link smoke, core-flow smoke, Google Play
internal-test evidence, review metadata evidence, and mobile/release owner
signoff.

## iOS/TestFlight Evidence Validator Hardened

The iOS/TestFlight evidence file is:

```text
release/ios/testflight-readiness.json
```

Validate it with:

```bash
node tool/validate_ios_testflight_evidence.mjs
```

The validator now requires official Apple guidance references, a source commit,
signed archive and IPA artifact records, SHA-256 hashes, artifact sizes, build
timestamps, App Store Connect build status, export-compliance answers,
TestFlight beta information, App Review metadata, physical iPhone install
smoke, production push smoke, and mobile/release owner signoff before the P1
iOS row can move beyond `PARTIAL`.
