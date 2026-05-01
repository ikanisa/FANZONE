import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  AuditAction,
  checkRateLimit,
  createAdminClient,
  createAuditLogger,
  createLogger,
  EntityType,
  errorResponse,
  getOrCreateRequestId,
  handleCors,
  jsonResponse,
  requireAuth,
} from "../_shared/mod.ts";
import type { RateLimitConfig } from "../_shared/mod.ts";

// ============================================================================
// Menu Ingest Create
// Client-facing: upload image → create pending import → return import ID for polling
// ============================================================================

const createJobSchema = z.object({
  venue_id: z.string().uuid(),
  image_base64: z.string().min(100),
  mime_type: z.enum([
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
  ]),
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

    logger.info("Creating ingest job", {
      venueId: venue_id,
      mimeType: mime_type,
    });

    // Rate limiting
    const rateLimitResult = await checkRateLimit(
      supabaseAdmin,
      user.id,
      RATE_LIMIT,
      logger,
    );
    if (rateLimitResult instanceof Response) return rateLimitResult;

    // Verify venue edit permission against the active venue membership table.
    const { data: member, error: memberError } = await supabaseAdmin
      .from("venue_users")
      .select("id")
      .eq("venue_id", venue_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (memberError || !member) {
      logger.warn("User cannot edit venue", {
        userId: user.id,
        venueId: venue_id,
      });
      return errorResponse(
        "You don't have permission to upload menus for this venue",
        403,
      );
    }

    const importId = crypto.randomUUID();
    const extension = mime_type === "application/pdf"
      ? "pdf"
      : (mime_type.split("/")[1] || "jpg");
    const safeFilename = filename
      .replace(/\.[^.]+$/, "")
      .replace(/[^a-zA-Z0-9._-]/g, "_")
      .slice(0, 80) || "menu";
    const storageBucket = "menu-ocr-queue";
    const storagePath = `${venue_id}/${importId}/${safeFilename}.${extension}`;
    const source = mime_type === "application/pdf" ? "ocr_pdf" : "ocr_image";

    // Create pending import record using the venue menu schema.
    const { data: menuImport, error: importError } = await supabaseAdmin
      .from("pending_menu_imports")
      .insert({
        id: importId,
        venue_id,
        created_by: user.id,
        source,
        status: "pending",
        storage_bucket: storageBucket,
        storage_path: storagePath,
        original_filename: filename,
      })
      .select()
      .single();

    if (importError || !menuImport) {
      logger.error("Failed to create menu import", {
        error: importError?.message,
      });
      return errorResponse("Failed to create menu import", 500);
    }

    // Upload to storage
    const binaryData = Uint8Array.from(
      atob(image_base64),
      (c) => c.charCodeAt(0),
    );

    const { error: uploadError } = await supabaseAdmin.storage
      .from(storageBucket)
      .upload(storagePath, binaryData, {
        contentType: mime_type,
        upsert: true,
      });

    if (uploadError) {
      logger.error("Failed to upload file", { error: uploadError.message });
      await supabaseAdmin.from("pending_menu_imports").delete().eq(
        "id",
        importId,
      );
      return errorResponse("Failed to upload file", 500);
    }

    // Audit log
    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
    await audit.log(
      AuditAction.MENU_INGEST_CREATE,
      EntityType.MENU_INGEST_JOB,
      importId,
      {
        venueId: venue_id,
        storageBucket,
        storagePath,
      },
    );

    logger.info("Menu import created successfully", { importId, storagePath });

    // Fire-and-forget trigger to worker
    try {
      const workerUrl = Deno.env.get("SUPABASE_URL") +
        "/functions/v1/menu_ingest_worker";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      fetch(workerUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({ import_id: importId }),
      }).catch(() => {});
    } catch {
      // Ignore trigger errors — cron will pick up
    }

    const durationMs = Date.now() - startTime;
    logger.requestEnd(200, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      import_id: importId,
      job_id: importId,
      status: "pending",
      message: "Menu upload received. Processing will begin shortly.",
    });
  } catch (error) {
    const durationMs = Date.now() - startTime;
    logger.error("Menu ingest create error", {
      error: String(error),
      durationMs,
    });
    return errorResponse("Internal server error", 500, String(error));
  }
});
