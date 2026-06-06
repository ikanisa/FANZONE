#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/onboarding-fan-profile-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredEvidenceIds = new Set([
  "FAN-PROFILE-UX-001",
  "FAN-PROFILE-SUPABASE-001",
  "FAN-PROFILE-LIVE-CATALOG-001",
  "FAN-PROFILE-VALIDATION-001",
]);

const requiredCommands = new Set([
  "flutter test test/features/onboarding/fan_profile_selector_test.dart test/features/onboarding/fan_profile_test.dart",
  "flutter test test/features/onboarding/fan_profile_test.dart test/features/onboarding/team_search_catalog_test.dart test/features/onboarding/fan_profile_selector_test.dart",
  "dart analyze lib/features/onboarding/data/team_search_catalog.dart lib/features/onboarding/data/onboarding_gateway.dart test/features/onboarding/team_search_catalog_test.dart",
  "node tool/validate_onboarding_team_catalog_evidence.mjs",
  "node tool/supabase_team_catalog_smoke.mjs",
  "./tool/flutter_analyze_release.sh",
  "flutter test test/accessibility_audit_test.dart",
  "flutter test test/screen_widgets_test.dart",
  "flutter test",
]);

const requiredCoreRefs = [
  "lib/features/onboarding/widgets/fan_profile_selector.dart",
  "lib/features/onboarding/screens/onboarding_screen.dart",
  "lib/features/onboarding/data/onboarding_gateway.dart",
  "lib/features/onboarding/data/team_search_catalog.dart",
  "lib/features/onboarding/data/fan_profile.dart",
  "test/features/onboarding/fan_profile_selector_test.dart",
  "test/features/onboarding/fan_profile_test.dart",
  "test/features/onboarding/team_search_catalog_test.dart",
  "tool/supabase_team_catalog_smoke.mjs",
  "tool/validate_onboarding_team_catalog_evidence.mjs",
  "supabase/migrations/20260503135000_fan_profile_categories.sql",
  "supabase/migrations/20260504170000_replace_uat_sports_catalog.sql",
  "supabase/migrations/20260508170000_import_world_cup_african_catalog.sql",
];

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function repoRefExists(ref) {
  if (!hasText(ref)) return false;
  if (/^https?:\/\//.test(ref)) return true;
  return fs.existsSync(path.resolve(process.cwd(), ref));
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function parseSmokeCounts(result) {
  const counts = {};
  for (const part of String(result || "").split(";")) {
    const [rawKey, rawValue] = part.trim().split("=");
    if (!rawKey || rawValue === undefined) continue;
    counts[rawKey.trim()] = Number(rawValue.trim());
  }
  return counts;
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Onboarding fan profile evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.status !== "PASS") errors.push("status must be PASS.");
if (!hasText(data.scope)) errors.push("scope is required.");

const seenEvidence = new Set();
for (const item of data.codeOwnedEvidence || []) {
  if (!requiredEvidenceIds.has(item?.id)) {
    errors.push(`Unexpected or missing onboarding evidence id: ${item?.id}`);
    continue;
  }
  seenEvidence.add(item.id);
  if (item.status !== "PASS") errors.push(`${item.id}.status must be PASS.`);
  if (!hasText(item.description)) errors.push(`${item.id}.description is required.`);
  if (!Array.isArray(item.references) || item.references.length === 0) {
    errors.push(`${item.id}.references must include repo references.`);
    continue;
  }
  for (const ref of item.references) {
    if (!repoRefExists(ref)) errors.push(`${item.id}.references contains missing ref: ${ref}`);
  }
}
for (const id of requiredEvidenceIds) {
  if (!seenEvidence.has(id)) errors.push(`Missing codeOwnedEvidence ${id}.`);
}
for (const ref of requiredCoreRefs) {
  if (!repoRefExists(ref)) errors.push(`Required onboarding implementation ref is missing: ${ref}`);
}

const commands = Array.isArray(data.commands) ? data.commands : [];
const commandsByName = new Map(
  commands
    .filter((item) => hasText(item?.command))
    .map((item) => [item.command, item]),
);
for (const command of requiredCommands) {
  const item = commandsByName.get(command);
  if (!item) {
    errors.push(`Missing command evidence: ${command}`);
  } else if (item.status !== "PASS") {
    errors.push(`${command} status must be PASS.`);
  }
}

const catalogSmoke = commandsByName.get("node tool/supabase_team_catalog_smoke.mjs");
const counts = parseSmokeCounts(catalogSmoke?.result);
for (const [key, minimum] of Object.entries({
  local_clubs: 1,
  top_european_clubs: 1,
  world_cup_national_teams: 1,
})) {
  if (!Number.isFinite(counts[key]) || counts[key] < minimum) {
    errors.push(`Supabase team catalog smoke result must include positive ${key}.`);
  }
}
if (!String(catalogSmoke?.result || "").includes("local_country=MT")) {
  errors.push("Supabase team catalog smoke result must include local_country=MT.");
}

const flutterAll = commandsByName.get("flutter test");
if (!String(flutterAll?.result || "").match(/\b\d+\s+tests passed\b/)) {
  errors.push("flutter test command must record a passed test count.");
}

const reviewWeb = data.reviewWeb || {};
if (reviewWeb.status !== "PASS") errors.push("reviewWeb.status must be PASS.");
if (!/^http:\/\/127\.0\.0\.1:8091/.test(reviewWeb.url || "")) {
  errors.push("reviewWeb.url must point to the local review web server.");
}
if (!repoRefExists(reviewWeb.screenshot)) {
  errors.push(`reviewWeb.screenshot does not exist: ${reviewWeb.screenshot}`);
}

if (!Array.isArray(data.externalLaunchGates) || data.externalLaunchGates.length === 0) {
  errors.push("externalLaunchGates must preserve separate external release gates.");
}
for (const fragment of ["Credential provider rotation", "iOS/TestFlight", "human legal signoff"]) {
  if (!data.externalLaunchGates?.some((gate) => String(gate).includes(fragment))) {
    errors.push(`externalLaunchGates must include ${fragment}.`);
  }
}

if (errors.length > 0) {
  console.error(`Onboarding fan profile evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Onboarding fan profile evidence validation passed for ${targetPath}.`);
