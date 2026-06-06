#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/settings-support-navigation-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredRoutes = new Map([
  ["Help & FAQ", { destination: "/settings/help", assertedContent: "Getting into FANZONE" }],
  ["Privacy Policy", { destination: "/settings/privacy-policy", assertedContent: "Account data" }],
  ["Terms of Service", { destination: "/settings/terms", assertedContent: "Use of the app" }],
]);

const requiredCodeEvidence = [
  "lib/app_router.dart",
  "lib/features/settings/screens/settings_screen.dart",
  "lib/features/settings/screens/support_info_screen.dart",
  "test/screen_widgets_test.dart",
];

const requiredValidationCommands = [
  "flutter test test/screen_widgets_test.dart --name \"settings support rows navigate through in-app routes\"",
  "flutter test test/screen_widgets_test.dart --name \"settings support\"",
  "./tool/flutter_analyze_release.sh",
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

function read(filePath) {
  return fs.readFileSync(path.resolve(process.cwd(), filePath), "utf8");
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Settings support evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(data.scope)) errors.push("scope is required.");

const routeRows = Array.isArray(data.routesVerified) ? data.routesVerified : [];
for (const [label, expected] of requiredRoutes) {
  const row = routeRows.find((item) => item?.label === label);
  if (!row) {
    errors.push(`routesVerified missing ${label}.`);
    continue;
  }
  if (row.source !== "/settings") {
    errors.push(`${label}.source must be /settings.`);
  }
  if (row.destination !== expected.destination) {
    errors.push(`${label}.destination must be ${expected.destination}.`);
  }
  if (row.assertedContent !== expected.assertedContent) {
    errors.push(`${label}.assertedContent must be ${expected.assertedContent}.`);
  }
}

for (const file of requiredCodeEvidence) {
  if (!repoRefExists(file)) errors.push(`Required Settings evidence file is missing: ${file}`);
  if (!Array.isArray(data.codeEvidence) || !data.codeEvidence.includes(file)) {
    errors.push(`codeEvidence must include ${file}.`);
  }
}

const appRouter = repoRefExists("lib/app_router.dart")
  ? read("lib/app_router.dart")
  : "";
const settingsScreen = repoRefExists("lib/features/settings/screens/settings_screen.dart")
  ? read("lib/features/settings/screens/settings_screen.dart")
  : "";
const supportScreen = repoRefExists("lib/features/settings/screens/support_info_screen.dart")
  ? read("lib/features/settings/screens/support_info_screen.dart")
  : "";
const screenTest = repoRefExists("test/screen_widgets_test.dart")
  ? read("test/screen_widgets_test.dart")
  : "";

if (!appRouter.includes("path: '/settings'")) {
  errors.push("app router must include the /settings parent route.");
}
for (const [name, childPath] of Object.entries({
  settings_help: "help",
  settings_privacy_policy: "privacy-policy",
  settings_terms: "terms",
})) {
  if (!appRouter.includes(`name: '${name}'`) ||
    !appRouter.includes(`path: '${childPath}'`)) {
    errors.push(`app router must include settings child route ${name}/${childPath}.`);
  }
}
for (const label of requiredRoutes.keys()) {
  if (!settingsScreen.includes(label)) errors.push(`settings screen must include ${label}.`);
  if (!supportScreen.includes(label)) errors.push(`support info screen must include ${label}.`);
}
for (const text of [
  "settings support rows navigate through in-app routes",
  "settings support info pages render in-app destinations",
  "Help & FAQ",
  "Privacy Policy",
  "Terms of Service",
]) {
  if (!screenTest.includes(text)) {
    errors.push(`screen widget test must include ${text}.`);
  }
}

const validations = Array.isArray(data.validation) ? data.validation : [];
const validationsByCommand = new Map(
  validations
    .filter((item) => hasText(item?.command))
    .map((item) => [item.command, item]),
);
for (const command of requiredValidationCommands) {
  const item = validationsByCommand.get(command);
  if (!item) {
    errors.push(`Missing validation command: ${command}`);
  } else if (item.status !== "PASS") {
    errors.push(`${command} validation status must be PASS.`);
  }
}
const supportTest = validationsByCommand.get(
  "flutter test test/screen_widgets_test.dart --name \"settings support\"",
);
if (!Number.isInteger(supportTest?.testsPassed) || supportTest.testsPassed < 2) {
  errors.push("settings support test evidence must record at least two passed tests.");
}

if (!Array.isArray(data.remainingNotes) ||
  !data.remainingNotes.some((note) => String(note).includes("human legal sign-off"))) {
  errors.push("remainingNotes must preserve privacy/legal human sign-off as a separate gate.");
}

if (errors.length > 0) {
  console.error(`Settings support evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Settings support evidence validation passed for ${targetPath}.`);
