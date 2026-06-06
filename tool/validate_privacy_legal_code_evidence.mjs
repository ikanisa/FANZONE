#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/privacy-legal-code-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredArtifacts = [
  "docs/privacy-policy.md",
  "release/legal/privacy-policy.md",
  "release/legal/terms.md",
  "release/legal/fet-reward-terms.md",
  "release/legal/privacy-legal-readiness-evidence.json",
  "apps/website/src/components/LegalPage.tsx",
  "release/ios/privacy-label-notes.md",
  "release/ios/app-store-metadata.md",
  "release/ios/app-review-notes.md",
  "docs/release-checklist.md",
  "docs/play-store-listing.md",
  "tool/validate_privacy_public_surface_copy.mjs",
  "lib/core/logging/app_logger.dart",
  "lib/services/app_telemetry.dart",
  "lib/core/config/platform_feature_access.dart",
  "lib/features/settings/screens/feature_unavailable_screen.dart",
  "lib/features/settings/screens/support_info_screen.dart",
  "lib/features/ordering/providers/order_provider.dart",
  "lib/widgets/common/fz_reference_modals.dart",
  "test/platform_feature_access_test.dart",
  "test/feature_unavailable_screen_test.dart",
  "test/features/ordering/order_provider_test.dart",
  "test/app_telemetry_test.dart",
  "test/fz_reference_modals_test.dart",
  "test/screen_widgets_test.dart",
];

const requiredChecks = [
  "PUBLIC-PRIVACY-POLICY",
  "PUBLIC-TERMS",
  "ANDROID-DATA-SAFETY",
  "APPLE-PRIVACY-LABELS",
  "ACCOUNT-DELETION",
  "DATA-RETENTION",
  "DATA-EXPORT-ACCESS",
  "SUPPORT-ACCESS",
  "NO-BETTING-NO-CASHOUT",
  "OFF-PLATFORM-PAYMENTS",
  "SDK-DATA-INVENTORY",
  "PUBLIC-SURFACE-COPY-AUDIT",
];

const requiredAppContent = [
  "Privacy Policy shows account data, location, payments, and controls.",
  "Terms of Service shows use of the app and closed-loop rewards wording.",
  "Website terms now use product-boundary-safe free-to-play and non-cash rewards wording on active surfaces.",
  "Release/legal and store-review notes use rewards-ledger wording instead of customer wallet wording.",
  "Tracked Android/iOS review notes and release checklist drafts no longer contain a committed reviewer phone number or OTP.",
  "Settings support rows navigate to Help, Privacy Policy, and Terms routes.",
  "Legacy wallet feature labels are sanitized to Rewards before user-facing errors.",
  "Disabled feature routes use configured product labels instead of raw route keys.",
  "Insufficient FET sheets use available-rewards wording instead of balance wording.",
  "Checkout order failure copy is user-safe and does not expose backend exception text.",
  "Telemetry and debug logs redact backend payloads and secret-looking values before storage or printing.",
];

const requiredPassingCommands = [
  "flutter test test/screen_widgets_test.dart --name \"settings support\"",
  "flutter test test/platform_feature_access_test.dart --name \"sanitizes legacy wallet labels\"",
  "flutter test test/feature_unavailable_screen_test.dart",
  "flutter test test/features/ordering/order_provider_test.dart",
  "flutter test test/app_telemetry_test.dart",
  "flutter test test/fz_reference_modals_test.dart",
  "./tool/flutter_analyze_release.sh",
  "node tool/validate_privacy_public_surface_copy.mjs",
  "node tool/validate_android_review_metadata.mjs",
  "./tool/product_boundary_scan.sh",
];

const expectedReadinessFailures = [
  "signOff.complianceOwner is required",
  "signOff.legalReviewer is required",
  "signOff.releaseOwner is required",
  "signOff.signedAtUtc must be an ISO UTC timestamp ending in Z",
  "signOff.approvedForLaunch must be true",
  "HUMAN-LEGAL-REVIEW is PENDING",
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

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Privacy/legal code evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(data.scope)) errors.push("scope is required.");

