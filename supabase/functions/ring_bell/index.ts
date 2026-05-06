import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  checkRateLimit,
  createAdminClient,
  createLogger,
  errorResponse,
  getOrCreateRequestId,
  handleCors,
  jsonResponse,
  requireAuth,
} from "../_shared/mod.ts";

const ringBellSchema = z.object({
  venue_id: z.string().uuid(),
  table_id: z.string().uuid(),
  message: z.string().trim().max(200).optional(),
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

    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user } = authResult;

    const body = await req.json();
    const parsed = ringBellSchema.safeParse(body);
    if (!parsed.success) {
      logger.warn("Validation failed", { errors: parsed.error.issues });
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { venue_id, table_id, message } = parsed.data;
    const supabaseAdmin = createAdminClient();

    const rateLimitResult = await checkRateLimit(
      supabaseAdmin,
      user.id,
      {
        endpoint: "ring_bell",
        maxRequests: 5,
        window: "1 hour",
      },
      logger,
    );
    if (rateLimitResult instanceof Response) return rateLimitResult;

    const { data: venue, error: venueError } = await supabaseAdmin
      .from("venues")
      .select("id, name, is_active")
      .eq("id", venue_id)
      .eq("is_active", true)
      .maybeSingle();

    if (venueError || !venue) {
      logger.warn("Venue not found or inactive", { venueId: venue_id });
      return errorResponse("Venue not found or inactive", 404);
    }

    const { data: table, error: tableError } = await supabaseAdmin
      .from("tables")
      .select("id, table_number")
      .eq("id", table_id)
      .eq("venue_id", venue_id)
      .eq("is_active", true)
      .maybeSingle();

    if (tableError || !table) {
      logger.warn("Table not found or inactive", {
        tableId: table_id,
        venueId: venue_id,
      });
      return errorResponse("Table not found or inactive", 404);
    }

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

    if (bellError || !bell) {
      logger.error("Failed to ring bell", { error: bellError?.message });
      return errorResponse("Failed to ring bell", 500);
    }

    logger.info("Bell rung", {
      bellId: bell.id,
      venueId: venue_id,
      tableNumber: table.table_number,
    });
    logger.requestEnd(201, Date.now() - startTime);

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
