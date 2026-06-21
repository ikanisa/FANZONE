#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = process.argv.slice(2);
const requirePass = args.includes("--require-pass");
const targetPath = args.find((arg) => !arg.startsWith("--")) ||
  "release/qa/fullstack-platform-completion-matrix.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const requiredRows = [
  "flutter_customer_app_ux",
  "venue_bar_pwa_operations",
  "admin_panels_platform_ops",
  "tv_games_pwa_display",
  "malta_rwanda_market_architecture",
  "permissions_location_notifications",
  "client_to_bar_chat",
  "weekly_ai_game_generation",
  "bar_random_game_assignment",
  "three_core_games_complete",
  "database_policy_quality",
  "release_quality_evidence",
];

const requiredEvidenceKeys = [
  "frontend",
  "backend",
  "databasePolicy",
  "testCoverage",
  "releaseEvidence",
  "owner",
  "nextAction",
];
const evidenceKeySet = new Set(requiredEvidenceKeys);

const allowedStatuses = new Set([
  "pass",
  "partial",
  "planned",
  "blocked",
  "not_applicable",
]);
const allowedPriorities = new Set(["P0", "P1", "P2"]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function repoRefExists(ref) {
  return hasText(ref) && fs.existsSync(path.resolve(process.cwd(), ref));
}

function isStrictEvidence(value) {
  if (!hasText(value)) return false;
  const normalized = value.trim().toLowerCase();
  return ![
    "pending",
    "planned",
    "blocked",
    "todo",
    "tbd",
    "n/a",
    "not proven",
  ].some((needle) => normalized === needle || normalized.startsWith(`${needle} `));
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

if (!fs.existsSync(absolutePath)) {
  console.error(`Missing fullstack platform completion matrix: ${targetPath}`);
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!String(data.scope || "").includes("FANZONE fullstack platform")) {
  errors.push("scope must describe FANZONE fullstack platform completion.");
}
if (!Array.isArray(data.requiredEvidenceKeys) ||
  requiredEvidenceKeys.some((key) => !data.requiredEvidenceKeys.includes(key))) {
  errors.push(`requiredEvidenceKeys must include: ${requiredEvidenceKeys.join(", ")}.`);
}

const rows = Array.isArray(data.rows) ? data.rows : [];
const ids = new Set();
let passCount = 0;
let incompleteCount = 0;

for (const row of rows) {
  if (!row || typeof row !== "object") {
    errors.push("Each row must be an object.");
    continue;
  }
  if (!hasText(row.id) || !/^[a-z0-9_]+$/.test(row.id)) {
    errors.push(`Invalid row id: ${row.id}`);
  } else if (ids.has(row.id)) {
    errors.push(`Duplicate row id: ${row.id}`);
  } else {
    ids.add(row.id);
  }

  if (!hasText(row.surface)) errors.push(`${row.id || "row"} surface is required.`);
  if (!hasText(row.category)) errors.push(`${row.id || "row"} category is required.`);
  if (!allowedPriorities.has(row.priority)) {
    errors.push(`${row.id || "row"} priority must be P0, P1, or P2.`);
  }
  if (!allowedStatuses.has(row.status)) {
    errors.push(`${row.id || "row"} has invalid status ${row.status}.`);
  }
  if (!hasText(row.requirement)) {
    errors.push(`${row.id || "row"} requirement is required.`);
  }
  if (!Array.isArray(row.sources) || row.sources.length === 0) {
    errors.push(`${row.id || "row"} sources must be a non-empty array.`);
  } else {
    for (const source of row.sources) {
      if (!repoRefExists(source)) {
        errors.push(`${row.id || "row"} source does not exist: ${source}`);
      }
    }
  }

  const notApplicableEvidenceKeys = Array.isArray(row.notApplicableEvidenceKeys)
    ? row.notApplicableEvidenceKeys
    : [];
  for (const key of notApplicableEvidenceKeys) {
    if (!evidenceKeySet.has(key)) {
      errors.push(`${row.id || "row"} notApplicableEvidenceKeys contains unknown key: ${key}`);
    }
  }

  if (!row.evidence || typeof row.evidence !== "object" || Array.isArray(row.evidence)) {
    errors.push(`${row.id || "row"} evidence must be an object.`);
  } else {
    for (const key of requiredEvidenceKeys) {
      if (!hasText(row.evidence[key])) {
        errors.push(`${row.id || "row"} evidence.${key} is required.`);
      }
      const isNotApplicableEvidence = notApplicableEvidenceKeys.includes(key);
      if (requirePass && row.status !== "not_applicable" && !isNotApplicableEvidence &&
        !isStrictEvidence(row.evidence[key])) {
        errors.push(`${row.id || "row"} evidence.${key} is not strict evidence: ${row.evidence[key]}`);
      }
    }
  }

  if (row.status === "pass") passCount += 1;
  if (row.status !== "pass" && row.status !== "not_applicable") incompleteCount += 1;
  if (requirePass && row.status !== "not_applicable" && row.status !== "pass") {
    errors.push(`${row.id || "row"} must be pass in --require-pass mode.`);
  }
}

for (const requiredRow of requiredRows) {
  if (!ids.has(requiredRow)) errors.push(`Matrix is missing required row ${requiredRow}.`);
}

if (errors.length > 0) {
  console.error(`Fullstack platform completion matrix validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Fullstack platform completion matrix validation passed for ${targetPath}.`);
console.log(`Rows: ${rows.length}. Status: ${passCount} pass, ${incompleteCount} incomplete, ${requirePass ? "strict" : "inventory"} mode.`);
