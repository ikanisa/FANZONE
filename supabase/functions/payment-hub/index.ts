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
    createAuditLogger,
    AuditAction,
    EntityType,
} from "../_shared/mod.ts";

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
        if (!parsed.success) return errorResponse("Invalid request", 400, parsed.error.issues);

        const { order_id, venue_id, method } = parsed.data;

        // 1. Fetch Order and verify ownership using the authenticated user id.
        const { data: order } = await supabaseAdmin
            .from("orders")
            .select("id, venue_id, user_id, total_amount, status, currency_code")
            .eq("id", order_id).eq("venue_id", venue_id).single();

        if (!order) return errorResponse("Order not found", 404);
        if (order.user_id !== user.id) {
            logger.warn("Unauthorized payment attempt", { user_id: user.id, order_id });
            return errorResponse("You are not authorized to pay for this order", 403);
        }
        if (order.status === "cancelled") return errorResponse("Cannot pay cancelled order", 400);

        // 2. Fetch Venue
        const { data: venue } = await supabaseAdmin
            .from("venues")
            .select("name, country_code, owner_phone, whatsapp, revolut_link")
            .eq("id", venue_id)
            .single();

        if (!venue) return errorResponse("Venue not found", 404);

        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);

        // 3. Method Routing
        if (method === "momo") {
            if (venue.country_code !== "RW") {
                return errorResponse("MoMo is only available for venues in Rwanda", 400);
            }

            const amount = Math.ceil(Number(order.total_amount || 0));
            const venuePhone = (venue.owner_phone || venue.whatsapp || "").replace(/\D/g, "");
            const ussdString = venuePhone ? `*182*1*1*${venuePhone}*${amount}#` : "*182*1*1#";
            
            await audit.log(AuditAction.PAYMENT_HANDOFF, EntityType.PAYMENT, order_id, {
                method: "momo", amount: String(amount), currency: "RWF"
            });

            await supabaseAdmin.from("orders").update({ payment_method: "momo" }).eq("id", order_id);

            return jsonResponse({
                success: true,
                ussd_string: ussdString,
                amount: String(amount),
                currency: "RWF",
                instructions: `Dial ${ussdString} to pay ${amount} RWF.`
            });

        } else if (method === "revolut") {
            if (!venue.revolut_link) {
                return errorResponse("Venue does not have a Revolut payment link set up", 400);
            }

            const amount = Number(order.total_amount || 0).toFixed(2);
            const paymentUrl = `${venue.revolut_link.replace(/\/$/, "")}?amount=${amount}`;

            await audit.log(AuditAction.PAYMENT_HANDOFF, EntityType.PAYMENT, order_id, {
                method: "revolut", amount, currency: "EUR"
            });

            await supabaseAdmin.from("orders").update({ payment_method: "revolut" }).eq("id", order_id);

            return jsonResponse({
                success: true,
                payment_url: paymentUrl,
                amount,
                currency: "EUR"
            });
        }

        return errorResponse("Unsupported payment method", 400);

    } catch (error) {
        logger.error("Payment hub error", { error: String(error) });
        return errorResponse("Internal server error", 500, String(error));
    }
});
