#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] || "release/qa/android-device-uat-current.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredFlows = new Map([
  [
    "ANDROID-HOME-SHELL-001",
    ["Home", "Play", "Settings", "Supabase-backed bars"],
  ],
  [
    "ANDROID-PLAY-GAMES-001",
    ["Play hub", "Supabase-backed live games"],
  ],
  [
    "ANDROID-SETTINGS-SUPPORT-001",
    ["Help & FAQ", "Privacy Policy"],
  ],
  [
    "ANDROID-WHATSAPP-OTP-001",
    ["Send OTP", "OTP entry", "Verified"],
  ],
  [
    "ANDROID-FAN-PROFILE-TEAMS-001",
    ["Local", "Europe", "National", "Malta"],
  ],
]);

const requiredCommands = [
  "dart analyze lib/core/utils/phone_country_catalog.dart lib/features/auth/widgets/sign_in_required_sheet.dart lib/features/auth/screens/whatsapp_login_screen.dart lib/features/onboarding/screens/onboarding_screen.dart test/phone_preset_test.dart",
  "flutter test test/phone_preset_test.dart test/onboarding_phone_step_test.dart test/dev_whatsapp_otp_fixture_test.dart",
  "flutter test test/features/onboarding/fan_profile_selector_test.dart test/features/onboarding/team_search_catalog_test.dart test/phone_preset_test.dart",
  "./tool/product_boundary_scan.sh",
  "git diff --check",
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

function sha256(filePath) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(filePath))
    .digest("hex");
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

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Android device UAT evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!gitCommitExists(data.sourceCommit)) {
  errors.push("sourceCommit must name an existing git commit.");
}
if (data.branch !== "main") errors.push("branch must be main for current release evidence.");

const device = data.device || {};
if (device.serial !== "13111JEC215558") {
  errors.push("device.serial must be the Pixel 4a UAT device serial.");
}
if (device.model !== "Pixel 4a") errors.push("device.model must be Pixel 4a.");
if (!Number.isInteger(device.androidApi) || device.androidApi < 30) {
  errors.push("device.androidApi must be a supported Android API integer.");
}

const installed = data.installedPackage || {};
if (installed.applicationId !== "app.fanzone.football") {
  errors.push("installedPackage.applicationId must be app.fanzone.football.");
}
if (installed.versionName !== "1.1.3") {
  errors.push("installedPackage.versionName must be 1.1.3.");
}
if (installed.versionCode !== 11) {
  errors.push("installedPackage.versionCode must be 11.");
}
if (!String(installed.foregroundActivity || "").includes("app.fanzone.football/")) {
  errors.push("installedPackage.foregroundActivity must show the FANZONE app foregrounded.");
}

const artifact = data.artifact || {};
if (artifact.path !== "build/app/outputs/flutter-apk/app-release.apk") {
  errors.push("artifact.path must be the release APK path.");
}
if (!repoRefExists(artifact.path)) {
  errors.push(`artifact.path does not exist: ${artifact.path}`);
} else {
  const artifactPath = path.resolve(process.cwd(), artifact.path);
  if (sha256(artifactPath) !== artifact.sha256) {
    errors.push("artifact.sha256 does not match the release APK.");
  }
  const size = fs.statSync(artifactPath).size;
  if (artifact.sizeBytes !== size) {
    errors.push(`artifact.sizeBytes does not match the release APK: expected ${artifact.sizeBytes}, actual ${size}.`);
  }
}
if (artifact.buildCommand !== "./tool/build_android_release_from_env.sh production") {
  errors.push("artifact.buildCommand must be ./tool/build_android_release_from_env.sh production.");
}

const flows = Array.isArray(data.validatedFlows) ? data.validatedFlows : [];
const flowsById = new Map(
  flows
    .filter((flow) => hasText(flow?.id))
    .map((flow) => [flow.id, flow]),
);
for (const [flowId, summaryFragments] of requiredFlows) {
  const flow = flowsById.get(flowId);
  if (!flow) {
    errors.push(`validatedFlows missing ${flowId}.`);
    continue;
  }
  if (flow.status !== "PASS") errors.push(`${flowId}.status must be PASS.`);
  for (const fragment of summaryFragments) {
    if (!String(flow.summary || "").includes(fragment)) {
      errors.push(`${flowId}.summary must include ${fragment}.`);
    }
  }
  if (!Array.isArray(flow.evidenceRefs) || flow.evidenceRefs.length === 0) {
    errors.push(`${flowId}.evidenceRefs must include screenshot/log refs.`);
    continue;
  }
  for (const ref of flow.evidenceRefs) {
    if (!repoRefExists(ref)) errors.push(`${flowId}.evidenceRefs contains missing ref: ${ref}`);
  }
}

const commands = Array.isArray(data.validationCommands)
  ? data.validationCommands
  : [];
const commandsByName = new Map(
  commands
    .filter((item) => hasText(item?.command))
    .map((item) => [item.command, item]),
);
for (const command of requiredCommands) {
  const item = commandsByName.get(command);
  if (!item) {
    errors.push(`Missing validation command: ${command}`);
  } else if (item.status !== "PASS") {
    errors.push(`${command} status must be PASS.`);
  }
}

const notes = Array.isArray(data.notes) ? data.notes.join("\n") : "";
for (const fragment of [
  "No crash-buffer entries",
  "production WhatsApp Cloud API path is preserved",
  "accessibility overlay",
]) {
  if (!notes.includes(fragment)) errors.push(`notes must include ${fragment}.`);
}

if (errors.length > 0) {
  console.error(`Android device UAT evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Android device UAT evidence validation passed for ${targetPath}.`);
