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
} from "../_shared/mod.ts";
import { buildOffPlatformPaymentHandoff } from "../_shared/off_platform_payment.ts";

const paymentSchema = z.object({
  order_id: z.string().uuid(),
  venue_id: z.string().uuid(),
  method: z.enum(["momo", "revolut"]),
});

Deno.serve(async (req) => {
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "payment_hub" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const supabaseAdmin = createAdminClient();
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user } = authResult;

    const body = await req.json();
    const parsed = paymentSchema.safeParse(body);
    if (!parsed.success) {
      return errorResponse("Invalid request", 400, parsed.error.issues);
    }

    const { order_id, venue_id, method } = parsed.data;

    // 1. Fetch order and verify ownership using the authenticated user id.
    const { data: order } = await supabaseAdmin
      .from("orders")
      .select("id, venue_id, user_id, total_amount, status, currency_code")
      .eq("id", order_id).eq("venue_id", venue_id).single();

    if (!order) return errorResponse("Order not found", 404);
    if (order.user_id !== user.id) {
      logger.warn("Unauthorized payment attempt", {
        user_id: user.id,
        order_id,
      });
      return errorResponse("You are not authorized to pay for this order", 403);
    }
    if (order.status === "cancelled") {
      return errorResponse("Cannot pay cancelled order", 400);
    }

    // 2. Fetch venue payment metadata. This function only creates external
    // handoff instructions; it never talks to a payment provider and never
    // marks an order paid.
    const { data: venue } = await supabaseAdmin
      .from("venues")
      .select(
        "name, country_code, owner_phone, whatsapp, revolut_link, momo_code",
      )
      .eq("id", venue_id)
      .single();

    if (!venue) return errorResponse("Venue not found", 404);

    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);

    let handoff;
    try {
      handoff = buildOffPlatformPaymentHandoff(method, {
        countryCode: venue.country_code,
        ownerPhone: venue.owner_phone,
        whatsapp: venue.whatsapp,
        momoCode: venue.momo_code,
        revolutLink: venue.revolut_link,
      }, {
        totalAmount: Number(order.total_amount || 0),
        currencyCode: order.currency_code,
      });
    } catch (error) {
      return errorResponse(
        error instanceof Error ? error.message : "Payment handoff unavailable",
        400,
      );
    }

    await audit.log(AuditAction.PAYMENT_HANDOFF, EntityType.PAYMENT, order_id, {
      method,
      amount: handoff.amount,
      currency: handoff.currency,
      autoConfirmsPayment: false,
      requiresStaffConfirmation: true,
    });

    await supabaseAdmin.from("orders").update({ payment_method: method }).eq(
      "id",
      order_id,
    );

    await supabaseAdmin.from("payment_events").insert({
      order_id,
      provider: method,
      status: "pending",
      request_payload: { requested_by: user.id, request_id: requestId },
      response_payload: {
        source: "payment-hub",
        handoff_type: handoff.handoff_type,
        auto_confirms_payment: false,
        requires_staff_confirmation: true,
      },
    });

    return jsonResponse({
      success: true,
      order_id,
      ...handoff,
    });
  } catch (error) {
    logger.error("Payment hub error", { error: String(error) });
    return errorResponse("Internal server error", 500, String(error));
  }
});
