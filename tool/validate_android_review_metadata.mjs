#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const files = {
  metadata: "release/android/play-store-metadata.md",
  dataSafety: "release/android/data-safety-notes.md",
  appAccess: "release/android/app-access-instructions.md",
  previewAssetAltText: "release/android/preview-asset-alt-text.md",
  manifest: "android/app/src/main/AndroidManifest.xml",
};

const failures = [];

function read(filePath) {
  const absolute = path.resolve(root, filePath);
  if (!fs.existsSync(absolute)) {
    failures.push(`Missing required Android review metadata file: ${filePath}`);
    return "";
  }
  return fs.readFileSync(absolute, "utf8");
}

function requireText(label, source, required) {
  for (const text of required) {
    if (!source.includes(text)) {
      failures.push(`${label} is missing required review text: ${text}`);
    }
  }
}

function rejectPattern(label, source, pattern, message) {
  if (pattern.test(source)) {
    failures.push(`${label}: ${message}`);
  }
}

function hasNonGitkeepAsset(directory) {
  const absolute = path.resolve(root, directory);
  if (!fs.existsSync(absolute)) return false;
  return fs
    .readdirSync(absolute, { withFileTypes: true })
    .some((entry) => entry.isFile() && entry.name !== ".gitkeep");
}

function assetFiles(directory) {
  const absolute = path.resolve(root, directory);
  if (!fs.existsSync(absolute)) return [];
  return fs
    .readdirSync(absolute, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name !== ".gitkeep")
    .map((entry) => path.join(directory, entry.name));
}

function pngInfo(filePath) {
  const buffer = fs.readFileSync(path.resolve(root, filePath));
  const pngSignature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") !== pngSignature) {
    return null;
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    bitDepth: buffer.readUInt8(24),
    colorType: buffer.readUInt8(25),
    sizeBytes: buffer.length,
  };
}

function validateRgbPng(filePath, label) {
  const info = pngInfo(filePath);
  if (!info) {
    failures.push(`${label} must be a PNG asset: ${filePath}`);
    return null;
  }
  if (info.bitDepth !== 8 || info.colorType !== 2) {
    failures.push(
      `${label} must be 24-bit RGB PNG with no alpha: ${filePath}`,
    );
  }
  return info;
}

const metadata = read(files.metadata);
const dataSafety = read(files.dataSafety);
const appAccess = read(files.appAccess);
const previewAssetAltText = read(files.previewAssetAltText);
const manifest = read(files.manifest);

requireText("Play metadata", metadata, [
  "Package name: `app.fanzone.football`",
  "Privacy policy URL: `https://fanzone.ikanisa.com/privacy`",
  "FET is a closed-loop engagement and reward point",
  "FET is not cash, not crypto trading, not an investment, and cannot be cashed out.",
  "No wagers, cash prizes, monetary prizes, odds, or cash-out are offered.",
  "FANZONE does not process card, bank, MoMo, or Revolut payments in the MVP release.",
]);

requireText("Data Safety notes", dataSafety, [
  "Phone number",
  "WhatsApp OTP authentication",
  "Location",
  "Nearby venue discovery",
  "The Android build declares coarse and fine location permissions",
  "Prediction pools and games are free-to-play",
  "The app does not contain real-money wagering or gambling mechanics.",
  "FANZONE does not process payments.",
]);

requireText("App access instructions", appAccess, [
  "FANZONE uses WhatsApp OTP login only.",
  "WHATSAPP_AUTH_TEST_PHONE",
  "WHATSAPP_AUTH_TEST_OTP",
  "actual reviewer phone only in Play Console",
  "actual reviewer OTP only in Play Console",
  "Do not commit it.",
  "FET rewards are closed-loop app/venue reward points with no cash-out.",
]);

requireText("Preview asset alt text", previewAssetAltText, [
  "phone_01_onboarding.png",
  "phone_02_whatsapp_login.png",
  "Get Started button",
  "OTP button",
  "no-wager",
  "no-cash-out",
]);

