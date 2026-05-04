import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  AuditAction,
  createAdminClient,
  createAuditLogger,
  createLogger,
  EntityType,
  errorResponse,
  getOrCreateRequestId,
  handleCors,
  jsonResponse,
  requireAuth,
  requireVendorOrAdmin,
} from "../_shared/mod.ts";

const generateTablesSchema = z.object({
  venue_id: z.string().uuid(),
  count: z.number().int().min(1).max(100),
  label_prefix: z.string().max(30).optional().default("Table"),
});

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "tables_generate" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/tables_generate");

    const supabaseAdmin = createAdminClient();

    // ---- Auth ----
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user, supabaseUser } = authResult;

    // ---- Validate input ----
    const body = await req.json();
    const parsed = generateTablesSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { venue_id, count } = parsed.data;

    // ---- RBAC: venue member or admin ----
    const rbacResult = await requireVendorOrAdmin(
      supabaseAdmin,
      supabaseUser,
      venue_id,
      user.id,
      logger,
    );
    if (rbacResult instanceof Response) return rbacResult;

    // ---- Get current max table_number for venue ----
    const { data: existingTables } = await supabaseAdmin
      .from("tables")
      .select("table_number")
      .eq("venue_id", venue_id)
      .order("table_number", { ascending: false })
      .limit(1);

    const lastTableNumber = Number.parseInt(
      existingTables?.[0]?.table_number ?? "0",
      10,
    );
    const startNumber = Number.isFinite(lastTableNumber) && lastTableNumber > 0
      ? lastTableNumber + 1
      : 1;

    // ---- Generate tables ----
    const tablesToInsert = [];

    for (let i = 0; i < count; i++) {
      const tableNumber = String(startNumber + i);

      tablesToInsert.push({
        venue_id,
        table_number: tableNumber,
        deep_link_uri: `fanzone://venue/${venue_id}/table/${tableNumber}`,
        qr_code_url: null,
        is_active: true,
      });
    }

    const { data: tables, error: insertError } = await supabaseAdmin
      .from("tables")
      .insert(tablesToInsert)
      .select();

    if (insertError) {
      logger.error("Failed to generate tables", { error: insertError.message });
      return errorResponse(
        "Failed to generate tables",
        500,
        insertError.message,
      );
    }

    // ---- Audit ----
    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
    await audit.log(AuditAction.TABLES_GENERATE, EntityType.TABLE, venue_id, {
      count,
      startNumber,
      endNumber: startNumber + count - 1,
    });

    const durationMs = Date.now() - startTime;
    logger.requestEnd(201, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      tables,
      count: tables?.length || 0,
    }, 201);
  } catch (error) {
    logger.error("Tables generate error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
