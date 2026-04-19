import { createClient } from "jsr:@supabase/supabase-js@2";
import { GoogleGenerativeAI, type Tool } from "npm:@google/generative-ai";
import { isAuthorizedEdgeRequest } from "../_shared/http.ts";

/**
 * Gemini Currency Rate Refresh Edge Function
 *
 * Uses Gemini with Google Search Grounding to fetch live EUR exchange rates
 * for all currencies supported by the FANZONE FET system.
 *
 * Base peg: 100 FET = 1 EUR (hardcoded, never changes).
 * This function only refreshes EUR→local currency rates.
 *
 * Invocation: POST (cron or admin trigger)
 * Auth: service_role key or CURRENCY_SYNC_SECRET header
 */

const FUNCTION_NAME = "gemini-currency-rates";
const DEFAULT_GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ??
  "gemini-3.1-pro-preview";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN")?.trim() || "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-currency-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

function requireSupabaseUrl(): string {
  return (
    Deno.env.get("FANZONE_SUPABASE_URL")?.trim() ||
    Deno.env.get("SUPABASE_URL")?.trim() ||
    requireEnv("FANZONE_SUPABASE_URL")
  );
}

function requireSupabaseServiceRoleKey(): string {
  return (
    Deno.env.get("FANZONE_SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    requireEnv("FANZONE_SUPABASE_SERVICE_ROLE_KEY")
  );
}

function assertAuthorized(req: Request) {
  const serviceRoleKey = requireSupabaseServiceRoleKey();
  const syncSecret = Deno.env.get("CURRENCY_SYNC_SECRET")?.trim();
  if (
    isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: [{
        header: "x-currency-sync-secret",
        value: syncSecret,
      }],
    })
  ) {
    return;
  }

  throw new Error("Unauthorized");
}

