import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
    handleCors,
    jsonResponse,
    errorResponse,
    createAdminClient,
    requireAuth,
    checkRateLimit,
    createLogger,
    getOrCreateRequestId,
    createAuditLogger,
    AuditAction,
    EntityType,
} from "../_shared/mod.ts";
import type { RateLimitConfig } from "../_shared/mod.ts";

// ============================================================================
// Menu Ingest Create
// Client-facing: upload image → create job → return job ID for polling
// Ported from DineIn, uses FANZONE _shared/ barrel
// ============================================================================

const createJobSchema = z.object({
    venue_id: z.string().uuid(),
    image_base64: z.string().min(100),
    mime_type: z.enum(["image/jpeg", "image/png", "image/webp", "application/pdf"]),
    filename: z.string().optional().default("menu.jpg"),
});

const RATE_LIMIT: RateLimitConfig = {
    maxRequests: 10,
    window: "1 hour",
    endpoint: "menu_ingest_create",
};

// Max file size: 10MB (base64 adds ~33% overhead, so ~7.5MB original)
const MAX_BASE64_SIZE = 14_000_000;

Deno.serve(async (req) => {
    const startTime = Date.now();
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "menu_ingest_create" });

    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    if (req.method !== "POST") {
        return errorResponse("Method not allowed", 405);
    }

    try {
        logger.requestStart(req.method, "/menu_ingest_create");
        const supabaseAdmin = createAdminClient();

        // Authenticate
        const authResult = await requireAuth(req, logger);
        if (authResult instanceof Response) return authResult;
        const { user } = authResult;

        // Validate
        const body = await req.json();
        const parsed = createJobSchema.safeParse(body);
        if (!parsed.success) {
            logger.warn("Validation failed", { errors: parsed.error.issues });
            return errorResponse("Invalid request data", 400, parsed.error.issues);
        }

        const { venue_id, image_base64, mime_type, filename } = parsed.data;

        if (image_base64.length > MAX_BASE64_SIZE) {
            return errorResponse("File too large (max 10MB)", 413);
        }

        logger.info("Creating ingest job", { venueId: venue_id, mimeType: mime_type });

        // Rate limiting
        const rateLimitResult = await checkRateLimit(supabaseAdmin, user.id, RATE_LIMIT, logger);
        if (rateLimitResult instanceof Response) return rateLimitResult;

        // Verify venue edit permission
        const { data: canEdit } = await supabaseAdmin.rpc("can_edit_vendor_profile", {
            p_venue_id: venue_id,
        });

        if (!canEdit) {
            logger.warn("User cannot edit venue", { userId: user.id, venueId: venue_id });
            return errorResponse("You don't have permission to upload menus for this venue", 403);
        }

        // Create job record
        const { data: job, error: jobError } = await supabaseAdmin
            .from("menu_ingest_jobs")
            .insert({
                venue_id,
                created_by: user.id,
                file_path: "pending",
                status: "pending",
            })
            .select()
            .single();

        if (jobError || !job) {
            logger.error("Failed to create job", { error: jobError?.message });
            return errorResponse("Failed to create job", 500);
        }

        // Upload to storage
        const extension = mime_type.split("/")[1] || "jpg";
        const storagePath = `${venue_id}/${job.id}/${filename.replace(/\.[^.]+$/, "")}.${extension}`;
        const binaryData = Uint8Array.from(atob(image_base64), (c) => c.charCodeAt(0));

        const { error: uploadError } = await supabaseAdmin.storage
            .from("menu_uploads")
            .upload(storagePath, binaryData, { contentType: mime_type, upsert: true });

        if (uploadError) {
            logger.error("Failed to upload file", { error: uploadError.message });
            await supabaseAdmin.from("menu_ingest_jobs").delete().eq("id", job.id);
            return errorResponse("Failed to upload file", 500);
        }

        // Update job with actual file path
        await supabaseAdmin.from("menu_ingest_jobs").update({ file_path: storagePath }).eq("id", job.id);

        // Audit log
        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
        await audit.log(AuditAction.MENU_INGEST_CREATE, EntityType.MENU_INGEST_JOB, job.id, {
            venueId: venue_id,
            storagePath,
        });

        logger.info("Job created successfully", { jobId: job.id, storagePath });

        // Fire-and-forget trigger to worker
        try {
            const workerUrl = Deno.env.get("SUPABASE_URL") + "/functions/v1/menu_ingest_worker";
            const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
            fetch(workerUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${serviceKey}`,
                },
                body: JSON.stringify({ job_id: job.id }),
            }).catch(() => {});
        } catch {
            // Ignore trigger errors — cron will pick up
        }

        const durationMs = Date.now() - startTime;
        logger.requestEnd(200, durationMs);

        return jsonResponse({
            success: true,
            requestId,
            job_id: job.id,
            status: "pending",
            message: "Menu upload received. Processing will begin shortly.",
        });
    } catch (error) {
        const durationMs = Date.now() - startTime;
        logger.error("Menu ingest create error", { error: String(error), durationMs });
        return errorResponse("Internal server error", 500, String(error));
    }
});
