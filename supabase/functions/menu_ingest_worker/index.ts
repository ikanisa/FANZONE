import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
    handleCors,
    jsonResponse,
    errorResponse,
    createAdminClient,
    createLogger,
    getOrCreateRequestId,
    callGemini,
    GEMINI_MODELS,
    parseJSON,
} from "../_shared/mod.ts";

// ============================================================================
// OCR Menu Ingest Worker
// Processes pending jobs: fetch image → Gemini OCR → write staging items
// Ported from DineIn, uses FANZONE _shared/ barrel
// ============================================================================

const MENU_OCR_PROMPT = `You are a menu extraction AI. Analyze this menu image and extract all menu items.

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
    job_id: z.string().uuid().optional(),
    max_jobs: z.number().min(1).max(10).default(5),
});

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

    try {
        logger.requestStart(req.method, "/menu_ingest_worker");
        const supabaseAdmin = createAdminClient();

        const body = await req.json().catch(() => ({}));
        const parsed = triggerSchema.safeParse(body);
        if (!parsed.success) {
            return errorResponse("Invalid request data", 400, parsed.error.issues);
        }

        const { job_id, max_jobs } = parsed.data;
        let processedCount = 0;
        let errorCount = 0;

        // Get jobs to process
        let jobsToProcess: any[] = [];

        if (job_id) {
            const { data: job } = await supabaseAdmin
                .from("menu_ingest_jobs")
                .select("*")
                .eq("id", job_id)
                .single();
            if (job && job.status === "pending") {
                jobsToProcess = [job];
            }
        } else {
            const { data: jobs } = await supabaseAdmin
                .from("menu_ingest_jobs")
                .select("*")
                .eq("status", "pending")
                .or("next_attempt_at.is.null,next_attempt_at.lte.now()")
                .order("created_at", { ascending: true })
                .limit(max_jobs);
            jobsToProcess = jobs || [];
        }

        logger.info("Jobs to process", { count: jobsToProcess.length });

        for (const job of jobsToProcess) {
            const jobLogger = createLogger({ requestId, action: "process_job", jobId: job.id });
            jobLogger.info("Processing job", { venueId: job.venue_id, filePath: job.file_path });

            try {
                // 1. Claim job (atomic: pending → running)
                const { data: claimed, error: claimError } = await supabaseAdmin.rpc("claim_ingest_job", {
                    p_job_id: job.id,
                });

                if (claimError || !claimed) {
                    jobLogger.warn("Failed to claim job (may be taken by another worker)");
                    continue;
                }

                // 2. Fetch image from storage
                const { data: fileData, error: fileError } = await supabaseAdmin.storage
                    .from("menu_uploads")
                    .download(job.file_path);

                if (fileError || !fileData) {
                    jobLogger.error("File not found", { error: fileError?.message });
                    await failJob(supabaseAdmin, job.id, ERROR_CODES.FILE_NOT_FOUND, "Menu image not found", false);
                    errorCount++;
                    continue;
                }

                // Convert to base64
                const arrayBuffer = await fileData.arrayBuffer();
                const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
                const mimeType = fileData.type || "image/jpeg";

                // 3. Call Gemini OCR
                jobLogger.info("Calling Gemini OCR");
                let geminiResult;
                try {
                    geminiResult = await callGemini(GEMINI_MODELS.vision, MENU_OCR_PROMPT, {
                        imageData: base64,
                        mimeType,
                        temperature: 0.3,
                        maxTokens: 4096,
                        responseMimeType: "application/json",
                    });
                } catch (ocrError) {
                    jobLogger.error("Gemini OCR failed", { error: String(ocrError) });
                    await failJob(supabaseAdmin, job.id, ERROR_CODES.OCR_FAILED, "AI menu analysis failed. Please try again.", true);
                    errorCount++;
                    continue;
                }

                if (!geminiResult.text) {
                    jobLogger.error("Gemini returned no text");
                    await failJob(supabaseAdmin, job.id, ERROR_CODES.OCR_FAILED, "No menu data extracted from image", true);
                    errorCount++;
                    continue;
                }

                // 4. Parse JSON response
                const menuItems = parseJSON(geminiResult.text, []);
                if (!Array.isArray(menuItems)) {
                    jobLogger.error("Invalid JSON from Gemini");
                    await failJob(supabaseAdmin, job.id, ERROR_CODES.INVALID_JSON, "Failed to parse menu data", true);
                    errorCount++;
                    continue;
                }

                // Validate and clean items
                const validatedItems = menuItems
                    .filter((item: any) => item.name && typeof item.price === "number")
                    .map((item: any) => ({
                        job_id: job.id,
                        venue_id: job.venue_id,
                        raw_category: item.category ? String(item.category).trim() : null,
                        name: String(item.name).trim(),
                        description: item.description ? String(item.description).trim() : null,
                        price: Number(item.price),
                        currency: job.venue_id ? "EUR" : null,
                        confidence: Number(item.confidence) || 0.5,
                        parse_warnings: [],
                        suggested_action: "keep",
                    }));

                jobLogger.info("Parsed menu items", { count: validatedItems.length, rawCount: menuItems.length });

                // 5. Clear old staging items (idempotency) and insert new ones
                await supabaseAdmin.from("menu_items_staging").delete().eq("job_id", job.id);

                if (validatedItems.length > 0) {
                    const { error: insertError } = await supabaseAdmin
                        .from("menu_items_staging")
                        .insert(validatedItems);

                    if (insertError) {
                        jobLogger.error("Failed to insert staging items", { error: insertError.message });
                        await failJob(supabaseAdmin, job.id, "DB_ERROR", "Failed to save parsed menu items", true);
                        errorCount++;
                        continue;
                    }
                }

                // 6. Mark job as needs_review
                await supabaseAdmin
                    .from("menu_ingest_jobs")
                    .update({
                        status: "needs_review",
                        finished_at: new Date().toISOString(),
                        updated_at: new Date().toISOString(),
                    })
                    .eq("id", job.id);

                jobLogger.info("Job completed", { itemCount: validatedItems.length });
                processedCount++;
            } catch (jobError) {
                jobLogger.error("Unexpected error processing job", { error: String(jobError) });
                await failJob(supabaseAdmin, job.id, "INTERNAL_ERROR", "An unexpected error occurred", true);
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
 * Mark job as failed (with optional retry scheduling)
 */
async function failJob(client: any, jobId: string, errorCode: string, errorMessage: string, shouldRetry: boolean) {
    await client.rpc("fail_ingest_job", {
        p_job_id: jobId,
        p_error_code: errorCode,
        p_error_message: errorMessage,
        p_should_retry: shouldRetry,
    });
}