function getSupabaseAdmin() {
  return createClient(
    requireSupabaseUrl(),
    requireSupabaseServiceRoleKey(),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

function stripCodeFences(text: string): string {
  return text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function extractBalancedJson(text: string): string | null {
  const source = stripCodeFences(text);

  for (let start = 0; start < source.length; start++) {
    const opener = source[start];
    if (opener !== "{" && opener !== "[") continue;

    const stack: string[] = [opener === "{" ? "}" : "]"];
    let inString = false;
    let escaped = false;

    for (let index = start + 1; index < source.length; index++) {
      const char = source[index];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char === "\\") {
        escaped = true;
        continue;
      }

      if (char === '"') {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (char === "{") {
        stack.push("}");
      } else if (char === "[") {
        stack.push("]");
      } else if (char === "}" || char === "]") {
        if (stack[stack.length - 1] !== char) break;
        stack.pop();
        if (stack.length === 0) {
          return source.slice(start, index + 1);
        }
      }
    }
  }

  return null;
}

function parseGeminiJson(text: string): unknown {
  const direct = stripCodeFences(text);

  try {
    return JSON.parse(direct);
  } catch {
    const candidate = extractBalancedJson(text);
    if (candidate == null) {
      console.error(
        `[${FUNCTION_NAME}] Failed to extract JSON from Gemini response:`,
        text.slice(0, 1000),
      );
      throw new Error("Gemini returned malformed JSON");
    }

    try {
      return JSON.parse(candidate);
    } catch (error) {
      console.error(
        `[${FUNCTION_NAME}] Failed to parse extracted Gemini JSON:`,
        candidate.slice(0, 1000),
      );
      throw error;
    }
  }
}

function coerceCurrencyCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(normalized) ? normalized : null;
}

function coerceRateNumber(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) && value > 0 ? value : null;
  }

  if (typeof value !== "string") return null;

  const cleaned = value
    .trim()
    .replace(/,/g, "")
    .replace(/[^\d.\-]/g, "");

  if (!cleaned) return null;
  const parsed = Number.parseFloat(cleaned);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function normalizeRateEntry(
  entry: unknown,
): { currency: string; rate: number } | null {
  if (Array.isArray(entry) && entry.length >= 2) {
    const currency = coerceCurrencyCode(entry[0]);
    const rate = coerceRateNumber(entry[1]);
    if (currency && rate != null) return { currency, rate };
  }

  if (!entry || typeof entry !== "object") return null;

  const record = entry as Record<string, unknown>;

  if (Object.keys(record).length === 1) {
    const [key, value] = Object.entries(record)[0];
    const currency = coerceCurrencyCode(key);
    const rate = coerceRateNumber(value);
    if (currency && rate != null) return { currency, rate };
  }

  const currency = [
    record.currency,
    record.code,
    record.target_currency,
    record.quote_currency,
    record.to,
    record.symbol,
  ]
    .map(coerceCurrencyCode)
    .find((value) => value != null);

  const rate = [
    record.rate,
    record.value,
    record.exchange_rate,
    record.eur_rate,
    record.per_eur,
    record.units_per_eur,
    record.target_rate,
  ]
    .map(coerceRateNumber)
    .find((value) => value != null);

  if (currency && rate != null) {
    return { currency, rate };
  }

  return null;
}

function collectRates(
  payload: unknown,
): Array<{ currency: string; rate: number }> {
  if (Array.isArray(payload)) {
    return payload
      .map(normalizeRateEntry)
      .filter((entry): entry is { currency: string; rate: number } =>
        entry != null
      );
  }

  if (!payload || typeof payload !== "object") return [];

  const record = payload as Record<string, unknown>;

  for (
    const key of [
      "rates",
      "exchange_rates",
      "currencies",
      "results",
      "items",
    ]
  ) {
    const value = record[key];
    if (value != null) {
      const nested = collectRates(value);
      if (nested.length > 0) return nested;
    }
  }

  for (const key of ["data", "payload", "result", "response"]) {
    const value = record[key];
    if (value && typeof value === "object") {
      const nested = collectRates(value);
      if (nested.length > 0) return nested;
    }
  }

  const mapped = Object.entries(record)
    .map(([key, value]) => {
      const currency = coerceCurrencyCode(key);
      const rate = coerceRateNumber(value);
      if (currency == null || rate == null) return null;
      return { currency, rate };
    })
    .filter((entry): entry is { currency: string; rate: number } =>
      entry != null
    );

  if (mapped.length > 0) return mapped;

  for (const value of Object.values(record)) {
    if (Array.isArray(value) || (value && typeof value === "object")) {
      const nested = collectRates(value);
      if (nested.length > 0) return nested;
    }
  }

  return [];
}

async function fetchLiveRatesFromGemini(): Promise<
  Array<{ currency: string; rate: number }>
> {
  const gemini = new GoogleGenerativeAI(requireEnv("GEMINI_API_KEY"));
  const tools = [{ googleSearch: {} }] as unknown as Tool[];

  const model = gemini.getGenerativeModel({
    model: DEFAULT_GEMINI_MODEL,
    tools,
  });

  const today = new Date().toISOString().slice(0, 10);
  const supabase = getSupabaseAdmin();
  const targetCurrencies = await getTargetCurrencies(supabase);

  if (targetCurrencies.length == 0) {
    throw new Error("No target currencies configured");
  }

  const currencyList = targetCurrencies.join(", ");

  const prompt = [
    "You are a currency data extraction worker.",
    `Today's date is ${today}.`,
    `Use Google Search to find the current live exchange rates from EUR (Euro) to each of these currencies: ${currencyList}.`,
    "For each currency, return how many units of that currency equal 1 EUR.",
    "Rules:",
    "- Return ONLY valid JSON.",
    '- Prefer this shape: {"rates":[{"currency":"GBP","rate":0.86}]}',
    "- Do not include markdown, prose, or code fences.",
    "- Use the most recent rates available from reputable financial sources.",
    "- Rates must be positive numbers.",
    "- Do not invent, estimate, or interpolate rates.",
    "- If a rate cannot be found with confidence, omit that currency instead of guessing.",
    "- Round large rates (>100) to integers. Round small rates (<10) to 2 decimal places.",
  ].join("\n");

  const result = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.1,
    },
  });

  const text = result.response.text().trim();
  const parsed = parseGeminiJson(text);
  const targetSet = new Set(targetCurrencies);
  const normalized = collectRates(parsed)
    .filter((entry) =>
      targetSet.has(entry.currency) && entry.currency !== "EUR"
    );

  if (normalized.length === 0) {
    console.error(
      `[${FUNCTION_NAME}] Gemini response contained no usable rates:`,
      text.slice(0, 1000),
    );
    throw new Error("Gemini returned no usable exchange rates");
  }

  const deduped = new Map<string, number>();
  for (const entry of normalized) {
    if (!deduped.has(entry.currency)) {
      deduped.set(entry.currency, entry.rate);
    }
  }

  const missingCurrencies = targetCurrencies.filter((currency) =>
    !deduped.has(currency)
  );
  if (missingCurrencies.length > 0) {
    console.error(
      `[${FUNCTION_NAME}] Gemini response missing live rates for:`,
      missingCurrencies.join(", "),
    );
    throw new Error(
      `Gemini returned incomplete exchange rates: missing ${missingCurrencies.join(", ")}`,
    );
  }

  return [...deduped.entries()].map(([currency, rate]) => ({ currency, rate }));
}

