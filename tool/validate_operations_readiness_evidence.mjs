#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/operations/operations-readiness-evidence.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredSchedulerJobs = new Set([
  "settle-match-pools",
  "dispatch-match-alerts",
  "sync-livescore-football",
]);
const requiredSchedulerCommands = new Map([
  ["settle-match-pools", "tool/run_supabase_cron_job.sh settle-match-pools"],
  ["dispatch-match-alerts", "tool/run_supabase_cron_job.sh dispatch-match-alerts"],
  ["sync-livescore-football", "tool/run_supabase_cron_job.sh sync-livescore-football"],
]);
const requiredSurfaces = new Set([
  "Flutter app",
  "Website PWA",
  "Admin PWA",
  "Bars/Venue PWA",
  "TV PWA",
  "Supabase Edge Functions",
  "Supabase database",
  "Scheduler",
]);
const requiredSignals = new Set([
  "auth",
  "ordering",
  "manual-payments",
  "fet-ledger",
  "pools",
  "rewards",
  "admin",
  "tv-display",
  "edge-functions",
  "scheduler",
  "database-health",
  "push-notifications",
]);
const requiredIncidentChecks = new Set([
  "OWNERS-ESCALATION",
  "ROLLBACK-TAG",
  "DATABASE-RESTORE-PLAN",
  "RUNBOOK-REVIEW",
  "POST-DEPLOY-WATCH",
  "SAMPLE-ALERT-TEST",
]);
const requiredEvidenceBundleFields = [
  "schedulerEvidenceBundleRoot",
  "observabilityEvidenceBundleRoot",
  "incidentEvidenceBundleRoot",
];
const requiredEnvironmentUrls = [
  "websiteUrl",
  "adminUrl",
  "venuePortalUrl",
  "tvDisplayUrl",
];
const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  if (!hasText(value)) return false;
  return Number.isFinite(Date.parse(value)) && value.includes("T") && value.endsWith("Z");
}

function refsArePresent(value) {
  return Array.isArray(value) && value.length > 0 && value.every(hasText);
}

