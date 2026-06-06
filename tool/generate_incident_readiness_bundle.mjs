#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const outRoot =
  process.argv[2] || "output/release-evidence/incident-readiness-code";
const timestamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
const bundleDir = path.resolve(process.cwd(), outRoot, timestamp);

function git(args) {
  return execFileSync("git", args, {
    cwd: process.cwd(),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function writeFile(name, content) {
  fs.writeFileSync(path.join(bundleDir, name), `${content.trim()}\n`, "utf8");
}

function repoRef(ref) {
  return path.resolve(process.cwd(), ref);
}

const sourceCommit = git(["rev-parse", "HEAD"]);
const shortCommit = sourceCommit.slice(0, 12);
const releaseTag = `fanzone-release-${shortCommit}`;
const generatedAtUtc = new Date().toISOString();

fs.mkdirSync(bundleDir, { recursive: true });

writeFile(
  "owners-and-escalation-redacted.txt",
  `
FANZONE incident owners and escalation template
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}

Required private fields before launch approval:
- incident_commander: PENDING_OWNER_SIGNOFF
- technical_owner: PENDING_OWNER_SIGNOFF
- communications_owner: PENDING_OWNER_SIGNOFF
- support_owner: PENDING_OWNER_SIGNOFF
- escalation_channel: PENDING_PRIVATE_CHANNEL
- backup_owner: PENDING_OWNER_SIGNOFF

Do not store private phone numbers, private emails, tokens, or customer data in
this tracked bundle. Store private contact details in the approved operations
system and reference only the redacted owner roles here.
`,
);

writeFile(
  "rollback-tag.txt",
  `
FANZONE rollback tag plan
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}
Proposed immutable release tag: ${releaseTag}

Required launch action:
git tag -a ${releaseTag} ${sourceCommit} -m "FANZONE release ${shortCommit}"
git push origin ${releaseTag}

Rollback rule:
- Prefer forward-fix migrations for already-applied database changes.
- Never delete order, FET ledger, payment, pool settlement, or audit history.
- Use feature flags or deployment rollback identifiers before data rollback.

Status: PENDING_RELEASE_OWNER_TAG_CREATION
`,
);

writeFile(
  "database-restore-plan.txt",
  `
FANZONE database restore plan template
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}

Required evidence before launch approval:
- production backup manifest: PENDING_BACKUP_OWNER
- restore owner: PENDING_OWNER_SIGNOFF
- restore target: staging restore drill or approved production incident window
- restore validation command: tool/create_supabase_backup_evidence.sh followed by restore list validation
- post-restore checks:
  - ./tool/supabase_rls_audit.sh
  - ./tool/supabase_fet_supply_smoke.sh
  - ./tool/supabase_order_lifecycle_smoke.sh --readiness
  - ./tool/supabase_manual_payment_reconciliation_smoke.sh --readiness
  - ./tool/supabase_staff_call_acknowledgement_smoke.sh --readiness

Rollback constraints:
- Do not truncate or rewrite customer order, payment, FET ledger, settlement,
  bell request, notification, or audit tables to roll back a release.
- Capture fresh backup evidence before any corrective restore.

Status: PENDING_BACKUP_AND_RESTORE_DRILL
`,
);

writeFile(
  "runbook-review.txt",
  `
FANZONE runbook review template
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}

Runbooks requiring human review:
- docs/operations/incident-runbooks.md
- docs/release/rollback.md
- docs/operations/scheduler-observability.md
- docs/release/production-go-live-task-register.md
- docs/release/world-class-evidence-matrix.md

Review decision: PENDING_RELEASE_OWNER_REVIEW
Reviewer: PENDING_OWNER_SIGNOFF
Review timestamp UTC: PENDING_OWNER_SIGNOFF

Required acceptance:
- owners and escalation route assigned;
- rollback tag created;
- production backup and restore validation evidence attached;
- observability dashboard and alert routes tested;
- post-deploy watch owner assigned.
`,
);

writeFile(
  "post-deploy-watch.txt",
  `
FANZONE post-deploy watch template
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}

Watch owner: PENDING_OWNER_SIGNOFF
Watch window: first 60 minutes after deploy, then next scheduled cron cycle
Primary dashboards/signals:
- admin_operations_observability_snapshot()
- app_runtime_errors runtime error rate
- product_events analytics flow
- orders open/disputed count
- payment_events manual payment confirmation
- fet_wallet_transactions credit/debit health
- match_pools open/locked/settled health
- bell_requests open staff calls
- notification_log and device_tokens push health
- matches last_live_checked_at LiveScore freshness

Rollback thresholds:
- sustained auth or order creation failures;
- Edge Function 5xx spike;
- FET ledger anomaly or settlement inconsistency;
- LiveScore sync stale beyond operator threshold;
- user-visible crash spike after rollout.

Status: PENDING_WATCH_OWNER_AND_PROVIDER_DASHBOARD_REFS
`,
);

writeFile(
  "sample-alert-test-redacted.txt",
  `
FANZONE sample alert test template
Generated UTC: ${generatedAtUtc}
Source commit: ${sourceCommit}

Required before launch approval:
- non-destructive alert route test executed;
- alert destination confirmed by operations owner;
- severity mapping confirmed;
- backup owner receives or can view alert;
- provider evidence exported or screenshotted with secrets redacted.

Recommended non-destructive test:
- trigger provider-side test alert or synthetic monitor check;
- do not inject production customer data;
- do not store alert webhook URLs, tokens, private phone numbers, or private
  emails in tracked evidence.

Status: PENDING_PROVIDER_ALERT_TEST
`,
);

const requiredFiles = [
  "owners-and-escalation-redacted.txt",
  "rollback-tag.txt",
  "database-restore-plan.txt",
  "runbook-review.txt",
  "post-deploy-watch.txt",
  "sample-alert-test-redacted.txt",
];

const manifest = {
  schemaVersion: 1,
  generatedAtUtc,
  sourceCommit,
  releaseTag,
  bundleDir: path.relative(process.cwd(), bundleDir),
  status: "CODE_OWNED_TEMPLATE_READY_PENDING_OWNER_SIGNOFF",
  requiredFiles,
  sourceRefs: [
    "docs/operations/incident-runbooks.md",
    "docs/release/rollback.md",
    "docs/operations/scheduler-observability.md",
    "tool/create_supabase_backup_evidence.sh",
    "tool/supabase_rls_audit.sh",
    "tool/supabase_fet_supply_smoke.sh",
    "tool/supabase_order_lifecycle_smoke.sh",
    "tool/supabase_manual_payment_reconciliation_smoke.sh",
    "tool/supabase_staff_call_acknowledgement_smoke.sh",
  ].filter((ref) => fs.existsSync(repoRef(ref))),
  pendingExternalEvidence: [
    "Named incident owners and private escalation channel",
    "Immutable release tag creation and push evidence",
    "Production backup manifest and restore drill evidence",
    "Human runbook review and approval",
    "Provider alert-route test evidence",
    "Release-owner launch signoff",
  ],
};

writeFile("manifest.json", JSON.stringify(manifest, null, 2));

console.log(`Incident readiness bundle generated: ${manifest.bundleDir}`);
