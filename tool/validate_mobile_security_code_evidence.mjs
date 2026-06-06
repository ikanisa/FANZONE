#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] || "release/qa/mobile-security-code-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredControls = [
  "Android dangerous permission minimization",
  "Android cleartext traffic and debuggable release flag rejection",
  "Android production app links and custom pool deep links",
  "Android production package identity and target SDK",
  "Android release signing fail-closed preflight",
  "Android AAB/APK signature verification scripts",
  "iOS location usage purpose string",
  "iOS push background mode declaration",
  "iOS release-configured bundle id and APS environment",
  "iOS associated domains for production app links",
  "Flutter secure storage dependency",
  "Runtime auth sessions stored via secure storage",
  "Mobile source privileged credential scan",
];

const requiredRefs = [
  "tool/mobile_release_static_audit.sh",
  "android/app/src/main/AndroidManifest.xml",
  "android/app/build.gradle.kts",
  "android/gradle.properties",
  "tool/preflight_build_check.sh",
  "tool/build_android_release_from_env.sh",
  "tool/build_android_aab_from_env.sh",
  "tool/android_deep_link_smoke.sh",
  "tool/android_signature_verify.sh",
  "ios/Runner/Info.plist",
  "ios/Runner/Runner.entitlements",
  "pubspec.yaml",
  "lib/core/storage/secure_auth_session_store.dart",
  "lib/core/auth/runtime_auth_session_manager.dart",
  "release/qa/android-device-uat-current.json",
];

