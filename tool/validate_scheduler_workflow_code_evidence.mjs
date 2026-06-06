#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] || "release/operations/scheduler-workflow-code-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._~+/\-]+=*)/;

const requiredControls = [
  "Required scheduler fallback workflows exist",
  "Operations schedule and dispatch controls are enforced",
  "Scheduler credentials are referenced as secrets only",
  "Scheduler targets match deployed Edge jobs",
  "Platform cron manifest matches scheduler expectations",
  "Code-owned scheduler history and missed-run snapshot exist",
  "Credential-safe post-deploy audit smoke tooling exists",
  "Provider scheduler state is captured without credentials",
  "Provider history remains an external launch gate",
];

const jobs = [
  {
    id: "settle-match-pools",
    workflow: ".github/workflows/cron-settle.yml",
    command: "tool/run_supabase_cron_job.sh settle-match-pools",
    functionTarget: "functions/v1/settle-match-pools",
    payload: '{"limit":50}',
    concurrencyGroup: "cron-settle-production",
    cronExpression: "*/15 * * * *",
  },
  {
    id: "dispatch-match-alerts",
    workflow: ".github/workflows/cron-match-alerts.yml",
    command: "tool/run_supabase_cron_job.sh dispatch-match-alerts",
    functionTarget: "functions/v1/dispatch-match-alerts",
    payload: "{}",
    concurrencyGroup: "cron-match-alerts-production",
    cronExpression: "*/5 * * * *",
  },
  {
    id: "sync-livescore-football",
    workflow: ".github/workflows/cron-livescore-football.yml",
    command: "tool/run_supabase_cron_job.sh sync-livescore-football",
    functionTarget: "functions/v1/sync-livescore-football",
    payload: "livescore_world_cup_2026",
    concurrencyGroup: "cron-livescore-football-production",
    requiresDryRunStep: true,
    cronExpression: "7 * * * *",
  },
];

const requiredRefs = [
  ".github/workflows/cron-settle.yml",
  ".github/workflows/cron-match-alerts.yml",
  ".github/workflows/cron-livescore-football.yml",
  "release/operations/scheduler-platform-cron-manifest.json",
  "release/operations/scheduler-provider-state-evidence.json",
  "tool/run_supabase_cron_job.sh",
  "tool/scheduler_payload_smoke.sh",
  "tool/validate_scheduler_platform_manifest.mjs",
  "tool/capture_scheduler_provider_state.mjs",
  "tool/validate_scheduler_provider_state_evidence.mjs",
  "supabase/functions/settle-match-pools/index.ts",
  "supabase/functions/dispatch-match-alerts/index.ts",
  "supabase/functions/sync-livescore-football/index.ts",
  "supabase/functions/_shared/cron_audit.ts",
  "supabase/functions/_shared/cron_audit_test.ts",
  "supabase/migrations/20260606170000_scheduler_run_history_and_missed_run_alerts.sql",
  "supabase/tests/scheduler_run_history_alerts.sql",
  "tool/supabase_scheduler_history_alerts.sh",
  "tool/scheduler_post_deploy_audit_smoke.mjs",
  "tool/validate_scheduler_post_deploy_audit_smoke.mjs",
  "release/operations/scheduler-post-deploy-audit-smoke-evidence.json",
  "release/operations/cron-smoke-evidence-20260606T043304Z.json",
  "docs/operations/scheduler-observability.md",
  "docs/release/world-class-evidence-matrix.md",
  "docs/release/production-go-live-task-register.md",
];

