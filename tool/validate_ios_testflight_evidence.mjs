#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/ios/testflight-readiness.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);
const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredCheckIds = new Set([
  "IOS-CONFIG-001",
  "IOS-FIREBASE-001",
  "IOS-ARCHIVE-001",
  "IOS-IPA-001",
  "IOS-INSTALL-001",
  "IOS-PUSH-001",
  "IOS-TESTFLIGHT-001",
  "IOS-BUILD-STATUS-001",
  "IOS-EXPORT-COMPLIANCE-001",
  "IOS-TEST-INFO-001",
  "IOS-REVIEW-001",
]);
const requiredArtifactIds = new Set(["XCARCHIVE", "IPA"]);
const requiredGuidanceRefs = new Set([
  "https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/",
  "https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/",
  "https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses/",
  "https://developer.apple.com/app-store/app-privacy-details/",
  "https://developer.apple.com/app-store/review/guidelines/",
]);
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

function existsFromRepo(value) {
  return hasText(value) && fs.existsSync(path.resolve(process.cwd(), value));
}

function isSha256(value) {
  return typeof value === "string" && /^[a-f0-9]{64}$/i.test(value);
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

  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the iOS release build, tag, or commit.");
  }
  if (!gitCommitExists(data.sourceCommit)) {
    errors.push("sourceCommit must name an existing git commit for the release candidate.");
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

  if (!Array.isArray(data.officialGuidanceRefs)) {
    errors.push("officialGuidanceRefs must be an array.");
  } else {
    for (const ref of requiredGuidanceRefs) {
      if (!data.officialGuidanceRefs.includes(ref)) {
        errors.push(`officialGuidanceRefs must include ${ref}.`);
      }
    }
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

  if (!Array.isArray(data.artifacts) || data.artifacts.length === 0) {
    errors.push("artifacts must be a non-empty array.");
  } else {
    const seenArtifacts = new Set();
    for (const [index, artifact] of data.artifacts.entries()) {
      const label = artifact?.id || `artifacts[${index}]`;
      if (!requiredArtifactIds.has(artifact?.id)) {
        errors.push(`${label} is not a required iOS artifact id.`);
      } else if (seenArtifacts.has(artifact.id)) {
        errors.push(`${label} is duplicated.`);
      } else {
        seenArtifacts.add(artifact.id);
      }

      if (!allowedStatuses.has(artifact?.status)) {
        errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
        continue;
      }
      if (artifact.status !== "PASS") {
        errors.push(`${label} is ${artifact.status}; iOS artifact readiness requires PASS.`);
        continue;
      }
      if (!hasText(artifact.path)) errors.push(`${label}.path is required for PASS.`);
      if (!existsFromRepo(artifact.path)) {
        errors.push(`${label}.path does not exist: ${artifact.path}`);
      }
      if (!isSha256(artifact.sha256)) errors.push(`${label}.sha256 must be a SHA-256 hex digest for PASS.`);
      if (!Number.isInteger(artifact.sizeBytes) || artifact.sizeBytes <= 0) {
        errors.push(`${label}.sizeBytes must be a positive integer for PASS.`);
      }
      if (!/^\d+\.\d+\.\d+$/.test(artifact.versionName || "")) {
        errors.push(`${label}.versionName must use x.y.z format for PASS.`);
      }
      if (!Number.isInteger(artifact.buildNumber) || artifact.buildNumber <= 0) {
        errors.push(`${label}.buildNumber must be a positive integer for PASS.`);
      }
      if (!isIsoDateTime(artifact.builtAtUtc)) {
        errors.push(`${label}.builtAtUtc must be an ISO UTC timestamp ending in Z for PASS.`);
      }
      if (!refsArePresent(artifact.evidenceRefs)) {
        errors.push(`${label}.evidenceRefs must include at least one evidence reference for PASS.`);
      }
    }
    for (const id of requiredArtifactIds) {
      if (!seenArtifacts.has(id)) errors.push(`Missing required artifact ${id}.`);
    }
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
    if (!allowedStatuses.has(check?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }
    if (check.status !== "PASS") {
      errors.push(`${label} is ${check.status}; iOS TestFlight readiness requires PASS.`);
      continue;
    }
    if (!refsArePresent(check.evidenceRefs)) {
      errors.push(`${label}.evidenceRefs must include at least one evidence reference.`);
    } else {
      for (const ref of check.evidenceRefs) {
        if (!repoRefExists(ref)) errors.push(`${label}.evidenceRefs contains missing repo ref: ${ref}.`);
      }
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

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`iOS TestFlight evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
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
