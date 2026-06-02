#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/performance/load-reliability-evidence.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredScenarioSurfaces = new Map([
  ["ORDERING-SUBMIT", "Flutter app"],
  ["PAYMENT-HANDOFF", "Flutter app"],
  ["STAFF-CALL-ACK", "Bars/Venue PWA"],
  ["FET-LEDGER-ACCRUAL", "Supabase database"],
  ["REWARD-REDEMPTION", "Flutter app"],
  ["ENTERTAINMENT-ENTRY", "Flutter app"],
  ["ENTERTAINMENT-SETTLEMENT", "Supabase Edge Functions"],
  ["ADMIN-LIVE-QUEUE", "Admin PWA"],
  ["TV-DISPLAY-RECOVERY", "TV PWA"],
  ["REALTIME-PROPAGATION", "All surfaces"],
  ["EDGE-FUNCTION-ERROR-BUDGET", "Supabase Edge Functions"],
  ["DATABASE-RLS-UNDER-LOAD", "Supabase database"],
]);
const requiredScenarioIds = new Set(requiredScenarioSurfaces.keys());
const requiredSurfaces = new Set([
  "Flutter app",
  "Bars/Venue PWA",
  "Admin PWA",
  "TV PWA",
  "Supabase Edge Functions",
  "Supabase database",
  "All surfaces",
]);
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

function isPositiveNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function isNonNegativeNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
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

