#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/edge-cors-smoke-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._-]{20,})/i;

const requiredProjectRef = "kjuhheobmdvjwgnzlcwx";
const requiredCommand = "node tool/capture_edge_cors_smoke.mjs";
const requiredFunctions = [
  "whatsapp-otp",
  "generate-pool-social-card",
];
const requiredAllowedOrigins = [
  "https://fanzone.ikanisa.com",
  "https://fanzoneadmin.ikanisa.com",
  "https://fanzone.venue.ikanisa.com",
  "https://fanzonetv.ikanisa.com",
];
const requiredBlockedOriginHash =
  "e55db36714faa6af771365d32a014c394178af5e4633e902a340d65fe39e581b";

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoUtc(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function includesAll(actual, expected) {
  if (!Array.isArray(actual)) return false;
  const actualSet = new Set(actual);
  return expected.every((item) => actualSet.has(item));
}

function hasHeaderToken(value, expectedToken) {
  return String(value || "")
    .split(",")
    .map((token) => token.trim().toLowerCase())
    .includes(expectedToken.toLowerCase());
}

function validateAllowedCheck(errors, check, expectedFunction, expectedOrigin) {
  const label = `${expectedFunction} ${expectedOrigin}`;
  if (!check) {
    errors.push(`Missing allowed-origin check for ${label}.`);
    return;
  }
  if (check.functionName !== expectedFunction) {
    errors.push(`${label} functionName mismatch.`);
  }
  if (check.origin !== expectedOrigin) {
    errors.push(`${label} origin mismatch.`);
  }
  if (check.expectedAllowed !== true) {
    errors.push(`${label} expectedAllowed must be true.`);
  }
  if (check.passed !== true) {
    errors.push(`${label} passed must be true.`);
  }
  if (!Number.isInteger(check.status) || check.status < 200 || check.status >= 300) {
    errors.push(`${label} status must be a 2xx integer.`);
  }
  if (check.accessControlAllowOrigin !== expectedOrigin) {
    errors.push(`${label} must reflect the exact request origin.`);
  }
  if (check.accessControlAllowOrigin === "*") {
    errors.push(`${label} must not allow wildcard CORS.`);
  }
  if (!hasHeaderToken(check.accessControlAllowMethods, "POST")) {
    errors.push(`${label} must allow POST.`);
  }
  if (!hasHeaderToken(check.accessControlAllowHeaders, "authorization")) {
    errors.push(`${label} must allow the authorization header.`);
  }
  if (!hasHeaderToken(check.vary, "Origin")) {
    errors.push(`${label} must vary by Origin.`);
  }
}

function validateBlockedCheck(errors, check, expectedFunction) {
  const label = `${expectedFunction} blocked origin`;
  if (!check) {
    errors.push(`Missing blocked-origin check for ${expectedFunction}.`);
    return;
  }
  if (check.functionName !== expectedFunction) {
    errors.push(`${label} functionName mismatch.`);
  }
  if (check.expectedAllowed !== false) {
    errors.push(`${label} expectedAllowed must be false.`);
  }
  if (check.passed !== true) {
    errors.push(`${label} passed must be true.`);
  }
  if (check.accessControlAllowOrigin !== "") {
    errors.push(`${label} must not return access-control-allow-origin.`);
  }
}

const errors = [];

if (!fs.existsSync(absolutePath)) {
  console.error(`Edge CORS smoke evidence validation failed for ${targetPath}:`);
  console.error("- evidence file does not exist.");
  process.exit(1);
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Edge CORS smoke evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

let data;
try {
  data = JSON.parse(raw);
} catch (error) {
  console.error(`Edge CORS smoke evidence validation failed for ${targetPath}:`);
  console.error(`- could not parse JSON: ${error.message}`);
  process.exit(1);
}

if (data.schemaVersion !== 1) {
  errors.push("schemaVersion must be 1.");
}
if (!isIsoUtc(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== requiredProjectRef) {
  errors.push(`projectRef must be ${requiredProjectRef}.`);
}
if (data.command !== requiredCommand) {
  errors.push(`command must be ${requiredCommand}.`);
}
if (data.status !== "PASS") {
  errors.push("status must be PASS.");
}
if (!hasText(data.scope) || !data.scope.includes("deployed Supabase Edge CORS")) {
  errors.push("scope must describe deployed Supabase Edge CORS.");
}
if (!includesAll(data.functions, requiredFunctions)) {
  errors.push("functions must include all browser-callable Edge functions under smoke.");
}
if (!includesAll(data.allowedOrigins, requiredAllowedOrigins)) {
  errors.push("allowedOrigins must include all production browser origins.");
}
if (!includesAll(data.blockedOriginHashes, [requiredBlockedOriginHash])) {
  errors.push("blockedOriginHashes must include the blocked-origin hash.");
}

const checks = Array.isArray(data.checks) ? data.checks : [];
const expectedCheckCount =
  requiredFunctions.length * (requiredAllowedOrigins.length + 1);
if (checks.length < expectedCheckCount) {
  errors.push(`checks must include at least ${expectedCheckCount} entries.`);
}
if (!checks.every((check) => check?.passed === true)) {
  errors.push("every check must pass.");
}

for (const functionName of requiredFunctions) {
  for (const origin of requiredAllowedOrigins) {
    validateAllowedCheck(
      errors,
      checks.find((check) =>
        check?.functionName === functionName &&
        check?.origin === origin &&
        check?.expectedAllowed === true
      ),
      functionName,
      origin,
    );
  }
  validateBlockedCheck(
    errors,
    checks.find((check) =>
      check?.functionName === functionName &&
      check?.expectedAllowed === false &&
      check?.originSha256 === requiredBlockedOriginHash
    ),
    functionName,
  );
}

if (errors.length > 0) {
  console.error(`Edge CORS smoke evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Edge CORS smoke evidence validation passed for ${targetPath}.`);
