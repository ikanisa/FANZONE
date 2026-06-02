#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const files = {
  metadata: "release/android/play-store-metadata.md",
  dataSafety: "release/android/data-safety-notes.md",
  appAccess: "release/android/app-access-instructions.md",
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

const metadata = read(files.metadata);
const dataSafety = read(files.dataSafety);
const appAccess = read(files.appAccess);
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

if (
  manifest.includes("android.permission.ACCESS_COARSE_LOCATION") ||
  manifest.includes("android.permission.ACCESS_FINE_LOCATION")
) {
  requireText("Data Safety notes", dataSafety, [
    "Yes, when the user enables location",
  ]);
}

const androidReviewText = [metadata, dataSafety, appAccess].join("\n");

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

if (failures.length > 0) {
  console.error("Android review metadata validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Android review metadata validation passed.");
