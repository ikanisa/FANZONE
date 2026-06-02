#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const defaultPath = "release/android/android-release-readiness.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredCheckIds = new Set([
  "ANDROID-CONFIG-001",
  "ANDROID-PREFLIGHT-001",
  "ANDROID-AAB-001",
  "ANDROID-APK-001",
  "ANDROID-SIGNATURE-001",
  "ANDROID-FRESHNESS-001",
  "ANDROID-INSTALL-001",
  "ANDROID-DEEPLINK-001",
  "ANDROID-CORE-SMOKE-001",
  "ANDROID-PLAY-INTERNAL-001",
  "ANDROID-REVIEW-METADATA-001",
]);
const requiredArtifactIds = new Set(["AAB", "APK"]);
const requiredGuidanceRefs = new Set([
  "https://developer.android.com/guide/app-bundle",
  "https://support.google.com/googleplay/android-developer/answer/9842756",
  "https://support.google.com/googleplay/android-developer/answer/9845334",
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

function isSha256(value) {
  return typeof value === "string" && /^[a-f0-9]{64}$/i.test(value);
}

function repoRefExists(ref) {
  if (!hasText(ref)) return false;
  if (/^https?:\/\//.test(ref)) return true;
  return fs.existsSync(path.resolve(process.cwd(), ref));
}

function refsArePresent(value) {
  return Array.isArray(value) && value.length > 0 && value.every(hasText);
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
    errors.push("releaseCandidate must name the Android release build, tag, or commit.");
  }
  if (!gitCommitExists(data.sourceCommit)) {
    errors.push("sourceCommit must name an existing git commit for the release candidate.");
  }
  if (data.environment !== "production") errors.push('environment must be "production".');
  if (data.applicationId !== "app.fanzone.football") {
    errors.push('applicationId must be "app.fanzone.football".');
  }
  if (!/^\d+\.\d+\.\d+$/.test(data.versionName || "")) {
    errors.push("versionName must use x.y.z format.");
  }
  if (!Number.isInteger(data.versionCode) || data.versionCode <= 0) {
    errors.push("versionCode must be a positive integer.");
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

  for (const [key, value] of Object.entries(data.artifactPaths || {})) {
    if (!hasText(value)) errors.push(`artifactPaths.${key} is required.`);
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
        errors.push(`${label} is not a required Android artifact id.`);
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
        errors.push(`${label} is ${artifact.status}; Android release artifact readiness requires PASS.`);
        continue;
      }
      if (!hasText(artifact.path)) errors.push(`${label}.path is required for PASS.`);
      if (!fs.existsSync(path.resolve(process.cwd(), artifact.path || ""))) {
        errors.push(`${label}.path does not exist: ${artifact.path}`);
      }
      if (!isSha256(artifact.sha256)) errors.push(`${label}.sha256 must be a SHA-256 hex digest for PASS.`);
      if (!Number.isInteger(artifact.sizeBytes) || artifact.sizeBytes <= 0) {
        errors.push(`${label}.sizeBytes must be a positive integer for PASS.`);
      }
      if (artifact.versionName !== data.versionName) {
        errors.push(`${label}.versionName must match top-level versionName.`);
      }
      if (artifact.versionCode !== data.versionCode) {
        errors.push(`${label}.versionCode must match top-level versionCode.`);
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

  const seenChecks = new Set();
  for (const [index, check] of data.checks.entries()) {
    const label = check?.id || `checks[${index}]`;
    if (!requiredCheckIds.has(check?.id)) {
      errors.push(`${label} is not a required Android release evidence check.`);
    } else if (seenChecks.has(check.id)) {
      errors.push(`${label} is duplicated.`);
    } else {
      seenChecks.add(check.id);
    }

    if (!hasText(check?.scenario)) errors.push(`${label}.scenario is required.`);
    if (!allowedStatuses.has(check?.status)) {
      errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
      continue;
    }
    if (check.status !== "PASS") {
      errors.push(`${label} is ${check.status}; Android release readiness requires PASS.`);
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

  for (const id of requiredCheckIds) {
    if (!seenChecks.has(id)) errors.push(`Missing required check ${id}.`);
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Android release evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Android release evidence validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Android release evidence validation passed for ${targetPath}.`);
