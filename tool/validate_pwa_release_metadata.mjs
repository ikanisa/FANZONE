#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(toolDir, "..");

const surfaces = {
  admin: {
    appDir: "apps/admin",
    expectedName: "FANZONE Admin",
    expectedShortName: "FANZONE Admin",
    expectedThemeColor: "#0C0A09",
    requiredHeaderMode: "DENY",
    appleTouchIconHref: "/apple-touch-icon.png",
  },
  "venue-portal": {
    appDir: "apps/venue-portal",
    expectedName: "FANZONE Venue Dashboard",
    expectedShortName: "FZ Venue",
    expectedThemeColor: "#050507",
    requiredHeaderMode: "DENY",
    appleTouchIconHref: "/brand/logo-mark-256.png",
  },
  "tv-display": {
    appDir: "apps/tv-display",
    expectedName: "FANZONE TV Display",
    expectedShortName: "FZ TV",
    expectedThemeColor: "#050507",
    requiredHeaderMode: "SAMEORIGIN",
    appleTouchIconHref: "/brand/logo-mark-256.png",
  },
};

function usage() {
  console.error(
    `Usage: ${path.basename(process.argv[1])} <${Object.keys(surfaces).join("|")}>`,
  );
}

async function readText(filePath, label) {
  try {
    return await fs.readFile(filePath, "utf8");
  } catch (error) {
    throw new Error(`Could not read ${label} at ${filePath}: ${error.message}`);
  }
}

async function readJson(filePath, label) {
  try {
    return JSON.parse(await readText(filePath, label));
  } catch (error) {
    throw new Error(`Could not parse ${label} at ${filePath}: ${error.message}`);
  }
}

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function collectFilesByExtension(dirPath, extension) {
  const files = [];

  if (!(await exists(dirPath))) {
    return files;
  }

  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    const entryPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectFilesByExtension(entryPath, extension)));
    } else if (entry.isFile() && entry.name.endsWith(extension)) {
      files.push(entryPath);
    }
  }

  return files;
}

function hasTag(html, pattern) {
  return pattern.test(html);
}

