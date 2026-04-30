import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
    handleCors,
    jsonResponse,
    errorResponse,
    createAdminClient,
    requireAuth,
    requireAdmin,
    createLogger,
    getOrCreateRequestId,
    createAuditLogger,
    AuditAction,
    EntityType,
} from "../_shared/mod.ts";

/**
 * Admin-only: approve a venue claim.
 * Sets claimed=true, assigns owner_id, links venue_users RBAC.
 */
const approveSchema = z.object({
    venue_id: z.string().uuid(),
});

Deno.serve(async (req) => {
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "approve_claim" });

    const cors = handleCors(req);
    if (cors) return cors;

    if (req.method !== "POST") return errorResponse("Method not allowed", 405);

    try {
        const supabaseAdmin = createAdminClient();

        // Auth Check
        const authResult = await requireAuth(req, logger);
        if (authResult instanceof Response) return authResult;
        const { user } = authResult;

        // Admin Check
        const adminResult = await requireAdmin(supabaseAdmin, user.id, logger);
        if (adminResult instanceof Response) return adminResult;

        const body = await req.json();
        const parsed = approveSchema.safeParse(body);
        if (!parsed.success) return errorResponse("Invalid input", 400, parsed.error.issues);
        const { venue_id } = parsed.data;

        // Fetch venue claim data
        const { data: venue, error: venueError } = await supabaseAdmin
            .from("venues")
            .select("id, name, owner_email, contact_email, claimed, owner_id")
            .eq("id", venue_id)
            .single();

        if (venueError || !venue) return errorResponse("Venue not found", 404);
        if (venue.claimed) return errorResponse("Venue already claimed", 409);
        if (!venue.owner_email && !venue.owner_id) {
            return errorResponse("No claim request found on this venue", 400);
        }

        let userId = venue.owner_id;

        // If owner_id is not set, resolve by email
        if (!userId && venue.owner_email) {
            const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers();
            if (listError) throw listError;

            const found = users.users.find(
                (u) => u.email?.toLowerCase() === venue.owner_email?.toLowerCase()
            );

            if (found) {
                userId = found.id;
            } else {
                return errorResponse("User account not found. Owner must sign up first.", 400);
            }
        }

        if (!userId) return errorResponse("Failed to resolve user ID", 500);

        // Update venue: set claimed=true, owner_id, contact_email
        const { error: updateError } = await supabaseAdmin
            .from("venues")
            .update({
                claimed: true,
                owner_id: userId,
                contact_email: venue.owner_email || venue.contact_email,
                owner_email: null, // Clear claim request
                owner_pin: null,
            })
            .eq("id", venue_id);

        if (updateError) {
            return errorResponse("Failed to update venue record", 500, updateError.message);
        }

        // Add to venue_users table (RBAC) — idempotent
        const { data: existingLink } = await supabaseAdmin
            .from("venue_users")
            .select("id")
            .eq("venue_id", venue_id)
            .eq("auth_user_id", userId)
            .single();

        if (!existingLink) {
            const { error: rbacError } = await supabaseAdmin
                .from("venue_users")
                .insert({
                    venue_id: venue_id,
                    auth_user_id: userId,
                    role: "owner",
                    is_active: true,
                });
            if (rbacError) {
                logger.error("Failed to add venue_users", { error: rbacError.message });
            }
        }

        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
        await audit.log(AuditAction.VENDOR_CLAIM, EntityType.VENDOR, venue_id, {
            status: "approved",
            owner_email: venue.owner_email,
        });

        logger.info("Claim approved", { venueId: venue_id, ownerId: userId });

        return jsonResponse({ success: true, message: "Claim approved and owner linked" });
    } catch (e) {
        logger.error("Server error", { error: String(e) });
        return errorResponse("Server error", 500, String(e));
    }
});
