#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/whatsapp-otp-smoke-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/i;

const requiredSecretNames = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "FANZONE_JWT_SECRET",
  "WABA_ACCESS_TOKEN",
  "WABA_PHONE_NUMBER_ID",
  "WABA_OTP_TEMPLATE_NAME",
  "WABA_TEMPLATE_LANGUAGE",
  "WHATSAPP_AUTH_TEST_PHONE",
  "WHATSAPP_AUTH_TEST_OTP",
  "WHATSAPP_AUTH_TEST_EXPIRY",
];

const requiredFiles = [
  "supabase/functions/whatsapp-otp/index.ts",
  "supabase/functions/whatsapp-otp/index_test.ts",
  "tool/supabase_whatsapp_auth_smoke.sh",
  "docs/release/deployment-readme.md",
  "tool/validate_edge_function_release_contract.mjs",
  "tool/go_live_readiness.sh",
];

const requiredPassingCommands = [
  "deno fmt --check supabase/functions/whatsapp-otp/index.ts supabase/functions/whatsapp-otp/index_test.ts",
  "deno check supabase/functions/whatsapp-otp/index.ts supabase/functions/whatsapp-otp/index_test.ts",
  "deno test --allow-env supabase/functions/whatsapp-otp/index_test.ts",
  "supabase functions deploy whatsapp-otp --project-ref kjuhheobmdvjwgnzlcwx --use-api",
  "redacted HTTP smoke: POST /functions/v1/whatsapp-otp send + verify",
  "tool/supabase_whatsapp_auth_smoke.sh --dry-run",
  "node tool/validate_edge_function_release_contract.mjs",
  "bash -n tool/supabase_whatsapp_auth_smoke.sh tool/go_live_readiness.sh",
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
  console.error(`WhatsApp OTP evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential/token pattern.");
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
if (data.function?.name !== "whatsapp-otp") {
  errors.push("function.name must be whatsapp-otp.");
}
if (data.function?.status !== "ACTIVE") {
  errors.push("function.status must be ACTIVE.");
}
if (!Number.isInteger(data.function?.version) || data.function.version <= 0) {
  errors.push("function.version must be a positive integer.");
}
if (!isIsoDateTime(data.function?.updatedAtUtc)) {
  errors.push("function.updatedAtUtc must be an ISO UTC timestamp ending in Z.");
}

if (data.secretInventoryChecked?.valuesRedacted !== true) {
  errors.push("secretInventoryChecked.valuesRedacted must be true.");
}
const secretNames = new Set(
  data.secretInventoryChecked?.requiredRuntimeSecretNamesPresent || [],
);
for (const name of requiredSecretNames) {
  if (!secretNames.has(name)) {
    errors.push(`secret inventory is missing required runtime name ${name}.`);
  }
}

const smoke = data.remoteSmoke || {};
if (!/^\+\d{8,15}$/.test(smoke.phone || "")) {
  errors.push("remoteSmoke.phone must be an E.164 review phone number.");
}
if (smoke.otp !== "redacted-fixed-review-code") {
  errors.push("remoteSmoke.otp must be redacted-fixed-review-code.");
}
for (const [field, expected] of Object.entries({
  sendStatus: 200,
  sendSuccess: true,
  verifyStatus: 200,
  verifySuccess: true,
  tokenType: "bearer",
  userPresent: true,
  accessTokenRedacted: true,
  refreshTokenRedacted: true,
})) {
  if (smoke[field] !== expected) {
    errors.push(`remoteSmoke.${field} must be ${expected}.`);
  }
}

for (const file of requiredFiles) {
  if (!repoRefExists(file)) errors.push(`Required OTP implementation file is missing: ${file}`);
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

const testItem = validationsByCommand.get(
  "deno test --allow-env supabase/functions/whatsapp-otp/index_test.ts",
);
if (!Number.isInteger(testItem?.testsPassed) || testItem.testsPassed < 1) {
  errors.push("WhatsApp OTP Deno test evidence must include a positive testsPassed count.");
}

if (!Array.isArray(data.remainingNotes) || data.remainingNotes.length === 0) {
  errors.push("remainingNotes must describe provider-dependent residual risk.");
}

if (errors.length > 0) {
  console.error(`WhatsApp OTP evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`WhatsApp OTP evidence validation passed for ${targetPath}.`);
