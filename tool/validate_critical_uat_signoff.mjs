#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const defaultPath = "release/qa/critical-user-flow-uat.json";
const targetPath = process.argv[2] || defaultPath;
const absolutePath = path.resolve(process.cwd(), targetPath);

const allowedStatuses = new Set(["PASS", "FAIL", "BLOCKED", "PENDING", "N/A"]);
const requiredSurfaces = new Set([
  "Flutter app",
  "Bars/Venue PWA",
  "Admin PWA",
  "TV PWA",
  "Supabase backend",
]);

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

function validate(data) {
  const errors = [];

  if (data.schemaVersion !== 1) {
    errors.push("schemaVersion must be 1.");
  }

  if (!hasText(data.releaseCandidate) || data.releaseCandidate === "TBD") {
    errors.push("releaseCandidate must name the release build, tag, or commit.");
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

    if (!hasText(flow?.scenario)) {
      errors.push(`${label} scenario is required.`);
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

    if (!Array.isArray(flow.evidenceRefs) || flow.evidenceRefs.length === 0) {
      errors.push(`${label} evidenceRefs must include at least one evidence reference.`);
    } else if (!flow.evidenceRefs.every(hasText)) {
      errors.push(`${label} evidenceRefs must be non-empty strings.`);
    }
  }

  for (const surface of requiredSurfaces) {
    if (!seenSurfaces.has(surface)) {
      errors.push(`Missing critical UAT coverage for ${surface}.`);
    }
  }

  return errors;
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
