#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const defaultPath = "release/security/secret-rotation-evidence.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);
const requiredCredentialIds = new Set([
  "SUPABASE-ANON-KEY",
  "SUPABASE-SERVICE-ROLE",
  "SUPABASE-DB-CREDENTIALS",
  "SUPABASE-PAT",
  "CLOUDFLARE-RUNTIME-SECRETS",
  "SUPABASE-EDGE-SECRETS",
  "CI-CD-SECRETS",
  "LOCAL-OPERATOR-SECRETS",
]);
const requiredPostRotationIds = new Set([
  "SECRET-SCAN-FULL-HISTORY",
  "PRODUCTION-ENV-ISOLATION",
  "SUPABASE-LIVE-VALIDATION",
  "DEPLOYED-WEB-SURFACE-SMOKE",
]);
const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);

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

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the release build, tag, or commit.");
  }
  if (data.environment !== "production") errors.push('environment must be "production".');

  const signOff = data.signOff || {};
  if (!hasText(signOff.securityOwner)) errors.push("signOff.securityOwner is required.");
  if (!hasText(signOff.releaseOwner)) errors.push("signOff.releaseOwner is required.");
  if (!isIsoDateTime(signOff.signedAtUtc)) {
    errors.push("signOff.signedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (signOff.approvedForLaunch !== true) {
    errors.push("signOff.approvedForLaunch must be true.");
  }

  if (!Array.isArray(data.credentialClasses) || data.credentialClasses.length === 0) {
    errors.push("credentialClasses must be a non-empty array.");
  } else {
    const seen = new Set();
    for (const item of data.credentialClasses) {
      const label = item?.id || "credentialClasses[]";
      if (!requiredCredentialIds.has(item?.id)) {
        errors.push(`${label} is not a required credential class.`);
      } else if (seen.has(item.id)) {
        errors.push(`${label} is duplicated.`);
      } else {
        seen.add(item.id);
      }

      if (!allowedStatuses.has(item?.status)) {
        errors.push(`${label} status must be PASS, FAIL, BLOCKED, PENDING, or N/A.`);
        continue;
      }
      if (item.status !== "PASS") {
        errors.push(`${label} is ${item.status}; credential rotation requires PASS.`);
        continue;
      }
      if (!isIsoDateTime(item.rotatedAtUtc)) {
        errors.push(`${label} rotatedAtUtc must be an ISO UTC timestamp ending in Z.`);
      }
      if (item.oldCredentialRevoked !== true) {
        errors.push(`${label} oldCredentialRevoked must be true.`);
      }
      if (!refsArePresent(item.providerEvidenceRefs)) {
        errors.push(`${label} providerEvidenceRefs must include at least one redacted provider reference.`);
      }
      if (!refsArePresent(item.postRotationSmokeRefs)) {
        errors.push(`${label} postRotationSmokeRefs must include at least one post-rotation smoke reference.`);
      }
    }
    for (const id of requiredCredentialIds) {
      if (!seen.has(id)) errors.push(`Missing credential class ${id}.`);
    }
  }

  if (!Array.isArray(data.postRotationChecks) || data.postRotationChecks.length === 0) {
    errors.push("postRotationChecks must be a non-empty array.");
  } else {
    const seen = new Set();
    for (const check of data.postRotationChecks) {
      const label = check?.id || "postRotationChecks[]";
      if (!requiredPostRotationIds.has(check?.id)) {
        errors.push(`${label} is not a required post-rotation check.`);
      } else if (seen.has(check.id)) {
        errors.push(`${label} is duplicated.`);
      } else {
        seen.add(check.id);
      }
      if (check?.status !== "PASS") {
        errors.push(`${label} is ${check?.status || "missing"}; post-rotation checks require PASS.`);
      }
      if (!refsArePresent(check?.evidenceRefs)) {
        errors.push(`${label} evidenceRefs must include at least one evidence reference.`);
      }
    }
    for (const id of requiredPostRotationIds) {
      if (!seen.has(id)) errors.push(`Missing post-rotation check ${id}.`);
    }
  }

  return errors;
}

const data = readJson(absolutePath);
const errors = validate(data);

if (errors.length > 0) {
  console.error(`Secret rotation evidence validation failed for ${targetPath}:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`Secret rotation evidence validation passed for ${targetPath}.`);