function collectIndexErrors(html, config) {
  const errors = [];

  if (!hasTag(html, /<link\b[^>]*rel=["']manifest["'][^>]*href=["']\/site\.webmanifest["'][^>]*>/i)) {
    errors.push("index.html must link /site.webmanifest.");
  }

  const escapedAppleHref = config.appleTouchIconHref.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  if (!hasTag(html, new RegExp(`<link\\b[^>]*rel=["']apple-touch-icon["'][^>]*href=["']${escapedAppleHref}["'][^>]*>`, "i"))) {
    errors.push("index.html must link the Apple touch icon.");
  }

  if (!hasTag(html, /<meta\b[^>]*name=["']description["'][^>]*content=["'][^"']{24,}["'][^>]*>/i)) {
    errors.push("index.html must include a meaningful description meta tag.");
  }

  const escapedTheme = config.expectedThemeColor.replace("#", "\\#");
  if (!hasTag(html, new RegExp(`<meta\\b[^>]*name=["']theme-color["'][^>]*content=["']${escapedTheme}["'][^>]*>`, "i"))) {
    errors.push(`index.html must set theme-color to ${config.expectedThemeColor}.`);
  }

  if (!hasTag(html, /<meta\b[^>]*name=["']mobile-web-app-capable["'][^>]*content=["']yes["'][^>]*>/i)) {
    errors.push('index.html must set mobile-web-app-capable to "yes".');
  }

  if (!hasTag(html, /<meta\b[^>]*name=["']apple-mobile-web-app-capable["'][^>]*content=["']yes["'][^>]*>/i)) {
    errors.push('index.html must set apple-mobile-web-app-capable to "yes".');
  }

  return errors;
}

async function collectManifestErrors(appRoot, manifest, config) {
  const errors = [];

  if (manifest?.name !== config.expectedName) {
    errors.push(`site.webmanifest name must be "${config.expectedName}".`);
  }

  if (manifest?.short_name !== config.expectedShortName) {
    errors.push(`site.webmanifest short_name must be "${config.expectedShortName}".`);
  }

  if (manifest?.start_url !== "/") {
    errors.push('site.webmanifest start_url must remain "/".');
  }

  if (manifest?.display !== "standalone") {
    errors.push('site.webmanifest display must be "standalone".');
  }

  if (manifest?.theme_color !== config.expectedThemeColor) {
    errors.push(`site.webmanifest theme_color must be ${config.expectedThemeColor}.`);
  }

  if (!Array.isArray(manifest?.icons) || manifest.icons.length < 2) {
    errors.push("site.webmanifest must declare at least two icons.");
    return errors;
  }

  for (const [index, icon] of manifest.icons.entries()) {
    if (typeof icon?.src !== "string" || !icon.src.startsWith("/")) {
      errors.push(`site.webmanifest icon ${index} must use an absolute src.`);
      continue;
    }

    const iconPath = path.join(appRoot, "public", icon.src);
    if (!(await exists(iconPath))) {
      errors.push(`site.webmanifest icon ${index} is missing: ${icon.src}.`);
    }
  }

  return errors;
}

function collectHeadersErrors(headers, config) {
  const errors = [];
  const requiredHeaders = [
    "X-Content-Type-Options",
    "Referrer-Policy",
    "Permissions-Policy",
    "Content-Security-Policy",
    "Strict-Transport-Security",
  ];

  for (const header of requiredHeaders) {
    if (!new RegExp(`^\\s*${header}:`, "im").test(headers)) {
      errors.push(`_headers must declare ${header}.`);
    }
  }

  if (!new RegExp(`^\\s*X-Frame-Options:\\s*${config.requiredHeaderMode}\\b`, "im").test(headers)) {
    errors.push(`_headers must set X-Frame-Options: ${config.requiredHeaderMode}.`);
  }

  if (!/Cache-Control:\s*public,\s*max-age=31536000,\s*immutable/im.test(headers)) {
    errors.push("_headers must cache immutable built assets.");
  }

  if (!/Cache-Control:\s*no-cache,\s*no-store,\s*must-revalidate/im.test(headers)) {
    errors.push("_headers must prevent index.html caching.");
  }

  return errors;
}

async function collectFontPolicyErrors(appRoot, headers, html) {
  const errors = [];
  const cssFiles = await collectFilesByExtension(path.join(appRoot, "src"), ".css");
  const sourceText = [
    html,
    ...(await Promise.all(cssFiles.map((filePath) => readText(filePath, filePath)))),
  ].join("\n");

  if (!sourceText.includes("fonts.googleapis.com")) {
    return errors;
  }

  if (!/style-src[^;]*https:\/\/fonts\.googleapis\.com/i.test(headers)) {
    errors.push("_headers CSP style-src must allow Google Fonts stylesheet imports used by the app.");
  }

  if (!/font-src[^;]*https:\/\/fonts\.gstatic\.com/i.test(headers)) {
    errors.push("_headers CSP font-src must allow Google Fonts font files used by the app.");
  }

  return errors;
}

async function main() {
  const surface = process.argv[2];
  const config = surfaces[surface];
  if (!config) {
    usage();
    process.exitCode = 2;
    return;
  }

  const appRoot = path.join(repoRoot, config.appDir);
  const html = await readText(path.join(appRoot, "index.html"), "index.html");
  const manifest = await readJson(
    path.join(appRoot, "public", "site.webmanifest"),
    "site.webmanifest",
  );
  const headers = await readText(
    path.join(appRoot, "public", "_headers"),
    "_headers",
  );

  const errors = [
    ...collectIndexErrors(html, config),
    ...(await collectManifestErrors(appRoot, manifest, config)),
    ...collectHeadersErrors(headers, config),
    ...(await collectFontPolicyErrors(appRoot, headers, html)),
  ];

  if (errors.length > 0) {
    console.error(`${surface} PWA release metadata validation failed:`);
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log(`${surface} PWA release metadata validation passed.`);
}

await main();