const requiredFileFragments = new Map([
  [
    "release/operations/scheduler-platform-cron-manifest.json",
    [
      "PASS_WITH_PENDING_PROVIDER_ACTIVATION",
      "supabase_edge_cron",
      "CRON_SECRET",
      "settle-match-pools",
      "dispatch-match-alerts",
      "sync-livescore-football",
      "*/15 * * * *",
      "*/5 * * * *",
      "7 * * * *",
      "livescore_world_cup_2026",
      "PENDING_PROVIDER_ACTIVATION",
    ],
  ],
  [
    "tool/validate_scheduler_platform_manifest.mjs",
    [
      "Scheduler platform manifest validation passed",
      "PASS_WITH_PENDING_PROVIDER_ACTIVATION",
      "expectedJobs",
      "provider schedules",
      "provider scheduler run history",
      "missed-run alert evidence",
    ],
  ],
  [
    "release/operations/scheduler-provider-state-evidence.json",
    [
      "BLOCKED_PROVIDER_STATE",
      "settle-match-pools",
      "dispatch-match-alerts",
      "sync-livescore-football",
      "RECENT_SCHEDULE_RUN_NOT_SUCCESSFUL",
      "MISSING_SCHEDULE_RUN_HISTORY",
      "workflowFoundOnDefaultBranch",
      "default branch",
      "scheduled runs complete successfully",
    ],
  ],
  [
    "tool/capture_scheduler_provider_state.mjs",
    [
      "GitHub Actions provider scheduler state",
      "BLOCKED_PROVIDER_STATE",
      "recentScheduledRuns",
      "Workflow not found on default branch",
      "Run IDs are SHA-256 hashed",
    ],
  ],
  [
    "tool/validate_scheduler_provider_state_evidence.mjs",
    [
      "Scheduler provider state validation passed",
      "BLOCKED_PROVIDER_STATE",
      "allowedProviderStates",
      "scheduled runs complete successfully",
      "missed-run alert evidence",
    ],
  ],
  [
    "tool/run_supabase_cron_job.sh",
    [
      "settle-match-pools",
      "dispatch-match-alerts",
      "sync-livescore-football",
      "CRON_SECRET remains the production scheduler default",
      "--dry-run",
    ],
  ],
  [
    "tool/scheduler_payload_smoke.sh",
    [
      "tool/run_supabase_cron_job.sh --dry-run settle-match-pools",
      "tool/run_supabase_cron_job.sh --dry-run dispatch-match-alerts",
      "tool/run_supabase_cron_job.sh --dry-run sync-livescore-football",
      "tool/supabase_edge_job_smoke.sh --unauthorized-only",
    ],
  ],
  [
    "docs/operations/scheduler-observability.md",
    [
      "scheduler workflow code evidence",
      "database-backed run-history",
      "provider scheduler history",
      "missed-run alert",
      "sync-livescore-football",
    ],
  ],
  [
    "supabase/functions/settle-match-pools/index.ts",
    [
      "../_shared/cron_audit.ts",
      "startCronJobRun",
      "finishCronJobRun",
      "cronAuditResponse",
      "settle-match-pools",
    ],
  ],
  [
    "supabase/functions/dispatch-match-alerts/index.ts",
    [
      "../_shared/cron_audit.ts",
      "startCronJobRun",
      "finishCronJobRun",
      "cronAuditResponse",
      "dispatch-match-alerts",
    ],
  ],
  [
    "supabase/functions/sync-livescore-football/index.ts",
    [
      "../_shared/cron_audit.ts",
      "startCronJobRun",
      "finishCronJobRun",
      "cronAuditResponse",
      "sync-livescore-football",
    ],
  ],
  [
    "supabase/functions/_shared/cron_audit.ts",
    [
      "cron_job_start",
      "cron_job_finish",
      "sanitizeAuditError",
      "service[_-]?role",
      "cronAuditResponse",
    ],
  ],
  [
    "supabase/functions/_shared/cron_audit_test.ts",
    [
      "startCronJobRun records scheduler run ids",
      "finishCronJobRun records terminal scheduler status",
      "scheduler audit degrades without blocking cron work",
    ],
  ],
  [
    "supabase/migrations/20260606170000_scheduler_run_history_and_missed_run_alerts.sql",
    [
      "CREATE TABLE IF NOT EXISTS public.scheduler_job_expectations",
      "CREATE OR REPLACE FUNCTION public.cron_job_start",
      "CREATE OR REPLACE FUNCTION public.cron_job_finish",
      "CREATE OR REPLACE FUNCTION public.admin_scheduler_health_snapshot",
      "missed_run",
      "alert_required",
      "Admin scheduler health snapshot requires a platform admin",
      "REVOKE ALL ON TABLE public.cron_job_log FROM PUBLIC, anon, authenticated",
      "GRANT EXECUTE ON FUNCTION public.cron_job_start",
      "GRANT EXECUTE ON FUNCTION public.admin_scheduler_health_snapshot",
    ],
  ],
  [
    "supabase/tests/scheduler_run_history_alerts.sql",
    [
      "scheduler_run_history_alerts_passed",
      "Client roles must not execute cron_job_start",
      "Client roles must not read raw cron_job_log rows",
      "admin_scheduler_health_snapshot must include missed-run and admin guard logic",
    ],
  ],
  [
    "tool/supabase_scheduler_history_alerts.sh",
    [
      "supabase/tests/scheduler_run_history_alerts.sql",
      "SUPABASE_SCHEDULER_HISTORY_DB_URL",
      "supabase db query --linked",
      "output/release-evidence/scheduler-history-alerts",
    ],
  ],
  [
    "tool/scheduler_post_deploy_audit_smoke.mjs",
    [
      "Post-deploy scheduler Edge smoke",
      "CRON_SECRET",
      "auditTracked",
      "Refusing to write evidence containing a credential value",
      "output/release-evidence/scheduler-post-deploy-smoke",
    ],
  ],
  [
    "tool/validate_scheduler_post_deploy_audit_smoke.mjs",
    [
      "Scheduler post-deploy audit smoke validation passed",
      "auditTracked must be true",
      "observed.audit must include tracked run_id",
      "credential pattern",
    ],
  ],
  [
    "release/operations/scheduler-post-deploy-audit-smoke-evidence.json",
    [
      "Post-deploy scheduler Edge smoke",
      "secretValuesPrinted",
      "auditTracked",
      "settle-match-pools",
      "dispatch-match-alerts",
      "sync-livescore-football",
      "tracked",
    ],
  ],
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return (
    hasText(value) &&
    Number.isFinite(Date.parse(value)) &&
    value.includes("T") &&
    value.endsWith("Z")
  );
}

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function gitCommitExists(value) {
  if (!hasText(value) || value === "UNKNOWN") return false;
  try {
    execFileSync("git", ["cat-file", "-e", `${value}^{commit}`], {
      cwd: process.cwd(),
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

function hasUncommentedScheduleTrigger(text) {
  return text
    .split(/\r?\n/)
    .some((line) => !line.trimStart().startsWith("#") && /^\s*schedule\s*:/.test(line));
}

function requireFile(errors, ref) {
  if (!fs.existsSync(repoPath(ref))) errors.push(`${ref} must exist.`);
}

function requireFragments(errors, ref, fragments) {
  requireFile(errors, ref);
  if (!fs.existsSync(repoPath(ref))) return;
  const text = fs.readFileSync(repoPath(ref), "utf8");
  if (credentialPattern.test(text)) {
    errors.push(`${ref} must not contain live credential-looking values.`);
  }
  for (const fragment of fragments) {
    if (!text.includes(fragment)) errors.push(`${ref} must include ${fragment}.`);
  }
}

function requireEvidenceRefWithFragments(errors, refs, prefix, fragments) {
  const ref = refs
    .filter((item) => typeof item === "string" && item.startsWith(prefix))
    .sort()
    .at(-1);
  if (!ref) {
    errors.push(`evidenceRefs must include a ${prefix} log.`);
    return;
  }
  requireFragments(errors, ref, fragments);
}

function validateWorkflow(errors, job) {
  requireFile(errors, job.workflow);
  if (!fs.existsSync(repoPath(job.workflow))) return;
  const text = fs.readFileSync(repoPath(job.workflow), "utf8");

  if (credentialPattern.test(text)) {
    errors.push(`${job.workflow} must not contain live credential-looking values.`);
  }
  if (!text.includes("workflow_dispatch:")) {
    errors.push(`${job.workflow} must expose workflow_dispatch.`);
  }
  if (!text.includes("schedule:")) {
    errors.push(`${job.workflow} must enable a GitHub schedule trigger.`);
  }
  if (!text.includes(`cron: "${job.cronExpression}"`)) {
    errors.push(`${job.workflow} must include cron: "${job.cronExpression}".`);
  }
  for (const fragment of [
    "contents: read",
    `group: ${job.concurrencyGroup}`,
    "cancel-in-progress: false",
    "SUPABASE_URL: ${{ secrets.SUPABASE_URL }}",
    "CRON_SECRET: ${{ secrets.CRON_SECRET }}",
    `${job.id}:`,
    "if: github.ref_name == 'main'",
    "name: production-operations",
    'test -n "${SUPABASE_URL}"',
    'test -n "${CRON_SECRET}"',
  ]) {
    if (!text.includes(fragment)) errors.push(`${job.workflow} must include ${fragment}.`);
  }
  if (!text.includes(job.functionTarget) && !text.includes(job.command)) {
    errors.push(`${job.workflow} must target ${job.functionTarget} or ${job.command}.`);
  }
  if (!text.includes(job.payload)) {
    errors.push(`${job.workflow} must include expected payload marker ${job.payload}.`);
  }
  if (job.requiresDryRunStep && !text.includes(`--dry-run ${job.id}`)) {
    errors.push(`${job.workflow} must validate payload with --dry-run ${job.id}.`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Scheduler workflow code evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(data.releaseCandidate)) errors.push("releaseCandidate is required.");
if (!gitCommitExists(data.sourceCommit)) {
  errors.push("sourceCommit must name an existing git commit.");
}
if (!String(data.scope || "").includes("scheduler workflow controls")) {
  errors.push("scope must describe scheduler workflow controls.");
}
if (data.status !== "PASS_WITH_PENDING_PROVIDER_HISTORY") {
  errors.push("status must be PASS_WITH_PENDING_PROVIDER_HISTORY.");
}

const controls = Array.isArray(data.controls) ? data.controls : [];
for (const controlName of requiredControls) {
  const control = controls.find((item) => item?.name === controlName);
  if (!control) {
    errors.push(`Missing control: ${controlName}.`);
    continue;
  }
  if (control.status !== "PASS") errors.push(`${controlName} must be PASS.`);
  if (!hasText(control.proof)) errors.push(`${controlName} must include proof.`);
}

const jobsById = new Map(
  (Array.isArray(data.jobs) ? data.jobs : [])
    .filter((job) => hasText(job?.id))
    .map((job) => [job.id, job]),
);
for (const job of jobs) {
  const item = jobsById.get(job.id);
  if (!item) {
    errors.push(`jobs must include ${job.id}.`);
    continue;
  }
  if (item.workflow !== job.workflow) errors.push(`${job.id}.workflow must be ${job.workflow}.`);
  if (item.status !== "PASS") errors.push(`${job.id}.status must be PASS.`);
  if (item.controls?.scheduledTrigger !== true) {
    errors.push(`${job.id}.controls.scheduledTrigger must be true.`);
  }
  if (item.controls?.manualDispatchFallback !== true) {
    errors.push(`${job.id}.controls.manualDispatchFallback must be true.`);
  }
  for (const [key, value] of Object.entries(item.controls || {})) {
    if (value !== true) errors.push(`${job.id}.controls.${key} must be true.`);
  }
}

for (const job of jobs) validateWorkflow(errors, job);

const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
for (const ref of requiredRefs) {
  if (!refs.includes(ref)) errors.push(`evidenceRefs must include ${ref}.`);
  requireFragments(errors, ref, requiredFileFragments.get(ref) || []);
}
requireEvidenceRefWithFragments(
  errors,
  refs,
  "output/release-evidence/scheduler-history-alerts/",
  [
    "FANZONE scheduler run history and missed-run alert contract",
    "scheduler_run_history_alerts_passed",
    "supabase/tests/scheduler_run_history_alerts.sql",
  ],
);
requireEvidenceRefWithFragments(
  errors,
  refs,
  "output/release-evidence/scheduler-deployments/",
  [
    "FANZONE scheduler Edge deployment inventory",
    "Project ref: kjuhheobmdvjwgnzlcwx",
    "settle-match-pools",
    "dispatch-match-alerts",
    "sync-livescore-football",
    "ACTIVE",
  ],
);
if (!hasText(data.generatedEvidencePath)) {
  errors.push("generatedEvidencePath is required.");
} else {
  requireFile(errors, data.generatedEvidencePath);
}

const commands = Array.isArray(data.commands) ? data.commands : [];
for (const command of [
  "node tool/generate_scheduler_workflow_code_evidence.mjs",
  "node tool/validate_scheduler_workflow_code_evidence.mjs",
  "deno test --allow-env supabase/functions/_shared/cron_audit_test.ts",
  "node tool/validate_scheduler_platform_manifest.mjs",
  "node tool/capture_scheduler_provider_state.mjs",
  "node tool/validate_scheduler_provider_state_evidence.mjs",
  "supabase db push",
  "tool/supabase_scheduler_history_alerts.sh",
  "supabase functions deploy settle-match-pools dispatch-match-alerts sync-livescore-football",
  "node --check tool/scheduler_post_deploy_audit_smoke.mjs && node --check tool/validate_scheduler_post_deploy_audit_smoke.mjs",
  "node tool/scheduler_post_deploy_audit_smoke.mjs",
  "node tool/validate_scheduler_post_deploy_audit_smoke.mjs",
]) {
  const item = commands.find((entry) => entry?.command === command);
  if (item?.status !== "PASS") {
    errors.push(`${command} must be recorded with PASS status.`);
  }
}

const pending = Array.isArray(data.pendingExternalEvidence)
  ? data.pendingExternalEvidence
  : [];
for (const required of [
  "Capture production provider scheduler history",
  "Capture missed-run alert configuration",
  "Capture operations owner",
]) {
  if (!pending.some((item) => String(item).includes(required))) {
    errors.push(`pendingExternalEvidence must include ${required}.`);
  }
}

if (errors.length > 0) {
  console.error(`Scheduler workflow code evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Scheduler workflow code evidence validation passed for ${targetPath}.`);
