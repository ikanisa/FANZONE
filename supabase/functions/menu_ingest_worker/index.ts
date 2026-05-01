import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  callGemini,
  createAdminClient,
  createLogger,
  errorResponse,
  GEMINI_MODELS,
  getOrCreateRequestId,
  handleCors,
  isAuthorizedEdgeRequest,
  jsonResponse,
  parseJSON,
} from "../_shared/mod.ts";

// ============================================================================
// OCR Menu Ingest Worker
// Processes pending imports: fetch image → Gemini OCR → write review payload
// ============================================================================

const MENU_OCR_PROMPT =
  `You are a menu extraction AI. Analyze this menu image and extract all menu items.

For each item found, extract:
- name: The dish/drink name (required)
- description: Brief description if visible (optional)
- price: Numeric price value (required, extract the number only)
- category: Category like "Starters", "Mains", "Desserts", "Drinks", etc. (optional, infer from context)
- confidence: Your confidence in this extraction, 0.0 to 1.0 (required)

Return ONLY a valid JSON array of objects. Example:
[
  {"name": "Caesar Salad", "description": "Fresh romaine with parmesan", "price": 12.50, "category": "Starters", "confidence": 0.95},
  {"name": "Grilled Salmon", "description": "Atlantic salmon with herbs", "price": 24.00, "category": "Mains", "confidence": 0.88}
]

If no menu items can be extracted, return an empty array: []

Important:
- Extract ALL visible menu items
- Convert prices to numbers (e.g., "€12.50" becomes 12.50)
- If currency symbol is present, note that this is EUR for Malta or RWF for Rwanda
- Be thorough but accurate
- Include confidence scores for each item`;

const triggerSchema = z.object({
  import_id: z.string().uuid().optional(),
  job_id: z.string().uuid().optional(),
  max_jobs: z.number().min(1).max(10).default(5),
});

const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";

