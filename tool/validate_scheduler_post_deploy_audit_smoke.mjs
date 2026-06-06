#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath = process.argv[2] ||
  "release/operations/scheduler-post-deploy-audit-smoke-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._~+/\-]+=*)/;

const requiredJobs = new Map([
  ["settle-match-pools", "tool/run_supabase_cron_job.sh settle-match-pools"],
  ["dispatch-match-alerts", "tool/run_supabase_cron_job.sh dispatch-match-alerts"],
  ["sync-livescore-football", "tool/run_supabase_cron_job.sh sync-livescore-football"],
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) &&
    Number.isFinite(Date.parse(value)) &&
    value.includes("T") &&
    value.endsWith("Z");
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Scheduler post-deploy audit smoke validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match linked FANZONE Supabase project.");
}
if (data.supabaseUrl !== "https://kjuhheobmdvjwgnzlcwx.supabase.co") {
  errors.push("supabaseUrl must be the linked FANZONE Supabase URL.");
}
if (!String(data.scope || "").includes("Post-deploy scheduler Edge smoke")) {
  errors.push("scope must describe post-deploy scheduler Edge smoke.");
}
if (data.secretValuesPrinted !== false) {
  errors.push("secretValuesPrinted must be false.");
}
if (!hasText(data.credentialHandling?.credentialSource)) {
  errors.push("credentialHandling.credentialSource is required.");
}
if (
  !String(data.credentialHandling?.notes || "").includes(
    "not written to tracked files or evidence",
  )
) {
  errors.push("credentialHandling.notes must state credentials are not written to evidence.");
}

const jobs = Array.isArray(data.jobs) ? data.jobs : [];
const jobsById = new Map(
  jobs.filter((job) => hasText(job?.id)).map((job) => [job.id, job]),
);
for (const [jobId, command] of requiredJobs) {
  const job = jobsById.get(jobId);
  if (!job) {
    errors.push(`jobs missing ${jobId}.`);
    continue;
  }
  if (job.command !== command) {
    errors.push(`${jobId}.command must be ${command}.`);
  }
  if (job.status !== "PASS") {
    errors.push(`${jobId}.status must be PASS.`);
  }
  if (job.httpStatus !== 200) {
    errors.push(`${jobId}.httpStatus must be 200.`);
  }
  if (job.auditTracked !== true) {
    errors.push(`${jobId}.auditTracked must be true.`);
  }
  const audit = job.observed?.audit;
  if (!audit || audit.status !== "tracked" || !hasText(audit.run_id)) {
    errors.push(`${jobId}.observed.audit must include tracked run_id.`);
  }
}

const settle = jobsById.get("settle-match-pools")?.observed || {};
if (!Number.isInteger(settle.limit) || settle.limit !== 50) {
  errors.push("settle-match-pools.observed.limit must be 50.");
}
if (!Number.isInteger(settle.settledPools) || settle.settledPools < 0) {
  errors.push("settle-match-pools.observed.settledPools must be non-negative.");
}

const alerts = jobsById.get("dispatch-match-alerts")?.observed || {};
for (const key of ["kickoffSent", "goalSent", "resultSent", "dispatchRowsWritten"]) {
  if (!Number.isInteger(alerts[key]) || alerts[key] < 0) {
    errors.push(`dispatch-match-alerts.observed.${key} must be non-negative.`);
  }
}
if (!Array.isArray(alerts.errors) || alerts.errors.length !== 0) {
  errors.push("dispatch-match-alerts.observed.errors must be an empty array.");
}

const liveScore = jobsById.get("sync-livescore-football")?.observed || {};
if (liveScore.resourceId !== "livescore_world_cup_2026") {
  errors.push("sync-livescore-football.observed.resourceId must be livescore_world_cup_2026.");
}
for (const key of [
  "rows",
  "stagedRows",
  "receivedRows",
  "needsReviewRows",
  "appliedRows",
  "liveStateUpdatedRows",
]) {
  if (!Number.isInteger(liveScore[key]) || liveScore[key] < 0) {
    errors.push(`sync-livescore-football.observed.${key} must be non-negative.`);
  }
}
if (!hasText(liveScore.syncRunId)) {
  errors.push("sync-livescore-football.observed.syncRunId is required.");
}

const remaining = Array.isArray(data.remainingOperationsGates)
  ? data.remainingOperationsGates.join("\n")
  : "";
for (const fragment of [
  "Provider scheduler history evidence",
  "Delivered missed-run alert evidence",
  "Operations owner",
]) {
  if (!remaining.includes(fragment)) {
    errors.push(`remainingOperationsGates must include ${fragment}.`);
  }
}

if (errors.length > 0) {
  console.error(`Scheduler post-deploy audit smoke validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Scheduler post-deploy audit smoke validation passed for ${targetPath}.`);