const artifacts = new Set(data.updatedArtifacts || []);
for (const artifact of requiredArtifacts) {
  if (!artifacts.has(artifact)) {
    errors.push(`updatedArtifacts must include ${artifact}.`);
  }
  if (!repoRefExists(artifact)) {
    errors.push(`updated artifact does not exist: ${artifact}`);
  }
}

const checks = new Set(data.codeOwnedChecksMarkedPass || []);
for (const check of requiredChecks) {
  if (!checks.has(check)) {
    errors.push(`codeOwnedChecksMarkedPass must include ${check}.`);
  }
}
if (checks.has("HUMAN-LEGAL-REVIEW")) {
  errors.push("HUMAN-LEGAL-REVIEW must not be marked pass in code-owned evidence.");
}

const appContent = new Set(data.appContentVerified || []);
for (const item of requiredAppContent) {
  if (!appContent.has(item)) {
    errors.push(`appContentVerified must include: ${item}`);
  }
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

const settingsTest = validationsByCommand.get(
  "flutter test test/screen_widgets_test.dart --name \"settings support\"",
);
if (!Number.isInteger(settingsTest?.testsPassed) || settingsTest.testsPassed < 2) {
  errors.push("settings support validation must record at least two passed tests.");
}

const platformLabelTest = validationsByCommand.get(
  "flutter test test/platform_feature_access_test.dart --name \"sanitizes legacy wallet labels\"",
);
if (!Number.isInteger(platformLabelTest?.testsPassed) ||
  platformLabelTest.testsPassed < 1) {
  errors.push("platform feature label validation must record at least one passed test.");
}

const unavailableScreenTest = validationsByCommand.get(
  "flutter test test/feature_unavailable_screen_test.dart",
);
if (!Number.isInteger(unavailableScreenTest?.testsPassed) ||
  unavailableScreenTest.testsPassed < 3) {
  errors.push("feature unavailable screen validation must record at least three passed tests.");
}

const referenceModalsTest = validationsByCommand.get(
  "flutter test test/fz_reference_modals_test.dart",
);
if (!Number.isInteger(referenceModalsTest?.testsPassed) ||
  referenceModalsTest.testsPassed < 1) {
  errors.push("reference modal copy validation must record at least one passed test.");
}

const orderProviderTest = validationsByCommand.get(
  "flutter test test/features/ordering/order_provider_test.dart",
);
if (!Number.isInteger(orderProviderTest?.testsPassed) ||
  orderProviderTest.testsPassed < 1) {
  errors.push("order provider checkout error copy validation must record at least one passed test.");
}

const appTelemetryTest = validationsByCommand.get(
  "flutter test test/app_telemetry_test.dart",
);
if (!Number.isInteger(appTelemetryTest?.testsPassed) ||
  appTelemetryTest.testsPassed < 2) {
  errors.push("app telemetry redaction validation must record at least two passed tests.");
}

const legalReadiness = validationsByCommand.get(
  "node tool/validate_privacy_legal_readiness_evidence.mjs",
);
if (!legalReadiness || legalReadiness.status !== "EXPECTED_FAIL") {
  errors.push(
    "privacy/legal readiness validator must be recorded as EXPECTED_FAIL until human legal signoff exists.",
  );
} else {
  const remaining = new Set(legalReadiness.remainingFailures || []);
  for (const failure of expectedReadinessFailures) {
    if (!remaining.has(failure)) {
      errors.push(`privacy/legal readiness expected failure missing: ${failure}`);
    }
  }
}

if (!Array.isArray(data.remainingNotes) ||
  !data.remainingNotes.some((note) => String(note).includes("Human legal review"))) {
  errors.push("remainingNotes must preserve human legal review as a required external gate.");
}

if (errors.length > 0) {
  console.error(`Privacy/legal code evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Privacy/legal code evidence validation passed for ${targetPath}.`);
