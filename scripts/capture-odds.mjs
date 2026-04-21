#!/usr/bin/env node
/**
 * FANZONE — Screenshot-to-Multipliers Capture Tool
 *
 * Captures football 1X2 odds from official bookmaker websites (bwin)
 * using a local headless browser, then sends screenshots to the
 * Gemini Vision Edge Function for structured data extraction.
 *
 * NO external APIs — runs entirely on your machine.
 *
 * Usage:
 *   node capture-odds.mjs                        # Capture all leagues
 *   node capture-odds.mjs --league epl           # Premier League only
 *   node capture-odds.mjs --league ucl           # Champions League only
 *   node capture-odds.mjs --url "https://..."    # Custom URL
 *   node capture-odds.mjs --dry-run              # Capture only, don't send
 *   node capture-odds.mjs --scroll               # Capture with page scrolling (more matches)
 *
 * Schedule with cron (daily at 06:00):
 *   0 6 * * * cd /Volumes/PRO-G40/FANZONE && node scripts/capture-odds.mjs >> /tmp/fanzone-odds.log 2>&1
 *
 * Env:
 *   SUPABASE_URL          — project URL
 *   SUPABASE_SERVICE_KEY  — service role key
 *   CHROME_PATH           — optional Chrome path
 */

import puppeteerExtra from "puppeteer-extra";
import StealthPlugin from "puppeteer-extra-plugin-stealth";
import fs from "fs";
import path from "path";

puppeteerExtra.use(StealthPlugin());