if (
  manifest.includes("android.permission.ACCESS_COARSE_LOCATION") ||
  manifest.includes("android.permission.ACCESS_FINE_LOCATION")
) {
  requireText("Data Safety notes", dataSafety, [
    "Yes, when the user enables location",
  ]);
}

const androidReviewText = [
  metadata,
  dataSafety,
  appAccess,
  previewAssetAltText,
].join("\n");

rejectPattern(
  "Android review metadata",
  androidReviewText,
  /\b(fet wallet|fet wallets|wallet balance|wallet activity|wallet transfer|wallet ledger|open wallet|sports-bar wallet)\b/i,
  "Use FET reward-points or rewards-ledger language, not wallet language.",
);
rejectPattern(
  "Android review metadata",
  androidReviewText,
  /\b(jackpot|paid prediction|paid predictions|pooled prize|pooled prizes)\b|(?<!do not )\boffers?\b[^.]{0,48}\b(cash prize|cash prizes|monetary prize|monetary prizes)\b|(?:win|wins|receive|receives|claim|claims|get|gets)[^.]{0,48}\b(cash prize|cash prizes|monetary prize|monetary prizes)\b/i,
  "Store metadata must not imply cash prizes, paid predictions, jackpots, or pooled prizes.",
);
rejectPattern(
  "Android app-access instructions",
  appAccess,
  /\+\d{8,}|\b\d{6}\b|Current UAT fixture/i,
  "Do not keep reviewer phone numbers, OTPs, or UAT fixture credentials in tracked reviewer instructions.",
);
rejectPattern(
  "Android review metadata",
  androidReviewText,
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/,
  "Tracked Android review metadata appears to contain a live credential pattern.",
);

if (!hasNonGitkeepAsset("release/android/screenshots")) {
  failures.push(
    "release/android/screenshots must contain Play screenshot assets, not only .gitkeep.",
  );
}

if (!hasNonGitkeepAsset("release/android/feature-graphic")) {
  failures.push(
    "release/android/feature-graphic must contain the Play feature graphic asset, not only .gitkeep.",
  );
}

const screenshots = assetFiles("release/android/screenshots");
if (screenshots.length < 2 || screenshots.length > 8) {
  failures.push(
    `release/android/screenshots must contain 2 to 8 phone screenshots; found ${screenshots.length}.`,
  );
}
for (const screenshot of screenshots) {
  const info = validateRgbPng(screenshot, "Android screenshot");
  if (!info) continue;
  const minDimension = Math.min(info.width, info.height);
  const maxDimension = Math.max(info.width, info.height);
  if (minDimension < 320 || maxDimension > 3840) {
    failures.push(
      `Android screenshot dimensions must stay within 320px and 3840px: ${screenshot} is ${info.width}x${info.height}.`,
    );
  }
  if (maxDimension > minDimension * 2) {
    failures.push(
      `Android screenshot aspect ratio must not exceed 2:1: ${screenshot} is ${info.width}x${info.height}.`,
    );
  }
  if (info.sizeBytes > 8 * 1024 * 1024) {
    failures.push(
      `Android screenshot must be 8MB or smaller: ${screenshot} is ${info.sizeBytes} bytes.`,
    );
  }
}

const featureGraphics = assetFiles("release/android/feature-graphic");
if (featureGraphics.length !== 1) {
  failures.push(
    `release/android/feature-graphic must contain exactly one feature graphic; found ${featureGraphics.length}.`,
  );
}
for (const featureGraphic of featureGraphics) {
  const info = validateRgbPng(featureGraphic, "Android feature graphic");
  if (!info) continue;
  if (info.width !== 1024 || info.height !== 500) {
    failures.push(
      `Android feature graphic must be 1024x500: ${featureGraphic} is ${info.width}x${info.height}.`,
    );
  }
}

if (failures.length > 0) {
  console.error("Android review metadata validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Android review metadata validation passed.");
