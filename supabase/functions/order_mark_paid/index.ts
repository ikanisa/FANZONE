import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  createAdminClient,
  createLogger,
  errorResponse,
  getOrCreateRequestId,
  handleCors,
  jsonResponse,
  requireAuth,
  requireVendorOrAdmin,
} from "../_shared/mod.ts";

const markPaidSchema = z.object({
  order_id: z.string().uuid(),
  payment_method: z
    .enum(["cash", "momo", "revolut", "other"])
    .optional()
    .default("cash"),
  amount_received: z.number().nonnegative().optional(),
  external_reference: z.string().trim().max(120).optional(),
  note: z.string().trim().max(240).optional(),
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

    const {
      order_id,
      payment_method,
      amount_received,
      external_reference,
      note,
    } = parsed.data;

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

    // External payments are off-platform. This endpoint records a staff/admin
    // manual confirmation after the customer shows cash, USSD, or Revolut proof.
    const { data: paymentRecord, error: paymentError } = await supabaseUser.rpc(
      "venue_update_order_payment_status",
      {
        p_order_id: order_id,
        p_payment_status: "paid",
        p_payment_method: payment_method,
        p_actor_note: note ?? null,
        p_amount_received: amount_received ?? null,
        p_external_reference: external_reference ?? null,
      },
    );

    if (paymentError) {
      logger.warn("Failed to record manual payment", {
        orderId: order_id,
        error: paymentError.message,
      });
      return errorResponse(paymentError.message, 400, undefined, req);
    }

    // FET credit is handled by the database trigger when payment_status
    // transitions to paid.

    const { data: updatedOrder, error: updatedError } = await supabaseAdmin
      .from("orders")
      .select()
      .eq("id", order_id)
      .single();

    if (updatedError || !updatedOrder) {
      logger.error("Failed to load paid order", {
        orderId: order_id,
        error: updatedError?.message,
      });
      return errorResponse(
        "Payment recorded but order reload failed",
        500,
        undefined,
        req,
      );
    }

    const durationMs = Date.now() - startTime;
    logger.requestEnd(200, durationMs);

    return jsonResponse({
      success: true,
      requestId,
      payment: paymentRecord,
      order: updatedOrder,
    });
  } catch (error) {
    logger.error("Mark paid error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