// ─────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://kjuhheobmdvjwgnzlcwx.supabase.co";
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || "";
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/screenshot-odds-extract`;

const VIEWPORT = { width: 1440, height: 900 };
const PAGE_LOAD_WAIT_MS = 8000;     // Wait after navigation for SPA to render
const POST_ACTION_WAIT_MS = 3000;   // Wait after clicking/scrolling
const STABILIZATION_WAIT_MS = 2000; // Final wait before screenshot

// ─────────────────────────────────────────────────────────────
// bwin — Official bookmaker with clean 1X2 odds layout
// Confirmed working: renders full odds in headless Chrome
// ─────────────────────────────────────────────────────────────

const BWIN_LEAGUES = {
  // Featured (overview page with all sports/matches)
  featured: {
    name: "bwin Featured Football",
    url: "https://sports.bwin.com/en/sports/football-4",
  },
  // Major European leagues
  epl: {
    name: "Premier League",
    url: "https://sports.bwin.com/en/sports/football-4/betting/england-14/premier-league-46",
  },
  laliga: {
    name: "La Liga",
    url: "https://sports.bwin.com/en/sports/football-4/betting/spain-28/laliga-16108",
  },
  bundesliga: {
    name: "Bundesliga",
    url: "https://sports.bwin.com/en/sports/football-4/betting/germany-17/bundesliga-43",
  },
  seriea: {
    name: "Serie A",
    url: "https://sports.bwin.com/en/sports/football-4/betting/italy-20/serie-a-42",
  },
  ligue1: {
    name: "Ligue 1",
    url: "https://sports.bwin.com/en/sports/football-4/betting/france-16/ligue-1-4131",
  },
  // International
  ucl: {
    name: "Champions League",
    url: "https://sports.bwin.com/en/sports/football-4/betting/europe-7/champions-league-0:2",
  },
  uel: {
    name: "Europa League",
    url: "https://sports.bwin.com/en/sports/football-4/betting/europe-7/europa-league-0:3",
  },
  wcq: {
    name: "World Cup 2026",
    url: "https://sports.bwin.com/en/sports/football-4/betting/world-6/world-cup-2026-0:77",
  },
};

// Default: capture featured + all major leagues
const DEFAULT_LEAGUES = ["featured", "epl", "laliga", "bundesliga", "seriea", "ligue1", "ucl"];

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { leagues: [], url: null, dryRun: false, scroll: false, savePath: "/tmp" };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--league" && args[i + 1]) opts.leagues.push(args[++i]);
    else if (args[i] === "--url" && args[i + 1]) opts.url = args[++i];
    else if (args[i] === "--dry-run") opts.dryRun = true;
    else if (args[i] === "--scroll") opts.scroll = true;
    else if (args[i] === "--save-path" && args[i + 1]) opts.savePath = args[++i];
  }

  if (opts.leagues.length === 0 && !opts.url) opts.leagues = [...DEFAULT_LEAGUES];
  return opts;
}

// ─────────────────────────────────────────────────────────────
// bwin-specific: dismiss cookie banner + ensure 1X2 view
// ─────────────────────────────────────────────────────────────

async function dismissBwinCookies(page) {
  try {
    await page.evaluate(() => {
      const btns = [...document.querySelectorAll("button")];
      const allow = btns.find((b) => {
        const t = (b.textContent || "").toLowerCase().trim();
        return t.includes("allow all") || t.includes("accept");
      });
      if (allow) allow.click();
    });
  } catch {}
}

async function ensureBwin1X2View(page) {
  // bwin defaults to "Result 1X2" dropdown on football pages
  // but verify and click it if needed
  try {
    await page.evaluate(() => {
      const selects = [...document.querySelectorAll("select, [role=listbox]")];
      for (const sel of selects) {
        const options = sel.querySelectorAll
          ? [...sel.querySelectorAll("option")]
          : [];
        const x2opt = options.find((o) =>
          (o.textContent || "").includes("1X2"),
        );
        if (x2opt) {
          x2opt.selected = true;
          sel.dispatchEvent(new Event("change", { bubbles: true }));
        }
      }
    });
  } catch {}
}

// ─────────────────────────────────────────────────────────────
// Capture a single page with proper timing
// ─────────────────────────────────────────────────────────────

async function capturePage(browser, url, name, shouldScroll) {
  const page = await browser.newPage();
  const screenshots = [];

  try {
    await page.setViewport({
      ...VIEWPORT,
      deviceScaleFactor: 2,
    });

    console.log(`\n📸 [${name}] Navigating to: ${url}`);
    await page.goto(url, {
      waitUntil: "networkidle2",
      timeout: 45000,
    });

    // CRITICAL: Wait for SPA content to fully render (minimum 5s)
    console.log(`   ⏳ Waiting ${PAGE_LOAD_WAIT_MS}ms for full page render...`);
    await sleep(PAGE_LOAD_WAIT_MS);

    // Dismiss cookie banner
    console.log(`   🍪 Dismissing cookies...`);
    await dismissBwinCookies(page);
    await sleep(POST_ACTION_WAIT_MS);

    // Ensure 1X2 odds view is selected
    await ensureBwin1X2View(page);
    await sleep(STABILIZATION_WAIT_MS);

    // Take first screenshot (above the fold)
    const s1 = await page.screenshot({
      type: "png",
      fullPage: false,
      encoding: "binary",
    });
    const b64_1 = Buffer.from(s1).toString("base64");
    screenshots.push({ base64: b64_1, section: "top" });
    console.log(
      `   ✅ Screenshot 1/1 captured (${(b64_1.length / 1024).toFixed(0)} KB)`,
    );

    // If scroll mode: scroll down and take additional screenshots
    if (shouldScroll) {
      for (let scrollIdx = 1; scrollIdx <= 2; scrollIdx++) {
        console.log(`   📜 Scrolling down (pass ${scrollIdx})...`);
        await page.evaluate(() => window.scrollBy(0, 800));
        await sleep(POST_ACTION_WAIT_MS);

        const sN = await page.screenshot({
          type: "png",
          fullPage: false,
          encoding: "binary",
        });
        const b64_n = Buffer.from(sN).toString("base64");
        screenshots.push({ base64: b64_n, section: `scroll_${scrollIdx}` });
        console.log(
          `   ✅ Screenshot ${scrollIdx + 1} captured (${(b64_n.length / 1024).toFixed(0)} KB)`,
        );
      }
    }

    return screenshots;
  } finally {
    await page.close();
  }
}

// ─────────────────────────────────────────────────────────────
// Send to Edge Function
// ─────────────────────────────────────────────────────────────

async function sendToEdgeFunction(imageBase64) {
  if (!SUPABASE_SERVICE_KEY) {
    console.log("   ⚠️  SUPABASE_SERVICE_KEY not set — skipping upload.");
    return null;
  }

  console.log(`   📤 Sending to Gemini Vision Edge Function...`);

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({
      imageBase64,
      trigger: "local_capture_script",
    }),
  });

  const result = await response.json();

  if (result.success) {
    const r = result.results?.[0] ?? result;
    console.log(`   📊 Fixtures found:  ${r.fixturesFound ?? 0}`);
    console.log(`   🔗 Matched to DB:   ${r.matchesLinked ?? 0}`);
    console.log(`   ✅ Odds updated:    ${r.oddsUpdated ?? 0}`);
  } else {
    console.error(`   ❌ Error: ${result.error || JSON.stringify(result)}`);
  }

  return result;
}

// ─────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────

async function main() {
  const opts = parseArgs();

  console.log("═".repeat(60));
  console.log("🏈 FANZONE Screenshot-to-Multipliers (bwin)");
  console.log("═".repeat(60));
  console.log(`   Source:     bwin.com (official bookmaker)`);
  console.log(`   Viewport:   ${VIEWPORT.width}x${VIEWPORT.height} @2x`);
  console.log(`   Scroll:     ${opts.scroll}`);
  console.log(`   Dry run:    ${opts.dryRun}`);
  console.log(`   Function:   ${EDGE_FUNCTION_URL}`);

  // Build capture jobs
  const jobs = [];
  if (opts.url) {
    jobs.push({ url: opts.url, name: "Custom URL" });
  } else {
    for (const key of opts.leagues) {
      const league = BWIN_LEAGUES[key];
      if (league) jobs.push({ url: league.url, name: league.name });
      else console.warn(`   ⚠️  Unknown league key: ${key}`);
    }
  }

  console.log(`   Leagues:    ${jobs.length}`);
  console.log("");

  // Launch browser
  console.log("🚀 Launching headless browser (stealth mode)...");
  const browser = await puppeteerExtra.launch({
    headless: "new",
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      `--window-size=${VIEWPORT.width},${VIEWPORT.height}`,
    ],
    ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  });

  const results = [];

  try {
    for (const job of jobs) {
      try {
        const screenshots = await capturePage(browser, job.url, job.name, opts.scroll);

        for (const shot of screenshots) {
          // Save locally
          const safeName = job.name.replace(/[^a-zA-Z0-9]/g, "_").toLowerCase();
          const filename = `fanzone_bwin_${safeName}_${shot.section}.png`;
          const savePath = path.join(opts.savePath, filename);
          fs.writeFileSync(savePath, Buffer.from(shot.base64, "base64"));
          console.log(`   💾 Saved: ${savePath}`);

          // Send to Edge Function
          if (!opts.dryRun) {
            const result = await sendToEdgeFunction(shot.base64);
            results.push({ league: job.name, section: shot.section, success: true, result });
          } else {
            results.push({ league: job.name, section: shot.section, success: true, dryRun: true });
          }
        }
      } catch (err) {
        console.error(`   ❌ [${job.name}] Failed: ${err.message}`);
        results.push({ league: job.name, success: false, error: err.message });
      }
    }
  } finally {
    await browser.close();
  }

  // Summary
  console.log("\n" + "═".repeat(60));
  console.log("📊 CAPTURE SUMMARY");
  console.log("═".repeat(60));
  const ok = results.filter((r) => r.success).length;
  const fail = results.filter((r) => !r.success).length;
  console.log(`   Total screenshots: ${results.length}`);
  console.log(`   Successful:        ${ok}`);
  console.log(`   Failed:            ${fail}`);
  console.log("");
  for (const r of results) {
    const icon = r.success ? "✅" : "❌";
    console.log(`   ${icon} ${r.league} (${r.section || "error"})`);
  }
  console.log("═".repeat(60));
  console.log("🏁 Done.\n");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
