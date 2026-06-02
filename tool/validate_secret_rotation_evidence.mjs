#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

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
const requiredPostRotationCommands = new Map([
  ["SECRET-SCAN-FULL-HISTORY", "tool/full_history_secret_scan.sh"],
  ["PRODUCTION-ENV-ISOLATION", "tool/verify_production_envs.sh .env.production"],
  ["SUPABASE-LIVE-VALIDATION", "tool/supabase_live_validation.sh"],
  ["DEPLOYED-WEB-SURFACE-SMOKE", "tool/collect_world_class_evidence.sh"],
]);
const requiredPostRotationIds = new Set(requiredPostRotationCommands.keys());
const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|supabase_[A-Za-z0-9_-]{20,})/;

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
    errors.push(`${label} ${fieldName} must include at least one evidence reference.`);
    return;
  }
  for (const ref of refs) {
    if (!repoRefExists(ref)) {
      errors.push(`${label} ${fieldName} contains missing repo ref: ${ref}.`);
    }
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
  if (data.environment !== "production") errors.push('environment must be "production".');

  const rotationWindow = data.rotationWindow || {};
  if (!isIsoDateTime(rotationWindow.startedAtUtc)) {
    errors.push("rotationWindow.startedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (!isIsoDateTime(rotationWindow.completedAtUtc)) {
    errors.push("rotationWindow.completedAtUtc must be an ISO UTC timestamp ending in Z.");
  }
  if (
    isIsoDateTime(rotationWindow.startedAtUtc) &&
    isIsoDateTime(rotationWindow.completedAtUtc) &&
    Date.parse(rotationWindow.completedAtUtc) <= Date.parse(rotationWindow.startedAtUtc)
  ) {
    errors.push("rotationWindow.completedAtUtc must be later than rotationWindow.startedAtUtc.");
  }
  if (
    !hasText(rotationWindow.evidenceBundleRoot) ||
    rotationWindow.evidenceBundleRoot.includes("TBD")
  ) {
    errors.push("rotationWindow.evidenceBundleRoot must name the durable redacted evidence bundle root.");
  } else if (!repoRefExists(rotationWindow.evidenceBundleRoot)) {
    errors.push("rotationWindow.evidenceBundleRoot must exist as a repo path or be a URL.");
  }

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
      if (!hasText(item.description)) {
        errors.push(`${label} description is required.`);
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
      validateEvidenceRefs(label, "providerEvidenceRefs", item.providerEvidenceRefs, errors);
      validateEvidenceRefs(label, "postRotationSmokeRefs", item.postRotationSmokeRefs, errors);
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
      if (
        requiredPostRotationCommands.has(check?.id) &&
        check?.command !== requiredPostRotationCommands.get(check.id)
      ) {
        errors.push(`${label} command must be ${requiredPostRotationCommands.get(check?.id)}.`);
      }
      validateEvidenceRefs(label, "evidenceRefs", check?.evidenceRefs, errors);
    }
    for (const id of requiredPostRotationIds) {
      if (!seen.has(id)) errors.push(`Missing post-rotation check ${id}.`);
    }
  }

  return errors;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Secret rotation evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
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
