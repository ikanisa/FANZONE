import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
    handleCors,
    jsonResponse,
    errorResponse,
    createAdminClient,
    requireAuth,
    checkRateLimit,
    createLogger,
    getOrCreateRequestId,
    createAuditLogger,
    AuditAction,
    EntityType,
} from "../_shared/mod.ts";
import type { RateLimitConfig } from "../_shared/mod.ts";

// --- Input Validation Schema ---
const menuItemSchema = z.object({
    name: z.string().min(1).max(200),
    description: z.string().max(500).optional().nullable(),
    price: z.number().positive(),
    category: z.string().max(100).optional().nullable(),
});

const onboardingSchema = z.object({
    venue_name: z.string().min(2).max(200),
    country: z.enum(["RW", "MT"]),
    city: z.string().min(2).max(100),
    address: z.string().max(300).optional().nullable(),
    whatsapp: z.string().min(8).max(20).optional().nullable(),
    revolut_link: z.string().url().optional().nullable(),
    momo_code: z.string().max(20).optional().nullable(),
    menu_items: z.array(menuItemSchema).max(100).optional().nullable(),
});

const RATE_LIMIT: RateLimitConfig = {
    maxRequests: 5,
    window: "1 hour",
    endpoint: "bar_onboarding_submit",
};

Deno.serve(async (req) => {
    const startTime = Date.now();
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "bar_onboarding_submit" });

    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    if (req.method !== "POST") {
        return errorResponse("Method not allowed", 405);
    }

    try {
        logger.requestStart(req.method, "/bar_onboarding_submit");

        const supabaseAdmin = createAdminClient();

        // Authenticate user
        const authResult = await requireAuth(req, logger);
        if (authResult instanceof Response) return authResult;
        const { user } = authResult;

        // Rate limiting
        const rateResult = await checkRateLimit(supabaseAdmin, user.id, RATE_LIMIT, logger);
        if (rateResult instanceof Response) return rateResult;

        // Parse + validate input
        const body = await req.json();
        const parsed = onboardingSchema.safeParse(body);
        if (!parsed.success) {
            logger.warn("Validation failed", { errors: parsed.error.issues });
            return errorResponse("Invalid request data", 400, parsed.error.issues);
        }

        const input = parsed.data;
        logger.info("Processing onboarding", { venue_name: input.venue_name, country: input.country });

        // ========================================================================
        // STEP 1: Create the venue record (status = pending until admin approval)
        // ========================================================================
        const { data: venue, error: venueError } = await supabaseAdmin
            .from("venues")
            .insert({
                name: input.venue_name,
                country_code: input.country,
                venue_type: "bar",
                currency_code: input.country === "RW" ? "RWF" : "EUR",
                city: input.city,
                address_line1: input.address || null,
                is_active: false,
                onboarding_status: "draft",
                owner_id: user.id,
                whatsapp: input.whatsapp || null,
                revolut_link: input.revolut_link || null,
                momo_code: input.momo_code || null,
            })
            .select("id")
            .single();

        if (venueError || !venue) {
            logger.error("Failed to create venue", { error: venueError?.message });
            return errorResponse("Failed to create venue", 500, venueError?.message);
        }

        // ========================================================================
        // STEP 2: Link user as venue owner (inactive until approved)
        // ========================================================================
        const { error: linkError } = await supabaseAdmin
            .from("venue_users")
            .insert({
                venue_id: venue.id,
                user_id: user.id,
                role: "owner",
                is_active: false, // Activated on approval
            });

        if (linkError) {
            logger.error("Failed to link venue user", { error: linkError.message });
        }

        // ========================================================================
        // STEP 3: Create onboarding request for admin review
        // ========================================================================
        const { error: requestError } = await supabaseAdmin
            .from("onboarding_requests")
            .insert({
                venue_id: venue.id,
                submitted_by: user.id,
                email: user.email || null,
                phone: user.phone || null,
                whatsapp: input.whatsapp || null,
                revolut_link: input.revolut_link || null,
                momo_code: input.momo_code || null,
                menu_items_json: input.menu_items || null,
                status: "pending",
            });

        if (requestError) {
            logger.error("Failed to create onboarding request", { error: requestError.message });
        }

        // ========================================================================
        // STEP 4: Audit log
        // ========================================================================
        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);
        await audit.log(AuditAction.VENDOR_CREATE, EntityType.VENDOR, venue.id, {
            action: "onboarding_submitted",
            venue_name: input.venue_name,
            country: input.country,
        });

        const durationMs = Date.now() - startTime;
        logger.requestEnd(200, durationMs);

        return jsonResponse({
            success: true,
            venueId: venue.id,
            message: "Bar onboarding submitted for review. You will be notified once approved.",
        });
    } catch (error) {
        const durationMs = Date.now() - startTime;
        logger.error("Onboarding error", { error: String(error), durationMs });
        return errorResponse("Internal server error", 500, String(error));
    }
});
