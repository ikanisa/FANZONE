import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  handleCors,
  jsonResponse,
  errorResponse,
  createAdminClient,
  requireAuth,
  requireVendorOrAdmin,
  createLogger,
  getOrCreateRequestId,
  createAuditLogger,
  AuditAction,
  EntityType,
} from "../_shared/mod.ts";

/**
 * Valid status transitions:
 *   placed    → received | cancelled
 *   received  → served | cancelled
 *   served    → (terminal)
 *   cancelled → (terminal)
 */
const VALID_TRANSITIONS: Record<string, string[]> = {
  placed: ["received", "cancelled"],
  received: ["served", "cancelled"],
};

const updateStatusSchema = z.object({
  order_id: z.string().uuid(),
  status: z.enum(["received", "served", "cancelled"]),
});

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "order_update_status" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/order_update_status");

    const supabaseAdmin = createAdminClient();

    // ---- Auth ----
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user, supabaseUser } = authResult;

    // ---- Validate input ----
    const body = await req.json();
    const parsed = updateStatusSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { order_id, status: newStatus } = parsed.data;

    // ---- Fetch order ----
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, venue_id, status")
      .eq("id", order_id)
      .single();

    if (orderError || !order) {
      return errorResponse("Order not found", 404);
    }

    // ---- RBAC: venue member or admin ----
    const rbacResult = await requireVendorOrAdmin(
      supabaseAdmin,
      supabaseUser,
      order.venue_id,
      user.id,
      logger
    );
    if (rbacResult instanceof Response) return rbacResult;

    // ---- Validate status transition ----
    const currentStatus = order.status;
    const allowedNext = VALID_TRANSITIONS[currentStatus] || [];

    if (!allowedNext.includes(newStatus)) {
      logger.warn("Invalid status transition", { currentStatus, newStatus, orderId: order_id });
      return errorResponse(
        `Invalid status transition: ${currentStatus} → ${newStatus}. Allowed: ${allowedNext.join(", ")}`,
        400
      );
    }

    // ---- Update status ----
    const updateData: Record<string, unknown> = { status: newStatus };
    if (newStatus === "served") {
      updateData.served_at = new Date().toISOString();
    }
    if (newStatus === "cancelled") {
      updateData.cancelled_at = new Date().toISOString();
    }

    const { data: updatedOrder, error: updateError } = await supabaseAdmin
      .from("orders")
      .update(updateData)
      .eq("id", order_id)
      .select()
      .single();

    if (updateError) {
      logger.error("Failed to update order status", { error: updateError.message });
      return errorResponse("Failed to update order status", 500);
    }

    // ---- Audit ----
    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
    await audit.log(AuditAction.ORDER_STATUS_UPDATE, EntityType.ORDER, order_id, {
      previousValue: { status: currentStatus },
      newValue: { status: newStatus },
      vendorId: order.venue_id,
    });

    const durationMs = Date.now() - startTime;
    logger.requestEnd(200, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      order: updatedOrder,
    });
  } catch (error) {
    logger.error("Update status error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
