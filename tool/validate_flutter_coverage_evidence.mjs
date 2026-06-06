#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath = process.argv[2] || "release/qa/flutter-coverage-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

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

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
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

function parseLcov(lcovText) {
  let lineFound = 0;
  let lineHit = 0;
  let files = 0;
  for (const rawLine of lcovText.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.startsWith("SF:")) files += 1;
    if (line.startsWith("LF:")) lineFound += Number(line.slice(3)) || 0;
    if (line.startsWith("LH:")) lineHit += Number(line.slice(3)) || 0;
  }
  return {
    files,
    lineFound,
    lineHit,
    lineCoveragePercent: lineFound === 0 ? 0 : Number(((lineHit / lineFound) * 100).toFixed(2)),
  };
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Flutter coverage evidence validation failed for ${targetPath}:`);
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
if (!String(data.scope || "").includes("Flutter")) {
  errors.push("scope must describe Flutter coverage.");
}

if (data.command !== "flutter test --coverage") {
  errors.push("command must be flutter test --coverage.");
}
if (data.status !== "PASS") errors.push("status must be PASS.");
if (!Number.isInteger(data.testsFailed) || data.testsFailed !== 0) {
  errors.push("testsFailed must be 0.");
}
if (!Number.isInteger(data.testsPassed) || data.testsPassed <= 0) {
  errors.push("testsPassed must be a positive integer.");
}

if (!repoRefExists(data.log)) {
  errors.push(`log does not exist: ${data.log}`);
} else {
  const logText = fs.readFileSync(repoPath(data.log), "utf8");
  if (credentialPattern.test(logText)) {
    errors.push("log appears to contain a live credential pattern.");
  }
  for (const fragment of [
    "Status: PASS",
    `Tests passed: ${data.testsPassed}`,
    `LCOV SHA-256: ${data.lcovSha256}`,
  ]) {
    if (!logText.includes(fragment)) {
      errors.push(`log must include ${fragment}.`);
    }
  }
}
if (!repoRefExists(data.lcovPath)) {
  errors.push(`lcovPath does not exist: ${data.lcovPath}`);
} else {
  const lcovAbsolutePath = repoPath(data.lcovPath);
  const lcovText = fs.readFileSync(lcovAbsolutePath, "utf8");
  if (credentialPattern.test(lcovText)) {
    errors.push("lcovPath appears to contain a live credential pattern.");
  }
  const actualSha = sha256(lcovAbsolutePath);
  if (data.lcovSha256 !== actualSha) {
    errors.push("lcovSha256 does not match lcovPath.");
  }
  const parsed = parseLcov(lcovText);
  if (parsed.files <= 0) errors.push("coverage files must be positive.");
  if (parsed.lineFound <= 0) errors.push("coverage lineFound must be positive.");
  if (parsed.lineHit <= 0) errors.push("coverage lineHit must be positive.");
  if (data.coverage?.files !== parsed.files) {
    errors.push(`coverage.files must match lcov file count ${parsed.files}.`);
  }
  if (data.coverage?.lineFound !== parsed.lineFound) {
    errors.push(`coverage.lineFound must match lcov LF total ${parsed.lineFound}.`);
  }
  if (data.coverage?.lineHit !== parsed.lineHit) {
    errors.push(`coverage.lineHit must match lcov LH total ${parsed.lineHit}.`);
  }
  if (data.coverage?.lineCoveragePercent !== parsed.lineCoveragePercent) {
    errors.push(
      `coverage.lineCoveragePercent must match lcov percent ${parsed.lineCoveragePercent}.`,
    );
  }
}

const requiredAreas = [
  "Home",
  "Play",
  "Settings",
  "onboarding",
  "ordering",
  "games",
  "wallet",
];
const areas = Array.isArray(data.coveredAreas) ? data.coveredAreas.join("\n") : "";
for (const area of requiredAreas) {
  if (!areas.toLowerCase().includes(area.toLowerCase())) {
    errors.push(`coveredAreas must include ${area}.`);
  }
}

if (errors.length > 0) {
  console.error(`Flutter coverage evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Flutter coverage evidence validation passed for ${targetPath}.`);