function repoRefExists(ref) {
  if (!hasText(ref)) return false;
  if (/^https?:\/\//.test(ref)) return true;
  return fs.existsSync(path.resolve(process.cwd(), ref));
}

function gitCommitExists(value) {
  if (!hasText(value) || value === "TBD") return false;
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

function validateEvidenceRefs(label, fieldName, refs, errors) {
  if (!refsArePresent(refs)) {
    errors.push(`${label}.${fieldName} must include evidence refs for PASS.`);
    return;
  }
  for (const ref of refs) {
    if (!repoRefExists(ref)) {
      errors.push(`${label}.${fieldName} contains missing repo ref: ${ref}.`);
    }
  }
}

function validateRequiredSet(items, requiredIds, label, errors) {
  if (!Array.isArray(items) || items.length === 0) {
    errors.push(`${label} must be a non-empty array.`);
    return new Set();
  }

  const seen = new Set();
  for (const [index, item] of items.entries()) {
    const itemLabel = item?.id || `${label}[${index}]`;
    if (!requiredIds.has(item?.id)) {
      errors.push(`${itemLabel} is not a required ${label} id.`);
    } else if (seen.has(item.id)) {
      errors.push(`${itemLabel} is duplicated.`);
    } else {
      seen.add(item.id);
    }
    if (!allowedStatuses.has(item?.status)) {
      errors.push(`${itemLabel} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
    }
  }

  for (const id of requiredIds) {
    if (!seen.has(id)) errors.push(`Missing ${label} ${id}.`);
  }

  return seen;
}

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the release build, tag, or commit.");
  }
  if (!gitCommitExists(data.sourceCommit)) {
    errors.push("sourceCommit must name an existing git commit for the release candidate.");
  }

  const environment = data.environment || {};
  if (environment.name !== "production") errors.push('environment.name must be "production".');
  if (!hasText(environment.supabaseProjectRef) || environment.supabaseProjectRef === "TBD") {
    errors.push("environment.supabaseProjectRef must name the tested Supabase project ref.");
  }
  for (const key of requiredEnvironmentUrls) {
    if (!/^https:\/\/.+/.test(environment[key] || "")) {
      errors.push(`environment.${key} must be an https URL.`);
    }
  }

  const evidenceWindow = data.evidenceWindow || {};
  if (!isIsoDateTime(evidenceWindow.startedAtUtc)) {
    errors.push("evidenceWindow.startedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (!isIsoDateTime(evidenceWindow.endedAtUtc)) {
    errors.push("evidenceWindow.endedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (
    isIsoDateTime(evidenceWindow.startedAtUtc) &&
    isIsoDateTime(evidenceWindow.endedAtUtc) &&
    Date.parse(evidenceWindow.endedAtUtc) <= Date.parse(evidenceWindow.startedAtUtc)
  ) {
    errors.push("evidenceWindow.endedAtUtc must be later than evidenceWindow.startedAtUtc.");
  }
  for (const key of requiredEvidenceBundleFields) {
    if (!hasText(evidenceWindow[key]) || evidenceWindow[key].includes("TBD")) {
      errors.push(`evidenceWindow.${key} must name a durable evidence bundle root.`);
    } else if (!repoRefExists(evidenceWindow[key])) {
      errors.push(`evidenceWindow.${key} must exist as a repo path or be a URL.`);
    }
  }

  const signOff = data.signOff || {};
  if (!hasText(signOff.operationsOwner)) errors.push("signOff.operationsOwner is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!hasText(signOff.incidentCommander)) errors.push("signOff.incidentCommander is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  validateRequiredSet(data.schedulerJobs, requiredSchedulerJobs, "schedulerJobs", errors);
  for (const job of data.schedulerJobs || []) {
    const label = job?.id || "schedulerJobs[]";
    if (job?.status !== "PASS") {
      errors.push(`${label} is ${job?.status || "missing"}; scheduler readiness requires PASS.`);
      continue;
    }
    if (requiredSchedulerCommands.has(job?.id) && job.command !== requiredSchedulerCommands.get(job.id)) {
      errors.push(`${label}.command must be ${requiredSchedulerCommands.get(job.id)}.`);
    }
    for (const field of ["provider", "scheduleExpression", "timezone", "owner", "backupOwner"]) {
      if (!hasText(job[field])) errors.push(`${label}.${field} is required for PASS.`);
    }
    for (const field of ["smokeEvidenceRefs", "historyEvidenceRefs", "missedRunAlertEvidenceRefs"]) {
      validateEvidenceRefs(label, field, job[field], errors);
    }
  }

  validateRequiredSet(data.observabilitySurfaces, requiredSurfaces, "observabilitySurfaces", errors);
  for (const surface of data.observabilitySurfaces || []) {
    const label = surface?.id || "observabilitySurfaces[]";
    if (surface?.status !== "PASS") {
      errors.push(`${label} is ${surface?.status || "missing"}; observability surfaces require PASS.`);
      continue;
    }
    for (const field of ["telemetryProvider", "owner", "backupOwner"]) {
      if (!hasText(surface[field])) errors.push(`${label}.${field} is required for PASS.`);
    }
    for (const field of ["dashboardRefs", "alertRouteRefs"]) {
      validateEvidenceRefs(label, field, surface[field], errors);
    }
  }

  validateRequiredSet(data.observabilitySignals, requiredSignals, "observabilitySignals", errors);
  for (const signal of data.observabilitySignals || []) {
    const label = signal?.id || "observabilitySignals[]";
    if (signal?.status !== "PASS") {
      errors.push(`${label} is ${signal?.status || "missing"}; observability signals require PASS.`);
      continue;
    }
    if (!hasText(signal.owner)) errors.push(`${label}.owner is required for PASS.`);
    for (const field of ["dashboardRefs", "alertRouteRefs"]) {
      validateEvidenceRefs(label, field, signal[field], errors);
    }
  }

  validateRequiredSet(data.incidentReadinessChecks, requiredIncidentChecks, "incidentReadinessChecks", errors);
  for (const check of data.incidentReadinessChecks || []) {
    const label = check?.id || "incidentReadinessChecks[]";
    if (check?.status !== "PASS") {
      errors.push(`${label} is ${check?.status || "missing"}; incident and rollback readiness requires PASS.`);
      continue;
    }
    validateEvidenceRefs(label, "evidenceRefs", check.evidenceRefs, errors);
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Operations readiness evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Operations readiness evidence validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Operations readiness evidence validation passed for ${targetPath}.`);
