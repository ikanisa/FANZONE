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

const markPaidSchema = z.object({
  order_id: z.string().uuid(),
  payment_method: z.enum(["cash", "momo", "revolut", "card", "other"])
    .optional().default(
      "cash",
    ),
});

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "order_mark_paid" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/order_mark_paid");

    const supabaseAdmin = createAdminClient();

    // ---- Auth ----
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user, supabaseUser } = authResult;

    // ---- Validate input ----
    const body = await req.json();
    const parsed = markPaidSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { order_id, payment_method } = parsed.data;

    // ---- Fetch order ----
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, venue_id, payment_status, status")
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
      logger,
    );
    if (rbacResult instanceof Response) return rbacResult;

    // ---- Idempotency: already paid ----
    if (order.payment_status === "paid") {
      logger.info("Order already marked paid (idempotent)", {
        orderId: order_id,
      });
      return jsonResponse({
        success: true,
        requestId,
        message: "Already paid",
        order,
      });
    }

    // ---- Can only mark paid if order is in valid state ----
    if (order.status === "cancelled") {
      return errorResponse("Cannot mark a cancelled order as paid", 400);
    }

    // ---- Update payment status ----
    // External payments are off-platform. This endpoint records a staff/admin
    // manual confirmation after the customer shows cash, USSD, or Revolut proof.
    const { data: updatedOrder, error: updateError } = await supabaseAdmin
      .from("orders")
      .update({
        payment_status: "paid",
        payment_method,
      })
      .eq("id", order_id)
      .select()
      .single();

    if (updateError) {
      logger.error("Failed to update payment status", {
        error: updateError.message,
      });
      return errorResponse("Failed to update payment status", 500);
    }

    // FET credit is handled by the database trigger when payment_status
    // transitions to paid.

    // ---- Audit ----
    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
    await audit.log(AuditAction.ORDER_MARK_PAID, EntityType.ORDER, order_id, {
      previousValue: { payment_status: order.payment_status },
      newValue: { payment_status: "paid", payment_method },
      vendorId: order.venue_id,
    });

    await supabaseAdmin.from("payment_events").insert({
      order_id,
      provider: payment_method,
      status: "paid",
      request_payload: { marked_by: user.id, request_id: requestId },
      response_payload: {
        source: "order_mark_paid",
        confirmation_mode: "staff_manual",
        provider_api_used: false,
      },
    });

    const durationMs = Date.now() - startTime;
    logger.requestEnd(200, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      order: updatedOrder,
    });
  } catch (error) {
    logger.error("Mark paid error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
