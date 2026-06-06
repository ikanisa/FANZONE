#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/games-livescore-fullstack-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredFunctions = new Set([
  "fan-trivia",
  "song-guess",
  "music-bingo",
  "sync-livescore-football",
]);

const requiredTemplateMappings = new Map([
  ["fan_trivia", "fan-trivia"],
  ["song_guess", "song-guess"],
  ["music_bingo", "music-bingo"],
]);

const requiredFiles = [
  "lib/features/games/data/games_repository.dart",
  "test/features/games/games_repository_test.dart",
  "tool/livescore_ingest.py",
  "tool/livescore_ingest_test.py",
  "supabase/functions/sync-livescore-football/index.ts",
  "supabase/functions/sync-livescore-football/livescore.ts",
  "supabase/functions/sync-livescore-football/livescore_test.ts",
  "supabase/functions/_shared/game_edge.ts",
  "supabase/functions/_shared/game_edge_test.ts",
  "supabase/functions/fan-trivia/index.ts",
  "supabase/functions/song-guess/index.ts",
  "supabase/functions/music-bingo/index.ts",
  "tool/run_supabase_cron_job.sh",
  "tool/supabase_game_edge_smoke.sh",
  "tool/scheduler_payload_smoke.sh",
  "tool/validate_edge_function_release_contract.mjs",
  "supabase/config.toml",
  "docs/release/deployment-readme.md",
  "docs/architecture/backend.md",
];

const requiredPassingCommands = new Set([
  "python3 -m unittest tool/livescore_ingest_test.py",
  "python3 -m py_compile tool/livescore_ingest.py tool/livescore_ingest_test.py",
  "deno test --allow-env supabase/functions/sync-livescore-football/livescore_test.ts",
  "deno check supabase/functions/sync-livescore-football/index.ts supabase/functions/sync-livescore-football/livescore.ts supabase/functions/sync-livescore-football/livescore_test.ts",
  "deno test --allow-env supabase/functions/_shared/game_edge_test.ts",
  "deno check supabase/functions/fan-trivia/index.ts supabase/functions/song-guess/index.ts supabase/functions/music-bingo/index.ts supabase/functions/_shared/game_edge.ts",
  "flutter test test/features/games/games_repository_test.dart",
  "node tool/validate_edge_function_release_contract.mjs",
  "tool/scheduler_payload_smoke.sh",
]);

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

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Games/LiveScore evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}
if (!hasText(data.scope)) errors.push("scope is required.");

const functions = Array.isArray(data.deployedFunctions)
  ? data.deployedFunctions
  : [];
const seenFunctions = new Set();
for (const fn of functions) {
  if (!requiredFunctions.has(fn?.name)) continue;
  seenFunctions.add(fn.name);
  if (fn.status !== "ACTIVE") {
    errors.push(`${fn.name} deployed function status must be ACTIVE.`);
  }
  if (!Number.isInteger(fn.version) || fn.version <= 0) {
    errors.push(`${fn.name} deployed function version must be a positive integer.`);
  }
  if (!isIsoDateTime(fn.updatedAtUtc)) {
    errors.push(`${fn.name} updatedAtUtc must be an ISO UTC timestamp ending in Z.`);
  }
}
for (const fn of requiredFunctions) {
  if (!seenFunctions.has(fn)) errors.push(`Missing deployed function evidence for ${fn}.`);
}

const mappings = data.flutterContract?.gameTemplatesMappedToEdgeFunctions || {};
for (const [templateId, functionName] of requiredTemplateMappings) {
  if (mappings[templateId] !== functionName) {
    errors.push(`Flutter game template ${templateId} must map to ${functionName}.`);
  }
}
if (!Array.isArray(data.flutterContract?.legacyFallbackPreserved) ||
  !data.flutterContract.legacyFallbackPreserved.includes("bar_trivia")) {
  errors.push("Flutter contract must preserve the bar_trivia legacy fallback.");
}

const liveScore = data.livescoreDryExport || {};
if (liveScore.status !== "PASS") {
  errors.push("livescoreDryExport.status must be PASS.");
}
if (liveScore.datasetType !== "official_fixture_rows") {
  errors.push("livescoreDryExport.datasetType must be official_fixture_rows.");
}
if (liveScore.resourceId !== "livescore_world_cup_2026") {
  errors.push("livescoreDryExport.resourceId must be livescore_world_cup_2026.");
}
if (!Number.isInteger(liveScore.rows) || liveScore.rows <= 0) {
  errors.push("livescoreDryExport.rows must be a positive integer.");
}
if (liveScore.sourceHost !== "www.livescore.com") {
  errors.push("livescoreDryExport.sourceHost must be www.livescore.com.");
}
if (!isIsoDateTime(liveScore.firstStartsAtUtc)) {
  errors.push("livescoreDryExport.firstStartsAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(liveScore.timezoneName)) {
  errors.push("livescoreDryExport.timezoneName is required.");
}

for (const file of requiredFiles) {
  if (!repoRefExists(file)) errors.push(`Required implementation file is missing: ${file}`);
}
for (const file of data.codeFix?.files || []) {
  if (!repoRefExists(file)) errors.push(`codeFix.files contains missing repo ref: ${file}`);
}

const validations = Array.isArray(data.validation) ? data.validation : [];
const validationsByCommand = new Map(
  validations
    .filter((item) => hasText(item?.command))
    .map((item) => [item.command, item]),
);
for (const command of requiredPassingCommands) {
  const item = validationsByCommand.get(command);
  if (!item) {
    errors.push(`Missing validation command: ${command}`);
  } else if (item.status !== "PASS") {
    errors.push(`${command} validation status must be PASS.`);
  }
}

const opsValidation = validationsByCommand.get("node tool/validate_operations_readiness_evidence.mjs");
if (!opsValidation || opsValidation.status !== "EXPECTED_FAIL_EXTERNAL_SIGNOFF") {
  errors.push(
    "Operations readiness validation must be recorded as EXPECTED_FAIL_EXTERNAL_SIGNOFF, not PASS, until external ops signoff exists.",
  );
}

const reviewWeb = data.reviewWeb || {};
if (reviewWeb.status !== "PASS") {
  errors.push("reviewWeb.status must be PASS.");
}
if (!/^http:\/\/127\.0\.0\.1:8091/.test(reviewWeb.url || "")) {
  errors.push("reviewWeb.url must point to the local review web surface on 127.0.0.1:8091.");
}
if (!repoRefExists(reviewWeb.screenshot)) {
  errors.push(`reviewWeb.screenshot does not exist: ${reviewWeb.screenshot}`);
}

if (!Array.isArray(data.remainingNotes) || data.remainingNotes.length === 0) {
  errors.push("remainingNotes must describe remaining non-code release gates.");
}

if (errors.length > 0) {
  console.error(`Games/LiveScore evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Games/LiveScore evidence validation passed for ${targetPath}.`);