const requiredFileFragments = new Map([
  [
    "tool/mobile_release_static_audit.sh",
    [
      "Static mobile release audit",
      "android.permission",
      "usesCleartextTraffic",
      "FlutterSecureStorage",
      "SUPABASE_SERVICE_ROLE_KEY",
    ],
  ],
  [
    "android/app/src/main/AndroidManifest.xml",
    [
      'android:host="fanzone.guest.ikanisa.com"',
      'android:host="fanzone.ikanisa.com"',
      'android:host="pools"',
      'android:autoVerify="true"',
    ],
  ],
  [
    "android/app/build.gradle.kts",
    [
      'applicationId = "app.fanzone.football"',
      "targetSdk = 35",
      "val requiresReleaseSigning = appEnvironment == \"production\"",
      "isMinifyEnabled = hardenReleaseBuild",
      "isShrinkResources = hardenReleaseBuild",
      'debugSymbolLevel = "FULL"',
    ],
  ],
  [
    "tool/preflight_build_check.sh",
    [
      "BUILD BLOCKED",
      "Android signing",
      "SUPABASE_URL",
      "SUPABASE_ANON_KEY",
    ],
  ],
  [
    "tool/android_deep_link_smoke.sh",
    [
      "fanzone.guest.ikanisa.com: verified",
      "fanzone.ikanisa.com: verified",
      "FANZONE_DEEPLINK_SMOKE_RELEASE",
      "fanzone://pools",
    ],
  ],
  [
    "tool/android_signature_verify.sh",
    [
      "jarsigner -verify",
      "apksigner",
      "--print-certs",
    ],
  ],
  [
    "ios/Runner/Info.plist",
    [
      "NSLocationWhenInUseUsageDescription",
      "UIBackgroundModes",
      "$(PRODUCT_BUNDLE_IDENTIFIER)",
    ],
  ],
  [
    "ios/Runner/Runner.entitlements",
    [
      "$(FANZONE_APS_ENVIRONMENT)",
      "applinks:fanzone.guest.ikanisa.com",
      "applinks:fanzone.ikanisa.com",
    ],
  ],
  [
    "pubspec.yaml",
    [
      "flutter_secure_storage:",
      "shared_preferences:",
    ],
  ],
  [
    "lib/core/storage/secure_auth_session_store.dart",
    [
      "FlutterSecureStorage",
      "writeMap",
      "delete(String key)",
    ],
  ],
  [
    "lib/core/auth/runtime_auth_session_manager.dart",
    [
      "SecureAuthSessionStore.writeMap",
      "SecureAuthSessionStore.delete",
    ],
  ],
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function repoRefExists(ref) {
  return hasText(ref) && fs.existsSync(repoPath(ref));
}

function readText(ref) {
  return fs.readFileSync(repoPath(ref), "utf8");
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
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

function requireFragments(errors, label, text, fragments) {
  for (const fragment of fragments) {
    if (!text.includes(fragment)) {
      errors.push(`${label} must include ${fragment}.`);
    }
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Mobile security code evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(data.releaseCandidate)) errors.push("releaseCandidate is required.");
if (!gitCommitExists(data.sourceCommit)) {
  errors.push("sourceCommit must name an existing git commit.");
}
if (!String(data.scope || "").includes("mobile security")) {
  errors.push("scope must describe mobile security controls.");
}

const staticAudit = data.staticAudit || {};
if (staticAudit.command !== "./tool/mobile_release_static_audit.sh") {
  errors.push("staticAudit.command must be ./tool/mobile_release_static_audit.sh.");
}
if (staticAudit.status !== "PASS") errors.push("staticAudit.status must be PASS.");
requireFragments(errors, "staticAudit.proof", staticAudit.proof || "", [
  "Static mobile release audit passed",
  "secure session storage",
  "mobile-source secret hygiene",
]);

const controls = new Set(data.coveredControls || []);
for (const control of requiredControls) {
  if (!controls.has(control)) errors.push(`coveredControls missing ${control}.`);
}

const refs = new Set(data.evidenceRefs || []);
for (const ref of requiredRefs) {
  if (!refs.has(ref)) errors.push(`evidenceRefs missing ${ref}.`);
  if (!repoRefExists(ref)) errors.push(`evidence ref does not exist: ${ref}`);
}

for (const [ref, fragments] of requiredFileFragments) {
  if (!repoRefExists(ref)) continue;
  const text = readText(ref);
  requireFragments(errors, ref, text, fragments);
}

for (const ref of [
  "lib",
  "android/app",
  "ios/Runner",
]) {
  const scanTarget = repoPath(ref);
  if (!fs.existsSync(scanTarget)) continue;
  try {
    const privilegedSecretPattern = [
      "SUPABASE_SERVICE_ROLE_KEY",
      "service_role_key",
      "postgresql:/{2}[^[:space:]]+:[^[:space:]]+@",
      "sbp_[A-Za-z0-9_-]{20,}",
    ].join("|");
    const result = execFileSync("rg", ["-n", privilegedSecretPattern, ref], {
      cwd: process.cwd(),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
    if (result.length > 0) {
      errors.push(`mobile source secret scan found privileged credential patterns in ${ref}.`);
    }
  } catch (error) {
    if (error.status !== 1) {
      errors.push(`mobile source secret scan failed for ${ref}: ${error.message}`);
    }
  }
}

const deviceCrash = data.deviceCrashEvidence || {};
if (deviceCrash.status !== "PASS") errors.push("deviceCrashEvidence.status must be PASS.");
if (deviceCrash.evidence !== "release/qa/android-device-uat-current.json") {
  errors.push("deviceCrashEvidence.evidence must be release/qa/android-device-uat-current.json.");
}
if (repoRefExists(deviceCrash.evidence)) {
  const androidUat = readJson(repoPath(deviceCrash.evidence));
  const notes = Array.isArray(androidUat.notes) ? androidUat.notes.join("\n") : "";
  if (!notes.includes("No crash-buffer entries")) {
    errors.push("Android device UAT evidence must record no crash-buffer entries.");
  }
} else {
  errors.push(`deviceCrashEvidence.evidence does not exist: ${deviceCrash.evidence}`);
}

const remaining = Array.isArray(data.remainingExternalEvidence)
  ? data.remainingExternalEvidence.join("\n")
  : "";
for (const fragment of [
  "Real-device mobile security review",
  "Production crash-reporting provider dashboard",
]) {
  if (!remaining.includes(fragment)) {
    errors.push(`remainingExternalEvidence must include ${fragment}.`);
  }
}

if (data.validator?.command !== "node tool/validate_mobile_security_code_evidence.mjs") {
  errors.push("validator.command must be node tool/validate_mobile_security_code_evidence.mjs.");
}
if (data.validator?.status !== "PASS") errors.push("validator.status must be PASS.");

if (errors.length > 0) {
  console.error(`Mobile security code evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Mobile security code evidence validation passed for ${targetPath}.`);
