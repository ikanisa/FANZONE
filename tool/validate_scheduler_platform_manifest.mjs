#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/operations/scheduler-platform-cron-manifest.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._~+/\-]+=*)/;

const expectedJobs = new Map([
  [
    "settle-match-pools",
    {
      command: "tool/run_supabase_cron_job.sh settle-match-pools",
      edgeFunction: "settle-match-pools",
      targetPath: "/functions/v1/settle-match-pools",
      scheduleExpression: "every 15 minutes",
      cronExpression: "*/15 * * * *",
      maxLagMinutes: 45,
      payloadFragments: ['"limit":50'],
    },
  ],
  [
    "dispatch-match-alerts",
    {
      command: "tool/run_supabase_cron_job.sh dispatch-match-alerts",
      edgeFunction: "dispatch-match-alerts",
      targetPath: "/functions/v1/dispatch-match-alerts",
      scheduleExpression: "every 5 minutes",
      cronExpression: "*/5 * * * *",
      maxLagMinutes: 20,
      payloadFragments: ["{}"],
    },
  ],
  [
    "sync-livescore-football",
    {
      command: "tool/run_supabase_cron_job.sh sync-livescore-football",
      edgeFunction: "sync-livescore-football",
      targetPath: "/functions/v1/sync-livescore-football",
      scheduleExpression: "hourly during active football windows",
      cronExpression: "7 * * * *",
      maxLagMinutes: 180,
      payloadFragments: [
        '"resource_id":"livescore_world_cup_2026"',
        '"apply":true',
        '"include_scoreboard":true',
        '"limit":200',
        '"delay_ms":750',
      ],
    },
  ],
]);

const requiredRefs = [
  "supabase/migrations/20260606170000_scheduler_run_history_and_missed_run_alerts.sql",
  "tool/run_supabase_cron_job.sh",
  "tool/scheduler_payload_smoke.sh",
  "release/operations/scheduler-post-deploy-audit-smoke-evidence.json",
  "docs/operations/scheduler-observability.md",
];

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoUtc(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function readText(ref) {
  return fs.readFileSync(repoPath(ref), "utf8");
}

function payloadText(value) {
  return JSON.stringify(value);
}

function requireFragment(errors, label, text, fragment) {
  if (!text.includes(fragment)) errors.push(`${label} must include ${fragment}.`);
}

if (!fs.existsSync(absolutePath)) {
  console.error(`Scheduler platform manifest validation failed for ${targetPath}:`);
  console.error("- manifest file does not exist.");
  process.exit(1);
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Scheduler platform manifest validation failed for ${targetPath}:`);
  console.error("- manifest appears to contain a live credential pattern.");
  process.exit(1);
}

let data;
try {
  data = JSON.parse(raw);
} catch (error) {
  console.error(`Scheduler platform manifest validation failed for ${targetPath}:`);
  console.error(`- could not parse JSON: ${error.message}`);
  process.exit(1);
}

const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoUtc(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked FANZONE Supabase project.");
}
if (data.status !== "PASS_WITH_PENDING_PROVIDER_ACTIVATION") {
  errors.push("status must be PASS_WITH_PENDING_PROVIDER_ACTIVATION.");
}
if (data.provider !== "supabase_edge_cron") {
  errors.push("provider must be supabase_edge_cron.");
}
if (data.timezone !== "UTC") errors.push("timezone must be UTC.");
if (data.secretName !== "CRON_SECRET") {
  errors.push("secretName must be CRON_SECRET.");
}
if (!String(data.scope || "").includes("platform-cron manifest")) {
  errors.push("scope must describe platform-cron manifest.");
}

const jobs = Array.isArray(data.jobs) ? data.jobs : [];
if (jobs.length !== expectedJobs.size) {
  errors.push(`jobs must include exactly ${expectedJobs.size} scheduler jobs.`);
}
const seen = new Set();
for (const job of jobs) {
  const expected = expectedJobs.get(job?.id);
  if (!expected) {
    errors.push(`${job?.id || "unknown job"} is not an expected scheduler job.`);
    continue;
  }
  if (seen.has(job.id)) errors.push(`${job.id} is duplicated.`);
  seen.add(job.id);

  for (const [key, expectedValue] of Object.entries(expected)) {
    if (key === "payloadFragments") continue;
    if (job[key] !== expectedValue) {
      errors.push(`${job.id}.${key} must be ${expectedValue}.`);
    }
  }
  if (job.missedRunSeverity !== "high") {
    errors.push(`${job.id}.missedRunSeverity must be high.`);
  }
  if (job.activationStatus !== "PENDING_PROVIDER_ACTIVATION") {
    errors.push(`${job.id}.activationStatus must stay PENDING_PROVIDER_ACTIVATION until provider proof exists.`);
  }
  const serializedPayload = payloadText(job.payload);
  for (const fragment of expected.payloadFragments) {
    requireFragment(errors, `${job.id}.payload`, serializedPayload, fragment);
  }
}
for (const id of expectedJobs.keys()) {
  if (!seen.has(id)) errors.push(`jobs missing ${id}.`);
}

const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
for (const ref of requiredRefs) {
  if (!refs.includes(ref)) errors.push(`evidenceRefs must include ${ref}.`);
  if (!fs.existsSync(repoPath(ref))) {
    errors.push(`evidence ref missing: ${ref}.`);
  }
}

const migration = readText(
  "supabase/migrations/20260606170000_scheduler_run_history_and_missed_run_alerts.sql",
);
const runner = readText("tool/run_supabase_cron_job.sh");
const docs = readText("docs/operations/scheduler-observability.md");
for (const [id, expected] of expectedJobs) {
  for (const fragment of [
    id,
    expected.command,
    expected.scheduleExpression,
    String(expected.maxLagMinutes),
  ]) {
    requireFragment(errors, "scheduler expectation migration", migration, fragment);
  }
  requireFragment(errors, "cron runner", runner, id);
  requireFragment(errors, "scheduler observability docs", docs, id);
}
for (const fragment of [
  "CRON_SECRET",
  "missed-run alert",
  "provider scheduler history",
]) {
  requireFragment(errors, "scheduler observability docs", docs, fragment);
}

const pending = Array.isArray(data.pendingExternalEvidence)
  ? data.pendingExternalEvidence
  : [];
for (const fragment of [
  "provider schedules",
  "provider scheduler run history",
  "missed-run alert evidence",
]) {
  if (!pending.some((item) => String(item).includes(fragment))) {
    errors.push(`pendingExternalEvidence must include ${fragment}.`);
  }
}

if (errors.length > 0) {
  console.error(`Scheduler platform manifest validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Scheduler platform manifest validation passed for ${targetPath}.`);
