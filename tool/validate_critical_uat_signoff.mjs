#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/qa/critical-user-flow-uat.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredFlowsById = new Map([
  ["MOB-AUTH-001", "Flutter app"],
  ["MOB-ORDER-001", "Flutter app"],
  ["MOB-WALLET-001", "Flutter app"],
  ["MOB-POOL-001", "Flutter app"],
  ["MOB-SETTLEMENT-001", "Flutter app"],
  ["VENUE-AUTH-001", "Bars/Venue PWA"],
  ["VENUE-ORDER-001", "Bars/Venue PWA"],
  ["VENUE-MENU-001", "Bars/Venue PWA"],
  ["VENUE-REWARDS-001", "Bars/Venue PWA"],
  ["VENUE-POOL-001", "Bars/Venue PWA"],
  ["VENUE-GAME-001", "Bars/Venue PWA"],
  ["ADMIN-AUTH-001", "Admin PWA"],
  ["ADMIN-OPS-001", "Admin PWA"],
  ["ADMIN-SETTLEMENT-001", "Admin PWA"],
  ["TV-PAIR-001", "TV PWA"],
  ["TV-LIVE-001", "TV PWA"],
  ["BACKEND-ISO-001", "Supabase backend"],
  ["BACKEND-REALTIME-001", "Supabase backend"],
]);
const requiredFlowIds = new Set(requiredFlowsById.keys());
const requiredSurfaces = new Set([
  "Flutter app",
  "Bars/Venue PWA",
  "Admin PWA",
  "TV PWA",
  "Supabase backend",
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

function isIsoDateTime(value) {
  if (typeof value !== "string" || value.trim() === "") return false;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) && value.includes("T") && value.endsWith("Z");
}

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
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

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) {
    errors.push("schemaVersion must be 1.");
  }

  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the release build, tag, or commit.");
  }

  if (!gitCommitExists(data.sourceCommit)) {
    errors.push("sourceCommit must name an existing git commit for the release candidate.");
  }

  const environment = data.environment || {};
  if (!["production", "approved-staging"].includes(environment.name)) {
    errors.push('environment.name must be "production" or "approved-staging".');
  }
  if (!hasText(environment.mobileBuild) || environment.mobileBuild === "TBD") {
    errors.push("environment.mobileBuild must name the tested mobile build.");
  }
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
  if (!Number.isFinite(testWindow.durationMinutes) || testWindow.durationMinutes <= 0) {
    errors.push("testWindow.durationMinutes must be a positive number.");
  }
  if (!hasText(testWindow.evidenceBundleRoot) || testWindow.evidenceBundleRoot.includes("TBD")) {
    errors.push("testWindow.evidenceBundleRoot must name the durable UAT evidence bundle root.");
  } else if (!repoRefExists(testWindow.evidenceBundleRoot)) {
    errors.push("testWindow.evidenceBundleRoot must exist as a repo path or be a URL.");
  }

  const signOff = data.signOff || {};
  if (!hasText(signOff.qaOwner)) errors.push("signOff.qaOwner is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  if (!Array.isArray(data.flows) || data.flows.length === 0) {
    errors.push("flows must be a non-empty array.");
    return errors;
  }

  const seenIds = new Set();
  const seenSurfaces = new Set();

  for (const [index, flow] of data.flows.entries()) {
    const label = flow?.id || `flows[${index}]`;

    if (!hasText(flow?.id)) {
      errors.push(`flows[${index}].id is required.`);
    } else if (!requiredFlowIds.has(flow.id)) {
      errors.push(`${label} is not a required critical UAT flow id.`);
    } else if (seenIds.has(flow.id)) {
      errors.push(`${label} is duplicated.`);
    } else {
      seenIds.add(flow.id);
    }

    if (!requiredSurfaces.has(flow?.surface)) {
      errors.push(`${label} surface must be one of: ${[...requiredSurfaces].join(", ")}.`);
    } else {
      seenSurfaces.add(flow.surface);
    }
    if (requiredFlowsById.has(flow?.id) && flow.surface !== requiredFlowsById.get(flow.id)) {
      errors.push(`${label} must be recorded on ${requiredFlowsById.get(flow.id)}.`);
    }

    if (!hasText(flow?.scenario)) {
      errors.push(`${label} scenario is required.`);
    }

    if (!Array.isArray(flow?.requiredEvidence) || flow.requiredEvidence.length === 0) {
      errors.push(`${label}.requiredEvidence must be a non-empty array.`);
    } else if (!flow.requiredEvidence.every(hasText)) {
      errors.push(`${label}.requiredEvidence must contain non-empty strings.`);
    }

    if (!allowedStatuses.has(flow?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }

    if (flow.status !== "PASS") {
      errors.push(`${label} is ${flow.status}; critical UAT requires PASS.`);
      continue;
    }

    if (!hasText(flow.tester)) {
      errors.push(`${label} tester is required for PASS.`);
    }

    if (!isIsoDateTime(flow.executedAtUtc)) {
      errors.push(`${label} executedAtUtc must be an ISO UTC timestamp ending in Z.`);
    }

    if (!refsArePresent(flow.evidenceRefs)) {
      errors.push(`${label}.evidenceRefs must include at least one evidence reference.`);
    } else {
      for (const ref of flow.evidenceRefs) {
        if (!repoRefExists(ref)) errors.push(`${label}.evidenceRefs contains missing repo ref: ${ref}.`);
      }
    }
  }

  for (const id of requiredFlowIds) {
    if (!seenIds.has(id)) errors.push(`Missing required critical UAT flow ${id}.`);
  }

  for (const surface of requiredSurfaces) {
    if (!seenSurfaces.has(surface)) {
      errors.push(`Missing critical UAT coverage for ${surface}.`);
    }
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Critical UAT sign-off validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Critical UAT sign-off validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Critical UAT sign-off validation passed for ${targetPath}.`);