async function getTargetCurrencies(
  supabase: ReturnType<typeof getSupabaseAdmin>,
): Promise<string[]> {
  const currencySet = new Set<string>();

  const { data: countryRows, error: countryError } = await supabase
    .from("country_currency_map")
    .select("currency_code");

  if (countryError) {
    console.warn(
      `[${FUNCTION_NAME}] Failed to read country_currency_map:`,
      countryError.message,
    );
  } else {
    for (const row of countryRows ?? []) {
      const code = row.currency_code?.toString().trim().toUpperCase();
      if (code && code !== "EUR") currencySet.add(code);
    }
  }

  if (currencySet.size === 0) {
    const { data: cachedRows, error: cachedError } = await supabase
      .from("currency_rates")
      .select("target_currency")
      .eq("base_currency", "EUR");

    if (cachedError) {
      console.warn(
        `[${FUNCTION_NAME}] Failed to read currency_rates fallback:`,
        cachedError.message,
      );
    } else {
      for (const row of cachedRows ?? []) {
        const code = row.target_currency?.toString().trim().toUpperCase();
        if (code && code !== "EUR") currencySet.add(code);
      }
    }
  }

  return [...currencySet].sort();
}

async function upsertRates(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  rates: Array<{ currency: string; rate: number }>,
) {
  const now = new Date().toISOString();

  // Always include EUR = 1.0
  const rows = [
    {
      base_currency: "EUR",
      target_currency: "EUR",
      rate: 1.0,
      source: "fixed",
      updated_at: now,
      raw_payload: {},
    },
    ...rates.map((r) => ({
      base_currency: "EUR",
      target_currency: r.currency,
      rate: r.rate,
      source: "gemini",
      updated_at: now,
      raw_payload: {},
    })),
  ];

  const { error } = await supabase
    .from("currency_rates")
    .upsert(rows, { onConflict: "base_currency,target_currency" });

  if (error) {
    console.error(`[${FUNCTION_NAME}] Upsert failed:`, error);
    throw new Error(`Failed to save rates: ${error.message}`);
  }

  return rows.length;
}

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { success: false, error: "Use POST" });
  }

  try {
    assertAuthorized(req);

    console.log(`[${FUNCTION_NAME}] Fetching live rates from Gemini...`);
    const rates = await fetchLiveRatesFromGemini();
    console.log(`[${FUNCTION_NAME}] Got ${rates.length} rates from Gemini`);

    const supabase = getSupabaseAdmin();
    const saved = await upsertRates(supabase, rates);

    console.log(`[${FUNCTION_NAME}] Saved ${saved} rates to currency_rates`);

    return jsonResponse(200, {
      success: true,
      requestId,
      ratesUpdated: saved,
      currencies: rates.map((r) => r.currency),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error(`[${FUNCTION_NAME}] Error:`, message);

    return jsonResponse(500, {
      success: false,
      requestId,
      error: message,
    });
  }
});
