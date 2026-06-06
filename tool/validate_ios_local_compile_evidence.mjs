#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const evidencePath = process.argv[2] || "release/ios/testflight-readiness.json";
const data = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
const evidence = data.localUnsignedArchiveEvidence || {};
const errors = [];

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function existsFromRepo(value) {
  return hasText(value) && fs.existsSync(path.resolve(process.cwd(), value));
}

function sha256(filePath) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(filePath))
    .digest("hex");
}

function plistValue(plistPath, keyPath) {
  try {
    return execFileSync("/usr/libexec/PlistBuddy", ["-c", `Print ${keyPath}`, plistPath], {
      cwd: process.cwd(),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

if (evidence.status !== "PASS") {
  errors.push("localUnsignedArchiveEvidence.status must be PASS.");
}
if (!existsFromRepo(evidence.log)) {
  errors.push(`localUnsignedArchiveEvidence.log does not exist: ${evidence.log}`);
} else if (sha256(path.resolve(process.cwd(), evidence.log)) !== evidence.logSha256) {
  errors.push("localUnsignedArchiveEvidence.logSha256 does not match the log file.");
}
if (!existsFromRepo(evidence.archivePath)) {
  errors.push(`localUnsignedArchiveEvidence.archivePath does not exist: ${evidence.archivePath}`);
}
if (!Number.isInteger(evidence.archiveSizeKiB) || evidence.archiveSizeKiB <= 0) {
  errors.push("localUnsignedArchiveEvidence.archiveSizeKiB must be a positive integer.");
}

if (existsFromRepo(evidence.archivePath)) {
  const archiveInfoPath = path.resolve(process.cwd(), evidence.archivePath, "Info.plist");
  const appInfoPath = path.resolve(
    process.cwd(),
    evidence.archivePath,
    "Products/Applications/Runner.app/Info.plist",
  );
  if (!fs.existsSync(archiveInfoPath)) {
    errors.push(`Archive Info.plist does not exist: ${archiveInfoPath}`);
  } else {
    const bundleId = plistValue(archiveInfoPath, ":ApplicationProperties:CFBundleIdentifier");
    const versionName = plistValue(archiveInfoPath, ":ApplicationProperties:CFBundleShortVersionString");
    const buildNumber = plistValue(archiveInfoPath, ":ApplicationProperties:CFBundleVersion");
    const signingIdentity = plistValue(archiveInfoPath, ":ApplicationProperties:SigningIdentity");
    const team = plistValue(archiveInfoPath, ":ApplicationProperties:Team");
    if (bundleId !== evidence.bundleId) {
      errors.push(`Archive bundle id ${bundleId} does not match ${evidence.bundleId}.`);
    }
    if (String(versionName) !== String(evidence.versionName)) {
      errors.push("Archive versionName does not match evidence.");
    }
    if (Number(buildNumber) !== Number(evidence.buildNumber)) {
      errors.push("Archive buildNumber does not match evidence.");
    }
    if (hasText(signingIdentity) || hasText(team)) {
      errors.push("Local compile evidence must remain unsigned; signing identity/team was present.");
    }
  }
  if (!fs.existsSync(appInfoPath)) {
    errors.push(`Runner.app Info.plist does not exist: ${appInfoPath}`);
  }
}

if (errors.length > 0) {
  console.error(`iOS local compile evidence validation failed for ${evidencePath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("iOS local compile evidence validation passed.");
