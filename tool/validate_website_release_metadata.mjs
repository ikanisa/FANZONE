#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";

const repoRoot = "/Volumes/PRO-G40/FANZONE";
const websiteRoot = path.join(repoRoot, "website");
const assetLinksPath = path.join(
  websiteRoot,
  "public",
  ".well-known",
  "assetlinks.json",
);
const appleAssociationPath = path.join(
  websiteRoot,
  "public",
  ".well-known",
  "apple-app-site-association",
);
const webManifestPath = path.join(websiteRoot, "public", "site.webmanifest");
const placeholderFingerprint =
  "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00";

async function readJson(filePath, label) {
  try {
    return JSON.parse(await fs.readFile(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not parse ${label} at ${filePath}: ${error.message}`);
  }
}

function collectAssetLinksErrors(assetLinks) {
  const errors = [];

  if (!Array.isArray(assetLinks) || assetLinks.length === 0) {
    errors.push("assetlinks.json must contain at least one target entry.");
    return errors;
  }

  for (const [index, entry] of assetLinks.entries()) {
    const target = entry?.target;
    const packageName = target?.package_name;
    const fingerprints = target?.sha256_cert_fingerprints;

    if (typeof packageName !== "string" || packageName.trim().length === 0) {
      errors.push(`assetlinks.json entry ${index} is missing target.package_name.`);
    }

    if (!Array.isArray(fingerprints) || fingerprints.length === 0) {
      errors.push(
        `assetlinks.json entry ${index} must declare at least one SHA-256 fingerprint.`,
      );
      continue;
    }

    for (const fingerprint of fingerprints) {
      if (typeof fingerprint !== "string" || fingerprint.trim().length === 0) {
        errors.push(
          `assetlinks.json entry ${index} contains an empty fingerprint value.`,
        );
        continue;
      }

      if (fingerprint === placeholderFingerprint) {
        errors.push(
          "assetlinks.json still contains the all-zero placeholder fingerprint.",
        );
      }
    }
  }

  return errors;
}

function collectAppleAssociationErrors(association) {
  const errors = [];
  const details = association?.applinks?.details;

  if (!Array.isArray(details) || details.length === 0) {
    errors.push(
      "apple-app-site-association must declare at least one applinks.details entry.",
    );
    return errors;
  }

  for (const [index, detail] of details.entries()) {
    if (typeof detail?.appID !== "string" || detail.appID.trim().length === 0) {
      errors.push(
        `apple-app-site-association entry ${index} is missing a non-empty appID.`,
      );
    }
  }

  return errors;
}

function collectManifestErrors(manifest) {
  const errors = [];

  if (manifest?.name !== "FANZONE") {
    errors.push('site.webmanifest name must remain "FANZONE".');
  }

  if (manifest?.start_url !== "/") {
    errors.push('site.webmanifest start_url must remain "/".');
  }

  if (!Array.isArray(manifest?.icons) || manifest.icons.length === 0) {
    errors.push("site.webmanifest must declare at least one icon.");
  }

  return errors;
}

async function main() {
  const assetLinks = await readJson(assetLinksPath, "assetlinks.json");
  const appleAssociation = await readJson(
    appleAssociationPath,
    "apple-app-site-association",
  );
  const webManifest = await readJson(webManifestPath, "site.webmanifest");

  const errors = [
    ...collectAssetLinksErrors(assetLinks),
    ...collectAppleAssociationErrors(appleAssociation),
    ...collectManifestErrors(webManifest),
  ];

  if (errors.length > 0) {
    console.error("Website release metadata validation failed:");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log("Website release metadata validation passed.");
}

await main();
