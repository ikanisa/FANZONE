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
 * Admin-only: approve or reject a bar onboarding request.
 * On approval: activates venue, activates venue_user, inserts menu items.
 * On rejection: deactivates venue_user, marks request rejected.
 */
const approvalSchema = z.object({
    request_id: z.string().uuid(),
    action: z.enum(["approve", "reject"]),
    notes: z.string().max(500).optional().nullable(),
});

type ApprovalInput = z.infer<typeof approvalSchema>;

Deno.serve(async (req) => {
    const startTime = Date.now();
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "admin_approve_onboarding" });

    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    if (req.method !== "POST") {
        return errorResponse("Method not allowed", 405);
    }

    try {
        logger.requestStart(req.method, "/admin_approve_onboarding");

        const supabaseAdmin = createAdminClient();

        // Authenticate user
        const authResult = await requireAuth(req, logger);
        if (authResult instanceof Response) return authResult;
        const { user } = authResult;

        // Require admin access
        const adminResult = await requireAdmin(supabaseAdmin, user.id, logger);
        if (adminResult instanceof Response) return adminResult;

        // Parse + validate input
        const body = await req.json();
        const parsed = approvalSchema.safeParse(body);
        if (!parsed.success) {
            logger.warn("Validation failed", { errors: parsed.error.issues });
            return errorResponse("Invalid request data", 400, parsed.error.issues);
        }

        const input: ApprovalInput = parsed.data;
        logger.info("Processing approval action", {
            requestId: input.request_id,
            action: input.action,
        });

        // ========================================================================
        // STEP 1: Get the onboarding request
        // ========================================================================
        const { data: request, error: requestError } = await supabaseAdmin
            .from("onboarding_requests")
            .select("*, venues(*)")
            .eq("id", input.request_id)
            .single();

        if (requestError || !request) {
            logger.warn("Onboarding request not found", { requestId: input.request_id });
            return errorResponse("Onboarding request not found", 404);
        }

        if (request.status !== "pending") {
            logger.warn("Request already processed", {
                requestId: input.request_id,
                status: request.status,
            });
            return errorResponse(`Request already ${request.status}`, 400);
        }

        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);

        // ========================================================================
        // STEP 2: Process based on action
        // ========================================================================
        if (input.action === "approve") {
            // ---- APPROVE: Update venue, activate user, add menu items ----
            const vendorUpdates: Record<string, unknown> = {
                is_active: true,
                onboarding_status: "live",
            };
            if (request.whatsapp) vendorUpdates.whatsapp = request.whatsapp;
            if (request.revolut_link) vendorUpdates.revolut_link = request.revolut_link;
            if (request.momo_code) vendorUpdates.momo_code = request.momo_code;

            const { error: vendorUpdateError } = await supabaseAdmin
                .from("venues")
                .update(vendorUpdates)
                .eq("id", request.venue_id);

            if (vendorUpdateError) {
                logger.error("Failed to update vendor", { error: vendorUpdateError.message });
                return errorResponse("Failed to update bar", 500, vendorUpdateError.message);
            }

            // Activate the venue_user
            const { error: userUpdateError } = await supabaseAdmin
                .from("venue_users")
                .update({ is_active: true })
                .eq("venue_id", request.venue_id)
                .eq("user_id", request.submitted_by);

            if (userUpdateError) {
                logger.error("Failed to activate venue user", { error: userUpdateError.message });
                return errorResponse("Failed to activate user", 500, userUpdateError.message);
            }

            // Add menu items if provided
            if (request.menu_items_json && Array.isArray(request.menu_items_json)) {
                const categoryNames = [
                    ...new Set(
                        request.menu_items_json.map((item: Record<string, unknown>) =>
                            String(item.category || "Menu").trim() || "Menu"
                        )
                    ),
                ];

                const categoryRows = categoryNames.map((name, index) => ({
                    venue_id: request.venue_id,
                    name,
                    display_order: index,
                }));

                const { data: categories, error: categoryError } = await supabaseAdmin
                    .from("menu_categories")
                    .insert(categoryRows)
                    .select("id, name");

                if (categoryError) {
                    logger.warn("Failed to add menu categories", { error: categoryError.message });
                }

                const categoryByName = new Map(
                    (categories || []).map((category: Record<string, unknown>) => [
                        String(category.name),
                        String(category.id),
                    ])
                );

                const currencyCode = request.venues?.currency_code || "EUR";
                const menuItems = request.menu_items_json
                    .map((item: Record<string, unknown>, index: number) => {
                        const categoryName = String(item.category || "Menu").trim() || "Menu";
                        const categoryId = categoryByName.get(categoryName);
                        if (!categoryId) return null;
                        return {
                            venue_id: request.venue_id,
                            category_id: categoryId,
                            name: item.name,
                            description: item.description || null,
                            price: item.price,
                            currency_code: currencyCode,
                            is_available: true,
                            display_order: index,
                        };
                    })
                    .filter(Boolean);

                if (menuItems.length > 0) {
                    const { error: menuError } = await supabaseAdmin
                        .from("menu_items")
                        .insert(menuItems);

                    if (menuError) {
                        logger.warn("Failed to add menu items", { error: menuError.message });
                        // Non-fatal — don't fail the approval
                    } else {
                        logger.info("Added menu items", { count: menuItems.length });
                    }
                }
            }

            // Update request status
            await supabaseAdmin
                .from("onboarding_requests")
                .update({
                    status: "approved",
                    admin_notes: input.notes || null,
                    reviewed_by: user.id,
                    reviewed_at: new Date().toISOString(),
                })
                .eq("id", input.request_id);

            await audit.log(AuditAction.VENDOR_UPDATE, EntityType.VENDOR, request.venue_id, {
                action: "onboarding_approved",
                requestId: input.request_id,
                approvedBy: user.id,
            });

            logger.info("Onboarding approved", { vendorId: request.venue_id });
        } else {
            // ---- REJECT: deactivate user, mark rejected ----
            await supabaseAdmin
                .from("onboarding_requests")
                .update({
                    status: "rejected",
                    admin_notes: input.notes || null,
                    reviewed_by: user.id,
                    reviewed_at: new Date().toISOString(),
                })
                .eq("id", input.request_id);

            await supabaseAdmin
                .from("venue_users")
                .update({ is_active: false })
                .eq("venue_id", request.venue_id)
                .eq("user_id", request.submitted_by);

            await audit.log(AuditAction.VENDOR_UPDATE, EntityType.VENDOR, request.venue_id, {
                action: "onboarding_rejected",
                requestId: input.request_id,
                rejectedBy: user.id,
                reason: input.notes || "No reason provided",
            });

            logger.info("Onboarding rejected", { vendorId: request.venue_id });
        }

        // ========================================================================
        // STEP 3: Return success
        // ========================================================================
        const durationMs = Date.now() - startTime;
        logger.requestEnd(200, durationMs);

        return jsonResponse({
            success: true,
            requestId,
            action: input.action,
            message:
                input.action === "approve"
                    ? "Bar onboarding approved. The owner can now log in."
                    : "Bar onboarding rejected.",
        });
    } catch (error) {
        const durationMs = Date.now() - startTime;
        logger.error("Approval error", { error: String(error), durationMs });
        return errorResponse("Internal server error", 500, String(error));
    }
});