function validateThresholds(thresholds, errors) {
  const requiredPositive = [
    "maxErrorRatePercent",
    "minAvailabilityPercent",
    "maxP95LatencyMs",
    "maxP99LatencyMs",
    "rollbackIfErrorRatePercentExceeds",
    "rollbackIfP95LatencyMsExceeds",
    "rollbackIfAvailabilityPercentBelow",
  ];

  for (const key of requiredPositive) {
    if (!isPositiveNumber(thresholds?.[key])) errors.push(`thresholds.${key} must be a positive number.`);
  }

  if (
    isPositiveNumber(thresholds?.maxP95LatencyMs) &&
    isPositiveNumber(thresholds?.maxP99LatencyMs) &&
    thresholds.maxP95LatencyMs > thresholds.maxP99LatencyMs
  ) {
    errors.push("thresholds.maxP95LatencyMs must be less than or equal to maxP99LatencyMs.");
  }

  if (
    isPositiveNumber(thresholds?.minAvailabilityPercent) &&
    (thresholds.minAvailabilityPercent > 100 || thresholds.minAvailabilityPercent < 90)
  ) {
    errors.push("thresholds.minAvailabilityPercent must be between 90 and 100.");
  }
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

  const testWindow = data.testWindow || {};
  if (!isIsoDateTime(testWindow.startedAtUtc)) {
    errors.push("testWindow.startedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (!isIsoDateTime(testWindow.endedAtUtc)) {
    errors.push("testWindow.endedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (
    isIsoDateTime(testWindow.startedAtUtc) &&
    isIsoDateTime(testWindow.endedAtUtc) &&
    Date.parse(testWindow.endedAtUtc) <= Date.parse(testWindow.startedAtUtc)
  ) {
    errors.push("testWindow.endedAtUtc must be later than testWindow.startedAtUtc.");
  }
  if (!isPositiveNumber(testWindow.durationMinutes)) {
    errors.push("testWindow.durationMinutes must be a positive number.");
  }
  if (!hasText(testWindow.tool) || testWindow.tool === "TBD") {
    errors.push("testWindow.tool is required.");
  }
  if (!/^https:\/\/.+/.test(testWindow.targetBaseUrl || "")) {
    errors.push("testWindow.targetBaseUrl must be an https URL.");
  }
  if (!hasText(testWindow.evidenceBundleRoot) || testWindow.evidenceBundleRoot.includes("TBD")) {
    errors.push("testWindow.evidenceBundleRoot must name the durable load/reliability evidence bundle root.");
  } else if (!repoRefExists(testWindow.evidenceBundleRoot)) {
    errors.push("testWindow.evidenceBundleRoot must exist as a repo path or be a URL.");
  }

  validateThresholds(data.thresholds || {}, errors);

  const signOff = data.signOff || {};
  if (!hasText(signOff.performanceOwner)) errors.push("signOff.performanceOwner is required.");
  if (!hasText(signOff.operationsOwner)) errors.push("signOff.operationsOwner is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  if (!Array.isArray(data.scenarios) || data.scenarios.length === 0) {
    errors.push("scenarios must be a non-empty array.");
    return errors;
  }

  const seen = new Set();
  for (const [index, scenario] of data.scenarios.entries()) {
    const label = scenario?.id || `scenarios[${index}]`;
    if (!requiredScenarioIds.has(scenario?.id)) {
      errors.push(`${label} is not a required load/reliability scenario.`);
    } else if (seen.has(scenario.id)) {
      errors.push(`${label} is duplicated.`);
    } else {
      seen.add(scenario.id);
    }

    if (!requiredSurfaces.has(scenario?.surface)) {
      errors.push(`${label}.surface must be one of the required production surfaces.`);
    }
    if (
      requiredScenarioSurfaces.has(scenario?.id) &&
      scenario.surface !== requiredScenarioSurfaces.get(scenario.id)
    ) {
      errors.push(`${label}.surface must be ${requiredScenarioSurfaces.get(scenario.id)}.`);
    }
    if (!allowedStatuses.has(scenario?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }
    if (scenario.status !== "PASS") {
      errors.push(`${label} is ${scenario.status}; load/reliability readiness requires PASS.`);
      continue;
    }

    for (const field of ["targetP95LatencyMs", "targetP99LatencyMs", "maxErrorRatePercent"]) {
      if (!isPositiveNumber(scenario[field])) errors.push(`${label}.${field} must be a positive number for PASS.`);
    }
    for (const field of ["observedP95LatencyMs", "observedP99LatencyMs", "observedErrorRatePercent"]) {
      if (!isNonNegativeNumber(scenario[field])) {
        errors.push(`${label}.${field} must be a non-negative number for PASS.`);
      }
    }
    if (!Number.isInteger(scenario.sampleSize) || scenario.sampleSize <= 0) {
      errors.push(`${label}.sampleSize must be a positive integer for PASS.`);
    }

    if (
      isPositiveNumber(scenario.targetP95LatencyMs) &&
      isPositiveNumber(scenario.targetP99LatencyMs) &&
      scenario.targetP95LatencyMs > scenario.targetP99LatencyMs
    ) {
      errors.push(`${label}.targetP95LatencyMs must be less than or equal to targetP99LatencyMs.`);
    }
    if (
      isNonNegativeNumber(scenario.observedP95LatencyMs) &&
      isPositiveNumber(scenario.targetP95LatencyMs) &&
      scenario.observedP95LatencyMs > scenario.targetP95LatencyMs
    ) {
      errors.push(`${label}.observedP95LatencyMs exceeds targetP95LatencyMs.`);
    }
    if (
      isNonNegativeNumber(scenario.observedP99LatencyMs) &&
      isPositiveNumber(scenario.targetP99LatencyMs) &&
      scenario.observedP99LatencyMs > scenario.targetP99LatencyMs
    ) {
      errors.push(`${label}.observedP99LatencyMs exceeds targetP99LatencyMs.`);
    }
    if (
      isNonNegativeNumber(scenario.observedErrorRatePercent) &&
      isPositiveNumber(scenario.maxErrorRatePercent) &&
      scenario.observedErrorRatePercent > scenario.maxErrorRatePercent
    ) {
      errors.push(`${label}.observedErrorRatePercent exceeds maxErrorRatePercent.`);
    }

    if (!refsArePresent(scenario.evidenceRefs)) {
      errors.push(`${label}.evidenceRefs must include at least one evidence reference for PASS.`);
    } else {
      for (const ref of scenario.evidenceRefs) {
        if (!repoRefExists(ref)) errors.push(`${label}.evidenceRefs contains missing repo ref: ${ref}.`);
      }
    }
  }

  for (const id of requiredScenarioIds) {
    if (!seen.has(id)) errors.push(`Missing required scenario ${id}.`);
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Load/reliability evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Load/reliability evidence validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Load/reliability evidence validation passed for ${targetPath}.`);
