#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/operations/cron-smoke-evidence-20260606T043304Z.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredJobs = new Map([
  ["settle-match-pools", "tool/run_supabase_cron_job.sh settle-match-pools"],
  ["dispatch-match-alerts", "tool/run_supabase_cron_job.sh dispatch-match-alerts"],
  ["sync-livescore-football", "tool/run_supabase_cron_job.sh sync-livescore-football"],
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
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
  console.error(`Cron smoke evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}
if (!String(data.scope || "").includes("Credentialed production cron smoke")) {
  errors.push("scope must describe credentialed production cron smoke.");
}
if (data.secretValuesPrinted !== false) {
  errors.push("secretValuesPrinted must be false.");
}
if (data.credentialHandling?.supabaseCronSecret !== "ROTATED") {
  errors.push("credentialHandling.supabaseCronSecret must be ROTATED.");
}
if (data.credentialHandling?.githubActionsCronSecret !== "ROTATED") {
  errors.push("credentialHandling.githubActionsCronSecret must be ROTATED.");
}
if (!String(data.credentialHandling?.notes || "").includes("not written to tracked files")) {
  errors.push("credentialHandling.notes must state that the secret was not written to tracked files.");
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
  if (typeof job.observed !== "object" || job.observed === null) {
    errors.push(`${jobId}.observed must include a response summary.`);
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
if (liveScore.rows !== liveScore.receivedRows || liveScore.rows !== liveScore.stagedRows) {
  errors.push("sync-livescore-football observed row counts must agree for rows, receivedRows, and stagedRows.");
}
if (!hasText(liveScore.syncRunId)) {
  errors.push("sync-livescore-football.observed.syncRunId is required.");
}

const remaining = Array.isArray(data.remainingOperationsGates)
  ? data.remainingOperationsGates.join("\n")
  : "";
for (const fragment of [
  "Scheduler provider history evidence",
  "Missed-run alert evidence",
  "Operations owner",
]) {
  if (!remaining.includes(fragment)) {
    errors.push(`remainingOperationsGates must include ${fragment}.`);
  }
}

if (errors.length > 0) {
  console.error(`Cron smoke evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Cron smoke evidence validation passed for ${targetPath}.`);
