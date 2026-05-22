#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const defaultPath = "release/ios/testflight-readiness.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);
const requiredCheckIds = new Set([
  "IOS-CONFIG-001",
  "IOS-FIREBASE-001",
  "IOS-ARCHIVE-001",
  "IOS-IPA-001",
  "IOS-INSTALL-001",
  "IOS-PUSH-001",
  "IOS-TESTFLIGHT-001",
  "IOS-REVIEW-001",
]);

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

function existsFromRepo(value) {
  return hasText(value) && fs.existsSync(path.resolve(process.cwd(), value));
}

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the iOS release build, tag, or commit.");
  }
  if (data.bundleId !== "com.fanzone.fanzone") {
    errors.push('bundleId must be "com.fanzone.fanzone".');
  }
  if (!hasText(data.appleTeamId) || data.appleTeamId === "TBD" || data.appleTeamId === "YOUR_TEAM_ID") {
    errors.push("appleTeamId must be a real Apple Developer Team ID.");
  }
  if (data.apsEnvironment !== "production") {
    errors.push('apsEnvironment must be "production".');
  }

  const signOff = data.signOff || {};
  if (!hasText(signOff.mobileOwner)) errors.push("signOff.mobileOwner is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  if (!Array.isArray(data.checks) || data.checks.length === 0) {
    errors.push("checks must be a non-empty array.");
    return errors;
  }

  const seen = new Set();
  const checksById = new Map();
  for (const [index, check] of data.checks.entries()) {
    const label = check?.id || `checks[${index}]`;
    if (!requiredCheckIds.has(check?.id)) {
      errors.push(`${label} is not a required iOS TestFlight evidence check.`);
    } else if (seen.has(check.id)) {
      errors.push(`${label} is duplicated.`);
    } else {
      seen.add(check.id);
      checksById.set(check.id, check);
    }

    if (!hasText(check?.scenario)) errors.push(`${label} scenario is required.`);
    if (check?.status !== "PASS") {
      errors.push(`${label} is ${check?.status || "missing"}; iOS TestFlight readiness requires PASS.`);
      continue;
    }
    if (!Array.isArray(check.evidenceRefs) || check.evidenceRefs.length === 0) {
      errors.push(`${label} evidenceRefs must include at least one evidence reference.`);
    } else if (!check.evidenceRefs.every(hasText)) {
      errors.push(`${label} evidenceRefs must be non-empty strings.`);
    }
  }

  for (const id of requiredCheckIds) {
    if (!seen.has(id)) errors.push(`Missing required check ${id}.`);
  }

  if (checksById.get("IOS-ARCHIVE-001")?.status === "PASS" && !existsFromRepo(data.archivePath)) {
    errors.push(`archivePath does not exist: ${data.archivePath}`);
  }
  if (checksById.get("IOS-IPA-001")?.status === "PASS" && !existsFromRepo(data.ipaPath)) {
    errors.push(`ipaPath does not exist: ${data.ipaPath}`);
  }

  return errors;
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`iOS TestFlight evidence validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`iOS TestFlight evidence validation passed for ${targetPath}.`);
