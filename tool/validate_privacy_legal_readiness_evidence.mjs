#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const defaultPath = "release/legal/privacy-legal-readiness-evidence.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredChecks = new Set([
  "PUBLIC-PRIVACY-POLICY",
  "PUBLIC-TERMS",
  "ANDROID-DATA-SAFETY",
  "APPLE-PRIVACY-LABELS",
  "ACCOUNT-DELETION",
  "DATA-RETENTION",
  "DATA-EXPORT-ACCESS",
  "SUPPORT-ACCESS",
  "NO-BETTING-NO-CASHOUT",
  "OFF-PLATFORM-PAYMENTS",
  "SDK-DATA-INVENTORY",
  "HUMAN-LEGAL-REVIEW",
]);
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

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the release build, tag, or commit.");
  }
  if (data.environment !== "production") errors.push('environment must be "production".');

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
    if (!allowedStatuses.has(check?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }
    if (check.status !== "PASS") {
      errors.push(`${label} is ${check.status}; privacy/legal readiness requires PASS.`);
      continue;
    }
    if (!refsArePresent(check.evidenceRefs)) {
      errors.push(`${label}.evidenceRefs must include at least one evidence reference for PASS.`);
    } else {
      for (const ref of check.evidenceRefs) {
        if (!repoRefExists(ref)) errors.push(`${label}.evidenceRefs contains missing repo ref: ${ref}.`);
      }
    }
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
