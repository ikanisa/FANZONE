import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  handleCors,
  jsonResponse,
  errorResponse,
  createAdminClient,
  requireAuth,
  createLogger,
  getOrCreateRequestId,
  checkRateLimit,
} from "../_shared/mod.ts";

const ringBellSchema = z.object({
  venue_id: z.string().uuid(),
  table_id: z.string().uuid(),
  message: z.string().max(200).optional(),
});

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "ring_bell" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/ring_bell");

    const supabaseAdmin = createAdminClient();

    // ---- Auth ----
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user } = authResult;

    // ---- Validate input ----
    const body = await req.json();
    const parsed = ringBellSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { venue_id, table_id, message } = parsed.data;

    // ---- Rate limit: 5 bells per hour per user ----
    const rateLimitResult = await checkRateLimit(supabaseAdmin, user.id, {
      maxRequests: 5,
      window: "1 hour",
      endpoint: "ring_bell",
    }, logger);
    if (rateLimitResult instanceof Response) return rateLimitResult;

    // ---- Validate venue ----
    const { data: venue } = await supabaseAdmin
      .from("venues")
      .select("id, name, is_active")
      .eq("id", venue_id)
      .eq("is_active", true)
      .single();

    if (!venue) {
      return errorResponse("Venue not found or inactive", 404);
    }

    // ---- Validate table belongs to venue ----
    const { data: table } = await supabaseAdmin
      .from("tables")
      .select("id, table_number")
      .eq("id", table_id)
      .eq("venue_id", venue_id)
      .eq("is_active", true)
      .single();

    if (!table) {
      return errorResponse("Table not found", 404);
    }

    // ---- Insert bell ring record ----
    const { data: bell, error: bellError } = await supabaseAdmin
      .from("bell_requests")
      .insert({
        venue_id,
        table_id,
        user_id: user.id,
        message: message || null,
      })
      .select()
      .single();

    if (bellError) {
      logger.error("Failed to ring bell", { error: bellError.message });
      return errorResponse("Failed to ring bell", 500);
    }

    logger.info("Bell rung", {
      bellId: bell.id,
      venueId: venue_id,
      tableNumber: table.table_number,
    });

    const durationMs = Date.now() - startTime;
    logger.requestEnd(201, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      bell,
      venue: { name: venue.name },
      table: { number: table.table_number },
    }, 201);
  } catch (error) {
    logger.error("Ring bell error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