const ERROR_CODES = {
  INVALID_FILE: "INVALID_FILE",
  FILE_NOT_FOUND: "FILE_NOT_FOUND",
  OCR_FAILED: "OCR_FAILED",
  INVALID_JSON: "INVALID_JSON",
  ZERO_ITEMS: "ZERO_ITEMS",
} as const;

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "menu_ingest_worker" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: CRON_SECRET }],
    })
  ) {
    logger.warn("Unauthorized worker trigger");
    return errorResponse("Unauthorized", 401);
  }

  try {
    logger.requestStart(req.method, "/menu_ingest_worker");
    const supabaseAdmin = createAdminClient();

    const body = await req.json().catch(() => ({}));
    const parsed = triggerSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request data", 400, parsed.error.issues);
    }

    const { max_jobs } = parsed.data;
    const importId = parsed.data.import_id ?? parsed.data.job_id;
    let processedCount = 0;
    let errorCount = 0;

    // Get imports to process
    let importsToProcess: any[] = [];

    if (importId) {
      const { data: menuImport } = await supabaseAdmin
        .from("pending_menu_imports")
        .select("*")
        .eq("id", importId)
        .single();
      if (menuImport && menuImport.status === "pending") {
        importsToProcess = [menuImport];
      }
    } else {
      const { data: menuImports } = await supabaseAdmin
        .from("pending_menu_imports")
        .select("*")
        .eq("status", "pending")
        .order("created_at", { ascending: true })
        .limit(max_jobs);
      importsToProcess = menuImports || [];
    }

    logger.info("Menu imports to process", { count: importsToProcess.length });

    for (const menuImport of importsToProcess) {
      const jobLogger = createLogger({
        requestId,
        action: "process_menu_import",
        importId: menuImport.id,
      });
      jobLogger.info("Processing menu import", {
        venueId: menuImport.venue_id,
        storageBucket: menuImport.storage_bucket,
        storagePath: menuImport.storage_path,
      });

      try {
        // 1. Claim import (best-effort atomic: pending → processing)
        const { data: claimed, error: claimError } = await supabaseAdmin
          .from("pending_menu_imports")
          .update({
            status: "processing",
            updated_at: new Date().toISOString(),
          })
          .eq("id", menuImport.id)
          .eq("status", "pending")
          .select()
          .maybeSingle();

        if (claimError || !claimed) {
          jobLogger.warn(
            "Failed to claim import (may be taken by another worker)",
          );
          continue;
        }

        // 2. Fetch image from storage
        const { data: fileData, error: fileError } = await supabaseAdmin.storage
          .from(claimed.storage_bucket)
          .download(claimed.storage_path);

        if (fileError || !fileData) {
          jobLogger.error("File not found", { error: fileError?.message });
          await failJob(
            supabaseAdmin,
            claimed.id,
            ERROR_CODES.FILE_NOT_FOUND,
            "Menu image not found",
            false,
          );
          errorCount++;
          continue;
        }

        // Convert to base64
        const arrayBuffer = await fileData.arrayBuffer();
        const base64 = arrayBufferToBase64(arrayBuffer);
        const mimeType = fileData.type || "image/jpeg";

        // 3. Call Gemini OCR
        jobLogger.info("Calling Gemini OCR");
        let geminiResult;
        try {
          geminiResult = await callGemini(
            GEMINI_MODELS.vision,
            MENU_OCR_PROMPT,
            {
              imageData: base64,
              mimeType,
              temperature: 0.3,
              maxTokens: 4096,
              responseMimeType: "application/json",
            },
          );
        } catch (ocrError) {
          jobLogger.error("Gemini OCR failed", { error: String(ocrError) });
          await failJob(
            supabaseAdmin,
            claimed.id,
            ERROR_CODES.OCR_FAILED,
            "AI menu analysis failed. Please try again.",
            true,
          );
          errorCount++;
          continue;
        }

        if (!geminiResult.text) {
          jobLogger.error("Gemini returned no text");
          await failJob(
            supabaseAdmin,
            claimed.id,
            ERROR_CODES.OCR_FAILED,
            "No menu data extracted from image",
            true,
          );
          errorCount++;
          continue;
        }

        // 4. Parse JSON response
        const menuItems = parseJSON(geminiResult.text, []);
        if (!Array.isArray(menuItems)) {
          jobLogger.error("Invalid JSON from Gemini");
          await failJob(
            supabaseAdmin,
            claimed.id,
            ERROR_CODES.INVALID_JSON,
            "Failed to parse menu data",
            true,
          );
          errorCount++;
          continue;
        }

        const { data: venue } = await supabaseAdmin
          .from("venues")
          .select("currency_code")
          .eq("id", claimed.venue_id)
          .maybeSingle();
        const currencyCode = venue?.currency_code === "RWF" ? "RWF" : "EUR";

        // Validate and clean items for review. Nothing is published until a
        // venue user confirms/imports the review payload.
        const validatedItems = menuItems
          .filter((item: any) => item.name && typeof item.price === "number")
          .map((item: any) => ({
            import_id: claimed.id,
            venue_id: claimed.venue_id,
            raw_category: item.category ? String(item.category).trim() : null,
            category: item.category ? String(item.category).trim() : null,
            name: String(item.name).trim(),
            description: item.description
              ? String(item.description).trim()
              : null,
            price: Number(item.price),
            currency_code: currencyCode,
            confidence: Number(item.confidence) || 0.5,
            parse_warnings: [],
            suggested_action: "keep",
          }));

        jobLogger.info("Parsed menu items", {
          count: validatedItems.length,
          rawCount: menuItems.length,
        });

        if (validatedItems.length === 0) {
          await failJob(
            supabaseAdmin,
            claimed.id,
            ERROR_CODES.ZERO_ITEMS,
            "No menu items were extracted from the upload",
            false,
          );
          errorCount++;
          continue;
        }

        // 5. Store extracted/review payload on the canonical import table.
        const { error: updateError } = await supabaseAdmin
          .from("pending_menu_imports")
          .update({
            status: "review",
            detected_currency: currencyCode,
            extracted_payload: {
              items: validatedItems,
              raw_count: menuItems.length,
              model: GEMINI_MODELS.vision,
            },
            review_payload: { items: validatedItems },
            error_message: null,
            processed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", claimed.id);

        if (updateError) {
          jobLogger.error("Failed to save menu import review payload", {
            error: updateError.message,
          });
          await failJob(
            supabaseAdmin,
            claimed.id,
            "DB_ERROR",
            "Failed to save parsed menu items",
            true,
          );
          errorCount++;
          continue;
        }

        jobLogger.info("Menu import completed", {
          itemCount: validatedItems.length,
        });
        processedCount++;
      } catch (jobError) {
        jobLogger.error("Unexpected error processing menu import", {
          error: String(jobError),
        });
        await failJob(
          supabaseAdmin,
          menuImport.id,
          "INTERNAL_ERROR",
          "An unexpected error occurred",
          true,
        );
        errorCount++;
      }
    }

    const durationMs = Date.now() - startTime;
    logger.requestEnd(200, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      processed: processedCount,
      errors: errorCount,
      duration_ms: durationMs,
    });
  } catch (error) {
    const durationMs = Date.now() - startTime;
    logger.error("Worker error", { error: String(error), durationMs });
    return errorResponse("Internal server error", 500, String(error));
  }
});

/**
 * Mark import as failed.
 */
async function failJob(
  client: any,
  importId: string,
  errorCode: string,
  errorMessage: string,
  shouldRetry: boolean,
) {
  await client
    .from("pending_menu_imports")
    .update({
      status: "failed",
      error_message: errorMessage,
      extracted_payload: {
        error_code: errorCode,
        retryable: shouldRetry,
      },
      processed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", importId);
}

function arrayBufferToBase64(arrayBuffer: ArrayBuffer): string {
  const bytes = new Uint8Array(arrayBuffer);
  const chunkSize = 0x8000;
  let binary = "";

  for (let index = 0; index < bytes.length; index += chunkSize) {
    const chunk = bytes.subarray(index, index + chunkSize);
    binary += String.fromCharCode(...chunk);
  }

  return btoa(binary);
}
