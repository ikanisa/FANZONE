#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const files = {
  websiteLegalPage: "apps/website/src/components/LegalPage.tsx",
  privacyPolicy: "docs/privacy-policy.md",
  legalPrivacyEvidence: "release/legal/privacy-policy.md",
  legalTerms: "release/legal/terms.md",
  fetTerms: "release/legal/fet-reward-terms.md",
  androidDataSafety: "release/android/data-safety-notes.md",
  androidAppAccess: "release/android/app-access-instructions.md",
  iosPrivacyLabels: "release/ios/privacy-label-notes.md",
  iosAppMetadata: "release/ios/app-store-metadata.md",
  iosReviewNotes: "release/ios/app-review-notes.md",
  releaseChecklist: "docs/release-checklist.md",
  playStoreListing: "docs/play-store-listing.md",
};

const failures = [];

function read(filePath) {
  const absolute = path.resolve(root, filePath);
  if (!fs.existsSync(absolute)) {
    failures.push(`Missing privacy/legal public surface file: ${filePath}`);
    return "";
  }
  return fs.readFileSync(absolute, "utf8");
}

function requireText(label, source, required) {
  for (const text of required) {
    if (!source.includes(text)) {
      failures.push(`${label} is missing required public/privacy copy: ${text}`);
    }
  }
}

function rejectPattern(label, source, pattern, message) {
  if (pattern.test(source)) failures.push(`${label}: ${message}`);
}

const sources = Object.fromEntries(
  Object.entries(files).map(([key, filePath]) => [key, read(filePath)]),
);

requireText("Website legal pages", sources.websiteLegalPage, [
  "FANZONE Privacy Policy",
  "FANZONE does not process payment cards, bank accounts, MoMo credentials, or Revolut credentials",
  "FANZONE does not sell personal data.",
  "Users may request account deletion",
  "FANZONE Terms of Use",
  "Payment is external",
  "FANZONE does not process external payment credentials",
  "FANZONE fan challenges are free to enter.",
  "FET points are non-cash rewards and cannot be sold, withdrawn, or redeemed as money.",
  "FET Reward Terms",
  "FET is not cash, not cryptocurrency trading, not a financial instrument, not an investment product, and not withdrawable.",
  "user ledgers must not go negative",
  "FANZONE Help",
  "You can request account deletion from the app where available",
]);

requireText("Canonical privacy policy", sources.privacyPolicy, [
  "WhatsApp-enabled phone number",
  "Firebase Cloud Messaging (FCM) tokens",
  "We do not process card numbers, bank credentials, MoMo credentials, Revolut credentials, or other external payment credentials.",
  "We do not access your camera, photo library, or any media files.",
  "We do not access your address book or contact list.",
  "Data export and access requests can be made through the same contact channel.",
  "Settings → Request Account Deletion",
]);

requireText("Release legal terms", sources.legalTerms, [
  "Payment is external",
  "FANZONE does not process payment credentials",
  "FANZONE is not a betting, gambling, cash-out, odds, or wagering platform.",
  "FET cannot be redeemed for cash, withdrawn, sold, traded externally, or treated as an investment product.",
]);

requireText("FET reward terms", sources.fetTerms, [
  "FET is not cash, not cryptocurrency trading, not a financial instrument, not an investment product, and not withdrawable.",
  "Every FET movement must be recorded in the rewards ledger.",
  "User rewards ledgers must not go negative.",
]);

requireText("Android Data Safety notes", sources.androidDataSafety, [
  "WhatsApp OTP authentication",
  "The app does not process external payment credentials or bank/card details.",
  "FET is a closed-loop reward point",
  "The app does not contain real-money wagering or gambling mechanics.",
]);

requireText("iOS review notes", sources.iosReviewNotes, [
  "actual reviewer phone and OTP only in App Store Connect review notes or a private release evidence bundle",
  "FET is a closed-loop engagement and reward point.",
  "FET rewards-ledger activity.",
]);

const publicCopy = [
  sources.websiteLegalPage,
  sources.privacyPolicy,
  sources.legalPrivacyEvidence,
  sources.legalTerms,
  sources.fetTerms,
  sources.androidDataSafety,
  sources.androidAppAccess,
  sources.iosPrivacyLabels,
  sources.iosAppMetadata,
  sources.iosReviewNotes,
  sources.releaseChecklist,
  sources.playStoreListing,
].join("\n");

rejectPattern(
  "Privacy/legal public surfaces",
  publicCopy,
  /\b(fet wallet|fet wallets|wallet balance|wallet balances|wallet activity|wallet transfer|wallet ledger|open wallet|sports-bar wallet)\b/i,
  "Use FET reward-points or rewards-ledger language, not wallet language.",
);

rejectPattern(
  "Privacy/legal public surfaces",
  publicCopy,
  /\b(jackpot|paid prediction|paid predictions|pooled prize|pooled prizes)\b|(?<!do not )\boffers?\b[^.]{0,48}\b(cash prize|cash prizes|monetary prize|monetary prizes)\b|(?:win|wins|receive|receives|claim|claims|get|gets)[^.]{0,48}\b(cash prize|cash prizes|monetary prize|monetary prizes)\b/i,
  "Public/reviewer copy must not imply cash prizes, paid predictions, jackpots, or pooled prizes.",
);

rejectPattern(
  "Tracked store-review instructions",
  [
    sources.androidAppAccess,
    sources.iosReviewNotes,
    sources.releaseChecklist,
    sources.playStoreListing,
  ].join("\n"),
  /\+\d{8,}|\b\d{6}\b|UAT fixture/i,
  "Do not keep reviewer phone numbers, OTPs, or UAT fixture credentials in tracked store-review instructions.",
);

rejectPattern(
  "Privacy/legal public surfaces",
  publicCopy,
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/,
  "Tracked privacy/legal copy appears to contain a live credential pattern.",
);

if (failures.length > 0) {
  console.error("Privacy/legal public surface copy validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Privacy/legal public surface copy validation passed.");
