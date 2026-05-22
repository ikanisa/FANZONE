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
import {
  type AnyOrderStatus,
  normalizeOrderStatusForTransition,
  type TargetOrderStatus,
} from "../_shared/order_lifecycle.ts";

const updateStatusSchema = z.object({
  order_id: z.string().uuid(),
  status: z.enum([
    "draft",
    "submitted",
    "accepted",
    "preparing",
    "ready",
    "served",
    "completed",
    "cancelled",
    "refunded",
    "disputed",
    "received",
  ]),
  reason: z.string().trim().max(500).optional(),
  metadata: z.record(z.unknown()).optional(),
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

    const { order_id, status: newStatus, reason, metadata } = parsed.data;

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
      logger,
    );
    if (rbacResult instanceof Response) return rbacResult;

    // ---- Canonical transition RPC ----
    const { data: transition, error: transitionError } = await supabaseUser.rpc(
      "venue_transition_order_status",
      {
        p_order_id: order_id,
        p_next_status: normalizeOrderStatusForTransition(
          newStatus as AnyOrderStatus,
        ) as TargetOrderStatus,
        p_reason: reason ?? null,
        p_metadata: {
          ...(metadata ?? {}),
          source: "order_update_status",
          edge_request_id: requestId,
        },
      },
    );

    if (transitionError) {
      logger.warn("Failed to transition order status", {
        error: transitionError.message,
        currentStatus: order.status,
        newStatus,
        orderId: order_id,
      });
      return errorResponse(transitionError.message, 400, undefined, req);
    }

    const { data: updatedOrder, error: updatedError } = await supabaseAdmin
      .from("orders")
      .select()
      .eq("id", order_id)
      .single();

    if (updatedError || !updatedOrder) {
      logger.error("Failed to load transitioned order", {
        error: updatedError?.message,
        orderId: order_id,
      });
      return errorResponse(
        "Order status changed but reload failed",
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
      transition,
      order: updatedOrder,
    });
  } catch (error) {
    logger.error("Update status error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
