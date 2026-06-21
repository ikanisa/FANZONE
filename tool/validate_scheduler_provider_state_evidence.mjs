#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/operations/scheduler-provider-state-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(gho_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._~+/\-]+=*)/;

const expectedJobs = new Map([
  [
    "settle-match-pools",
    {
      workflowName: "Match Pool Settlement Cron",
      workflowPath: ".github/workflows/cron-settle.yml",
      expectedCron: "*/15 * * * *",
    },
  ],
  [
    "dispatch-match-alerts",
    {
      workflowName: "Match Alert Dispatch Cron",
      workflowPath: ".github/workflows/cron-match-alerts.yml",
      expectedCron: "*/5 * * * *",
    },
  ],
  [
    "sync-livescore-football",
    {
      workflowName: "LiveScore Football Sync Cron",
      workflowPath: ".github/workflows/cron-livescore-football.yml",
      expectedCron: "7 * * * *",
    },
  ],
  [
    "generate-weekly-game-packs",
    {
      workflowName: "Weekly Game Pack Generation Cron",
      workflowPath: ".github/workflows/cron-generate-weekly-game-packs.yml",
      expectedCron: "17 3 * * 1",
    },
  ],
]);

const allowedProviderStates = new Set([
  "PASS",
  "MISSING_WORKFLOW_ON_DEFAULT_BRANCH",
  "WORKFLOW_NOT_ACTIVE",
  "MISSING_SCHEDULE_RUN_HISTORY",
  "RECENT_SCHEDULE_RUN_NOT_SUCCESSFUL",
  "RUN_IN_PROGRESS",
]);

const allowedManualDispatchStates = new Set([
  "PASS",
  "MISSING_WORKFLOW_ON_DEFAULT_BRANCH",
  "WORKFLOW_NOT_ACTIVE",
  "MISSING_MANUAL_DISPATCH_HISTORY",
  "RECENT_MANUAL_DISPATCH_NOT_SUCCESSFUL",
  "RUN_IN_PROGRESS",
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoUtc(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

if (!fs.existsSync(absolutePath)) {
  console.error(`Scheduler provider state validation failed for ${targetPath}:`);
  console.error("- evidence file does not exist.");
  process.exit(1);
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Scheduler provider state validation failed for ${targetPath}:`);
  console.error("- evidence appears to contain a live credential pattern.");
  process.exit(1);
}

let data;
try {
  data = JSON.parse(raw);
} catch (error) {
  console.error(`Scheduler provider state validation failed for ${targetPath}:`);
  console.error(`- could not parse JSON: ${error.message}`);
  process.exit(1);
}

const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoUtc(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.repo !== "ikanisa/FANZONE") errors.push("repo must be ikanisa/FANZONE.");
if (data.command !== "node tool/capture_scheduler_provider_state.mjs") {
  errors.push("command must be node tool/capture_scheduler_provider_state.mjs.");
}
if (!String(data.scope || "").includes("GitHub Actions provider scheduler state")) {
  errors.push("scope must describe GitHub Actions provider scheduler state.");
}

const jobs = Array.isArray(data.jobs) ? data.jobs : [];
if (jobs.length !== expectedJobs.size) {
  errors.push(`jobs must include exactly ${expectedJobs.size} scheduler jobs.`);
}
const seen = new Set();
for (const job of jobs) {
  const expected = expectedJobs.get(job?.id);
  if (!expected) {
    errors.push(`${job?.id || "unknown"} is not an expected scheduler job.`);
    continue;
  }
  if (seen.has(job.id)) errors.push(`${job.id} is duplicated.`);
  seen.add(job.id);
  for (const [key, expectedValue] of Object.entries(expected)) {
    if (job[key] !== expectedValue) {
      errors.push(`${job.id}.${key} must be ${expectedValue}.`);
    }
  }
  if (job.localCron !== expected.expectedCron) {
    errors.push(`${job.id}.localCron must be ${expected.expectedCron}.`);
  }
  if (!allowedProviderStates.has(job.providerState)) {
    errors.push(`${job.id}.providerState is invalid.`);
  }
  if (!allowedManualDispatchStates.has(job.manualDispatchState)) {
    errors.push(`${job.id}.manualDispatchState is invalid.`);
  }
  if (job.workflowIdSha256 && job.workflowIdSha256.length !== 64) {
    errors.push(`${job.id}.workflowIdSha256 must be a SHA-256 hash.`);
  }
  const runs = Array.isArray(job.recentScheduledRuns)
    ? job.recentScheduledRuns
    : [];
  for (const run of runs) {
    if (!hasText(run.idSha256) || run.idSha256.length !== 64) {
      errors.push(`${job.id}.recentScheduledRuns.idSha256 must be a SHA-256 hash.`);
    }
    if (run.event && run.event !== "schedule") {
      errors.push(`${job.id}.recentScheduledRuns.event must be schedule.`);
    }
    if (run.branch && run.branch !== "main") {
      errors.push(`${job.id}.recentScheduledRuns.branch must be main.`);
    }
    if (run.createdAtUtc && !isIsoUtc(run.createdAtUtc)) {
      errors.push(`${job.id}.recentScheduledRuns.createdAtUtc must be ISO UTC.`);
    }
  }
  const manualRuns = Array.isArray(job.recentManualDispatchRuns)
    ? job.recentManualDispatchRuns
    : [];
  for (const run of manualRuns) {
    if (!hasText(run.idSha256) || run.idSha256.length !== 64) {
      errors.push(`${job.id}.recentManualDispatchRuns.idSha256 must be a SHA-256 hash.`);
    }
    if (run.event && run.event !== "workflow_dispatch") {
      errors.push(`${job.id}.recentManualDispatchRuns.event must be workflow_dispatch.`);
    }
    if (run.branch && run.branch !== "main") {
      errors.push(`${job.id}.recentManualDispatchRuns.branch must be main.`);
    }
    if (run.createdAtUtc && !isIsoUtc(run.createdAtUtc)) {
      errors.push(`${job.id}.recentManualDispatchRuns.createdAtUtc must be ISO UTC.`);
    }
    if (typeof run.runnerNamePresent !== "boolean") {
      errors.push(`${job.id}.recentManualDispatchRuns.runnerNamePresent must be boolean.`);
    }
  }
}
for (const id of expectedJobs.keys()) {
  if (!seen.has(id)) errors.push(`jobs missing ${id}.`);
}

const allPass = jobs.every((job) => job.providerState === "PASS");
if (allPass) {
  if (data.status !== "PASS") errors.push("status must be PASS when every providerState is PASS.");
} else {
  if (data.status !== "BLOCKED_PROVIDER_STATE") {
    errors.push("status must be BLOCKED_PROVIDER_STATE while any providerState is not PASS.");
  }
  const pending = Array.isArray(data.pendingExternalEvidence)
    ? data.pendingExternalEvidence
    : [];
  for (const fragment of [
    "default branch",
    "scheduled runs complete successfully",
    "manual dispatch fallback runs complete successfully",
    "missed-run alert evidence",
  ]) {
    if (!pending.some((item) => String(item).includes(fragment))) {
      errors.push(`pendingExternalEvidence must include ${fragment}.`);
    }
  }
}

if (!Array.isArray(data.notes) || data.notes.length < 2) {
  errors.push("notes must explain provider evidence scope.");
}

if (errors.length > 0) {
  console.error(`Scheduler provider state validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Scheduler provider state validation passed for ${targetPath}.`);
