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

const markPaidSchema = z.object({
  order_id: z.string().uuid(),
  payment_method: z.enum(["cash", "momo_ussd", "revolut_link"]).optional().default("cash"),
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
      .select("id, venue_id, payment_status, status, total_amount, currency, client_auth_user_id")
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

    // ---- Idempotency: already paid ----
    if (order.payment_status === "paid") {
      logger.info("Order already marked paid (idempotent)", { orderId: order_id });
      return jsonResponse({ success: true, requestId, message: "Already paid", order });
    }

    // ---- Can only mark paid if order is in valid state ----
    if (order.status === "cancelled") {
      return errorResponse("Cannot mark a cancelled order as paid", 400);
    }

    // ---- Update payment status ----
    const { data: updatedOrder, error: updateError } = await supabaseAdmin
      .from("orders")
      .update({
        payment_status: "paid",
        payment_method,
        paid_at: new Date().toISOString(),
      })
      .eq("id", order_id)
      .select()
      .single();

    if (updateError) {
      logger.error("Failed to update payment status", { error: updateError.message });
      return errorResponse("Failed to update payment status", 500);
    }

    // ========================================================================
    // FET CREDIT: 1 EUR = 100 FET, 1 RWF ≈ 0.00074 EUR (100 FET per EUR)
    // This trigger is also backed by DB trigger, but we handle it here for
    // immediacy and to capture metadata
    // ========================================================================
    if (order.client_auth_user_id) {
      try {
        let fetAmount = 0;
        if (order.currency === "EUR") {
          fetAmount = Math.floor(Number(order.total_amount) * 100);
        } else if (order.currency === "RWF") {
          fetAmount = Math.floor(Number(order.total_amount) * 0.074);
        }

        if (fetAmount > 0) {
          const { error: fetError } = await supabaseAdmin.rpc("credit_fet_for_order", {
            p_user_id: order.client_auth_user_id,
            p_order_id: order_id,
            p_amount: fetAmount,
          });

          if (fetError) {
            logger.error("FET credit failed (non-blocking)", { error: fetError.message, fetAmount });
          } else {
            logger.info("FET credited", { userId: order.client_auth_user_id, fetAmount });
          }
        }
      } catch (fetErr) {
        logger.error("FET credit exception (non-blocking)", { error: String(fetErr) });
      }
    }

    // ---- Audit ----
    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
    await audit.log(AuditAction.ORDER_MARK_PAID, EntityType.ORDER, order_id, {
      previousValue: { payment_status: order.payment_status },
      newValue: { payment_status: "paid", payment_method },
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
    logger.error("Mark paid error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
