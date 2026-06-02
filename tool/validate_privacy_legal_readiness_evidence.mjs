#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/legal/privacy-legal-readiness-evidence.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredCheckSurfaces = new Map([
  ["PUBLIC-PRIVACY-POLICY", "All"],
  ["PUBLIC-TERMS", "All"],
  ["ANDROID-DATA-SAFETY", "Flutter app"],
  ["APPLE-PRIVACY-LABELS", "Flutter app"],
  ["ACCOUNT-DELETION", "All"],
  ["DATA-RETENTION", "All"],
  ["DATA-EXPORT-ACCESS", "All"],
  ["SUPPORT-ACCESS", "Admin PWA"],
  ["NO-BETTING-NO-CASHOUT", "All"],
  ["OFF-PLATFORM-PAYMENTS", "All"],
  ["SDK-DATA-INVENTORY", "Flutter app"],
  ["HUMAN-LEGAL-REVIEW", "All"],
]);
const requiredChecks = new Set(requiredCheckSurfaces.keys());
const requiredGuidanceRefs = new Set([
  "https://support.google.com/googleplay/android-developer/answer/10787469",
  "https://support.google.com/googleplay/android-developer/answer/13327111",
  "https://developer.apple.com/app-store/app-privacy-details/",
]);
const requiredPublicUrls = [
  "privacyPolicyUrl",
  "termsUrl",
  "supportUrl",
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

function validateEvidenceRefs(label, refs, errors) {
  if (!refsArePresent(refs)) {
    errors.push(`${label}.evidenceRefs must include at least one evidence reference for PASS.`);
    return;
  }
  for (const ref of refs) {
    if (!repoRefExists(ref)) errors.push(`${label}.evidenceRefs contains missing repo ref: ${ref}.`);
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
  for (const key of requiredEnvironmentUrls) {
    if (!/^https:\/\/.+/.test(environment[key] || "")) {
      errors.push(`environment.${key} must be an https URL.`);
    }
  }

  const reviewWindow = data.reviewWindow || {};
  if (!isIsoDateTime(reviewWindow.startedAtUtc)) {
    errors.push("reviewWindow.startedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (!isIsoDateTime(reviewWindow.completedAtUtc)) {
    errors.push("reviewWindow.completedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (
    isIsoDateTime(reviewWindow.startedAtUtc) &&
    isIsoDateTime(reviewWindow.completedAtUtc) &&
    Date.parse(reviewWindow.completedAtUtc) <= Date.parse(reviewWindow.startedAtUtc)
  ) {
    errors.push("reviewWindow.completedAtUtc must be later than reviewWindow.startedAtUtc.");
  }
  if (!hasText(reviewWindow.evidenceBundleRoot) || reviewWindow.evidenceBundleRoot.includes("TBD")) {
    errors.push("reviewWindow.evidenceBundleRoot must name the durable privacy/legal evidence bundle root.");
  } else if (!repoRefExists(reviewWindow.evidenceBundleRoot)) {
    errors.push("reviewWindow.evidenceBundleRoot must exist as a repo path or be a URL.");
  }

  const signOff = data.signOff || {};
  if (!hasText(signOff.complianceOwner)) errors.push("signOff.complianceOwner is required.");
  if (!hasText(signOff.legalReviewer)) errors.push("signOff.legalReviewer is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  if (!Array.isArray(data.officialGuidanceRefs)) {
    errors.push("officialGuidanceRefs must be an array.");
  } else {
    for (const ref of requiredGuidanceRefs) {
      if (!data.officialGuidanceRefs.includes(ref)) {
        errors.push(`officialGuidanceRefs must include ${ref}.`);
      }
    }
  }

  for (const key of requiredPublicUrls) {
    const value = data.publicUrls?.[key];
    if (!/^https:\/\/.+/.test(value || "")) {
      errors.push(`publicUrls.${key} must be an https URL.`);
    }
  }

  if (!Array.isArray(data.checks) || data.checks.length === 0) {
    errors.push("checks must be a non-empty array.");
    return errors;
  }

  const seen = new Set();
  for (const [index, check] of data.checks.entries()) {
    const label = check?.id || `checks[${index}]`;
    if (!requiredChecks.has(check?.id)) {
      errors.push(`${label} is not a required privacy/legal readiness check.`);
    } else if (seen.has(check.id)) {
      errors.push(`${label} is duplicated.`);
    } else {
      seen.add(check.id);
    }

    if (!hasText(check?.surface)) errors.push(`${label}.surface is required.`);
    if (requiredCheckSurfaces.has(check?.id) && check.surface !== requiredCheckSurfaces.get(check.id)) {
      errors.push(`${label}.surface must be ${requiredCheckSurfaces.get(check.id)}.`);
    }
    if (!allowedStatuses.has(check?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }
    if (check.status !== "PASS") {
      errors.push(`${label} is ${check.status}; privacy/legal readiness requires PASS.`);
      continue;
    }
    validateEvidenceRefs(label, check.evidenceRefs, errors);
  }

  for (const id of requiredChecks) {
    if (!seen.has(id)) errors.push(`Missing required check ${id}.`);
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Privacy/legal readiness validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Privacy/legal readiness validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Privacy/legal readiness validation passed for ${targetPath}.`);
