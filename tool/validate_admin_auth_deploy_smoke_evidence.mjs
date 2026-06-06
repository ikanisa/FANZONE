#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/admin-auth-deploy-smoke-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._-]{20,}|set-cookie)/i;

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoUtc(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

if (!fs.existsSync(absolutePath)) {
  console.error(`Admin auth deploy smoke validation failed for ${targetPath}:`);
  console.error("- evidence file does not exist.");
  process.exit(1);
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Admin auth deploy smoke validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a credential or cookie pattern.");
  process.exit(1);
}

let data;
try {
  data = JSON.parse(raw);
} catch (error) {
  console.error(`Admin auth deploy smoke validation failed for ${targetPath}:`);
  console.error(`- could not parse JSON: ${error.message}`);
  process.exit(1);
}

const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoUtc(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}
if (data.command !== "node tool/capture_admin_auth_deploy_smoke.mjs") {
  errors.push("command must be node tool/capture_admin_auth_deploy_smoke.mjs.");
}
if (data.status !== "PASS") errors.push("status must be PASS.");
if (data.functionName !== "admin_user_management") {
  errors.push("functionName must be admin_user_management.");
}
if (!String(data.scope || "").includes("admin authorization boundary")) {
  errors.push("scope must describe admin authorization boundary smoke.");
}

const deployment = data.deployment || {};
if (deployment.name !== "admin_user_management") {
  errors.push("deployment.name must be admin_user_management.");
}
if (deployment.slug !== "admin_user_management") {
  errors.push("deployment.slug must be admin_user_management.");
}
if (deployment.status !== "ACTIVE") {
  errors.push("deployment.status must be ACTIVE.");
}
if (!Number.isInteger(deployment.version) || deployment.version < 15) {
  errors.push("deployment.version must be at least 15.");
}
if (!isIsoUtc(deployment.updatedAtUtc)) {
  errors.push("deployment.updatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(deployment.idSha256) || deployment.idSha256.length !== 64) {
  errors.push("deployment.idSha256 must be a SHA-256 hash.");
}

const anonymousPost = data.anonymousPost || {};
if (anonymousPost.status !== 401) {
  errors.push("anonymousPost.status must be 401.");
}
if (anonymousPost.responseCode !== "UNAUTHORIZED_NO_AUTH_HEADER") {
  errors.push("anonymousPost.responseCode must be UNAUTHORIZED_NO_AUTH_HEADER.");
}
if (anonymousPost.sbErrorCode !== "UNAUTHORIZED_NO_AUTH_HEADER") {
  errors.push("anonymousPost.sbErrorCode must be UNAUTHORIZED_NO_AUTH_HEADER.");
}
if (anonymousPost.sbProjectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("anonymousPost.sbProjectRef must match the linked project.");
}
if (!String(anonymousPost.strictTransportSecurity || "").includes("max-age=")) {
  errors.push("anonymousPost.strictTransportSecurity must be present.");
}
if (!String(anonymousPost.responseMessage || "").includes("authorization")) {
  errors.push("anonymousPost.responseMessage must mention authorization.");
}

if (!Array.isArray(data.notes) || data.notes.length < 2) {
  errors.push("notes must describe the smoke scope.");
}

if (errors.length > 0) {
  console.error(`Admin auth deploy smoke validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Admin auth deploy smoke validation passed for ${targetPath}.`);
