import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
    handleCors,
    jsonResponse,
    errorResponse,
    createAdminClient,
    createLogger,
    getOrCreateRequestId,
} from "../_shared/mod.ts";

/**
 * Submit a venue claim (anonymous/unauthenticated).
 * Stores contact info on the venue record for admin review.
 * Does NOT mark venue as claimed.
 */
const claimSchema = z.object({
    venue_id: z.string().uuid(),
    email: z.string().email(),
    phone: z.string().min(8).max(20),
});

Deno.serve(async (req) => {
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "submit_claim" });

    const cors = handleCors(req);
    if (cors) return cors;

    if (req.method !== "POST") return errorResponse("Method not allowed", 405);

    try {
        const supabaseAdmin = createAdminClient();
        const body = await req.json();
        const parsed = claimSchema.safeParse(body);

        if (!parsed.success) {
            return errorResponse("Invalid input", 400, parsed.error.issues);
        }
        const { venue_id, email, phone } = parsed.data;

        // Check if venue exists and is unclaimed
        const { data: venue, error: venueError } = await supabaseAdmin
            .from("venues")
            .select("id, claimed, name")
            .eq("id", venue_id)
            .single();

        if (venueError || !venue) return errorResponse("Venue not found", 404);
        if (venue.claimed) return errorResponse("Venue already claimed", 409);

        // Store claim contact on venue (admin reviews and approves separately)
        const { error: updateError } = await supabaseAdmin
            .from("venues")
            .update({
                owner_email: email,
                owner_phone: phone,
            })
            .eq("id", venue_id);

        if (updateError) {
            logger.error("Failed to submit claim", { error: updateError.message });
            return errorResponse("Failed to submit claim", 500, updateError.message);
        }

        logger.info(`Claim submitted for venue ${venue.name} by ${email}`);

        return jsonResponse({ success: true, message: "Claim submitted for review" });
    } catch (e) {
        logger.error("Server error", { error: String(e) });
        return errorResponse("Server error", 500, String(e));
    }
});
