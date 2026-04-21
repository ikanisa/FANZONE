/**
 * Screenshot capture engine.
 * Takes screenshots of betting websites using cloud browser services.
 * Supports Browserless.io (Puppeteer WebSocket) and ScreenshotOne (REST API).
 */

import type { CaptureProvider } from "./constants.ts";
import type { CaptureResult } from "./types.ts";

// ─────────────────────────────────────────────────────────────
// Provider 1: Browserless.io — full headless Chrome via REST /screenshot
// ─────────────────────────────────────────────────────────────

async function captureBrowserless(
  url: string,
  apiToken: string,
  viewport: { width: number; height: number },
): Promise<CaptureResult> {
  const endpoint = `https://chrome.browserless.io/screenshot?token=${encodeURIComponent(apiToken)}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url,
      gotoOptions: {
        waitUntil: "networkidle2",
        timeout: 30000,
      },
      options: {
        type: "png",
        fullPage: false,
        encoding: "base64",
      },
      viewport: {
        width: viewport.width,
        height: viewport.height,
        deviceScaleFactor: 2, // Retina-quality for better OCR
      },
      // Stealth settings to reduce bot detection
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      // Wait for dynamic content to render
      waitForTimeout: 5000,
      // Block unnecessary assets to speed up loading
      blockAds: true,
    }),
    signal: AbortSignal.timeout(60_000),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "unknown error");
    throw new Error(
      `Browserless capture failed (${response.status}): ${errorText.slice(0, 300)}`,
    );
  }

  const imageBase64 = await response.text();

  if (!imageBase64 || imageBase64.length < 100) {
    throw new Error("Browserless returned an empty or invalid screenshot.");
  }

  return {
    imageBase64,
    provider: "browserless",
    width: viewport.width,
    height: viewport.height,
  };
}

// ─────────────────────────────────────────────────────────────
// Provider 2: ScreenshotOne — simple REST API
// ─────────────────────────────────────────────────────────────

async function captureScreenshotOne(
  url: string,
  accessKey: string,
  viewport: { width: number; height: number },
): Promise<CaptureResult> {
  const params = new URLSearchParams({
    access_key: accessKey,
    url,
    viewport_width: String(viewport.width),
    viewport_height: String(viewport.height),
    device_scale_factor: "2",
    format: "png",
    response_type: "base64",
    block_ads: "true",
    block_cookie_banners: "true",
    delay: "5", // Wait 5 seconds for JS to load
    timeout: "30",
    full_page: "false",
    // JS rendering is always enabled
  });

  const endpoint = `https://api.screenshotone.com/take?${params.toString()}`;

  const response = await fetch(endpoint, {
    signal: AbortSignal.timeout(60_000),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "unknown error");
    throw new Error(
      `ScreenshotOne capture failed (${response.status}): ${errorText.slice(0, 300)}`,
    );
  }

  const imageBase64 = await response.text();

  if (!imageBase64 || imageBase64.length < 100) {
    throw new Error("ScreenshotOne returned an empty or invalid screenshot.");
  }

  return {
    imageBase64,
    provider: "screenshotone",
    width: viewport.width,
    height: viewport.height,
  };
}

// ─────────────────────────────────────────────────────────────
// Unified capture with automatic fallback
// ─────────────────────────────────────────────────────────────

export interface CaptureOptions {
  url: string;
  viewport?: { width: number; height: number };
  /** Force a specific provider. If omitted, tries all in order. */
  preferredProvider?: CaptureProvider;
}

/**
 * Capture a screenshot of the given URL using cloud browser services.
 * Tries providers in order: browserless → screenshotone.
 * Falls back to the next provider if one fails.
 */
export async function captureScreenshot(
  options: CaptureOptions,
): Promise<CaptureResult> {
  const viewport = options.viewport ?? { width: 1440, height: 900 };
  const errors: Array<{ provider: string; error: string }> = [];

  // Determine provider order
  const providers: CaptureProvider[] = options.preferredProvider
    ? [options.preferredProvider]
    : ["browserless", "screenshotone"];

  for (const provider of providers) {
    try {
      if (provider === "browserless") {
        const token = Deno.env.get("BROWSERLESS_API_KEY")?.trim();
        if (!token) {
          errors.push({
            provider,
            error: "BROWSERLESS_API_KEY not configured",
          });
          continue;
        }
        console.log(
          `[screenshot-odds-extract] Capturing via Browserless: ${options.url}`,
        );
        return await captureBrowserless(options.url, token, viewport);
      }

      if (provider === "screenshotone") {
        const key = Deno.env.get("SCREENSHOTONE_ACCESS_KEY")?.trim();
        if (!key) {
          errors.push({
            provider,
            error: "SCREENSHOTONE_ACCESS_KEY not configured",
          });
          continue;
        }
        console.log(
          `[screenshot-odds-extract] Capturing via ScreenshotOne: ${options.url}`,
        );
        return await captureScreenshotOne(options.url, key, viewport);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(
        `[screenshot-odds-extract] ${provider} failed for ${options.url}: ${msg}`,
      );
      errors.push({ provider, error: msg });
    }
  }

  throw new Error(
    `All capture providers failed for ${options.url}: ${JSON.stringify(errors)}`,
  );
}
