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

// --- Input Validation Schemas ---

// Create Admin User
const createAdminSchema = z.object({
    action: z.literal("create_admin"),
    email: z.string().email(),
    password: z.string().min(6),
    role: z.enum(["admin", "superadmin"]).optional().default("admin"),
});

// Create Vendor (Bar) with Auth
const createVendorSchema = z.object({
    action: z.literal("create_vendor"),
    name: z.string().min(1),
    country: z.enum(["RW", "MT"]),
    slug: z.string().min(1).optional(),
    address: z.string().optional(),
    phone: z.string().optional(),
    revolut_link: z.string().optional(),
    whatsapp: z.string().optional(),
    website: z.string().optional(),
    hours_json: z.unknown().optional(),
    photos_json: z.unknown().optional(),
    // Auth credentials for bar owner
    owner_email: z.string().email(),
    owner_password: z.string().min(6),
});

// Update Vendor
const updateVendorSchema = z.object({
    action: z.literal("update_vendor"),
    venue_id: z.string().uuid(),
    name: z.string().min(1).optional(),
    address: z.string().optional(),
    phone: z.string().optional(),
    revolut_link: z.string().optional(),
    whatsapp: z.string().optional(),
    website: z.string().optional(),
    hours_json: z.unknown().optional(),
    photos_json: z.unknown().optional(),
    status: z.enum(["active", "suspended", "pending"]).optional(),
});

// Delete Vendor
const deleteVendorSchema = z.object({
    action: z.literal("delete_vendor"),
    venue_id: z.string().uuid(),
});

// Get All Vendors (Admin)
const listVendorsSchema = z.object({
    action: z.literal("list_venues"),
});

// Get Admin Users
const listAdminsSchema = z.object({
    action: z.literal("list_admins"),
});

// Toggle Admin Status
const toggleAdminSchema = z.object({
    action: z.literal("toggle_admin_status"),
    admin_id: z.string().uuid(),
    is_active: z.boolean(),
});

// List Countries
const listCountriesSchema = z.object({
    action: z.literal("list_countries"),
});

const requestSchema = z.union([
    createAdminSchema,
    createVendorSchema,
    updateVendorSchema,
    deleteVendorSchema,
    listVendorsSchema,
    listAdminsSchema,
    toggleAdminSchema,
    listCountriesSchema,
]);

Deno.serve(async (req) => {
    const startTime = Date.now();
    const requestId = getOrCreateRequestId(req);
    const logger = createLogger({ requestId, action: "admin_user_management" });

    // Handle CORS preflight
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    if (req.method !== "POST") {
        return errorResponse("Method not allowed", 405);
    }

    try {
        logger.requestStart(req.method, "/admin_user_management");

        const supabaseAdmin = createAdminClient();

        // Authenticate user
        const authResult = await requireAuth(req, logger);
        if (authResult instanceof Response) return authResult;
        const { user } = authResult;

        // Require admin access for all operations
        const adminResult = await requireAdmin(supabaseAdmin, user.id, logger);
        if (adminResult instanceof Response) return adminResult;

        // Parse + validate input
        const body = await req.json();
        const parsed = requestSchema.safeParse(body);
        if (!parsed.success) {
            logger.warn("Validation failed", { errors: parsed.error.issues });
            return errorResponse("Invalid request data", 400, parsed.error.issues);
        }

        const input = parsed.data;
        const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);

        // Route to appropriate handler
        switch (input.action) {
            case "create_admin":
                return await handleCreateAdmin(supabaseAdmin, input, audit, logger);

            case "create_vendor":
                return await handleCreateVendor(supabaseAdmin, input, audit, logger);

            case "update_vendor":
                return await handleUpdateVendor(supabaseAdmin, input, audit, logger);

            case "delete_vendor":
                return await handleDeleteVendor(supabaseAdmin, input, audit, logger);

            case "list_venues":
                return await handleListVendors(supabaseAdmin, logger);

            case "list_admins":
                return await handleListAdmins(supabaseAdmin, logger);

            case "toggle_admin_status":
                return await handleToggleAdminStatus(supabaseAdmin, input, audit, logger);

            case "list_countries":
                return await handleListCountries(supabaseAdmin, logger);

            default:
                return errorResponse("Unknown action", 400);
        }
    } catch (error) {
        const durationMs = Date.now() - startTime;
        logger.error("Admin user management error", { error: String(error), durationMs });
        return errorResponse("Internal server error", 500, String(error));
    }
});

// ========================================================================
// HANDLERS
// ========================================================================

async function handleCreateAdmin(
    supabaseAdmin: any,
    input: z.infer<typeof createAdminSchema>,
    audit: any,
    logger: any
) {
    logger.info("Creating admin user", { email: input.email });

    // Create Supabase auth user
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: input.email,
        password: input.password,
        email_confirm: true,
    });

    if (authError || !authData.user) {
        logger.error("Failed to create auth user", { error: authError?.message });
        return errorResponse("Failed to create user account", 400, authError?.message);
    }

    // Create admin_users record
    const { data: adminRecord, error: adminError } = await supabaseAdmin
        .from("admin_users")
        .insert({
            auth_user_id: authData.user.id,
            role: input.role,
            is_active: true,
        })
        .select()
        .single();

    if (adminError) {
        // Cleanup auth user on failure
        await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
        logger.error("Failed to create admin record", { error: adminError.message });
        return errorResponse("Failed to create admin record", 500, adminError.message);
    }

    await audit.log(AuditAction.ADMIN_CREATE, EntityType.ADMIN_USER, adminRecord.id, {
        email: input.email,
        role: input.role,
    });

    return jsonResponse({
        success: true,
        admin: {
            ...adminRecord,
            email: input.email,
        },
    }, 201);
}

async function handleCreateVendor(
    supabaseAdmin: any,
    input: z.infer<typeof createVendorSchema>,
    audit: any,
    logger: any
) {
    logger.info("Creating vendor with auth", { name: input.name, email: input.owner_email });

    // Create Supabase auth user for bar owner
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: input.owner_email,
        password: input.owner_password,
        email_confirm: true,
    });

    if (authError || !authData.user) {
        logger.error("Failed to create auth user for vendor", { error: authError?.message });
        return errorResponse("Failed to create user account", 400, authError?.message);
    }

    // Generate slug
    const generateSlug = (name: string): string => {
        return name
            .toLowerCase()
            .trim()
            .replace(/[^\w\s-]/g, "")
            .replace(/[\s_-]+/g, "-")
            .replace(/^-+|-+$/g, "");
    };

    let slug = input.slug || generateSlug(input.name);
    let slugAttempts = 0;
    let slugExists = true;

    while (slugExists && slugAttempts < 10) {
        const { data: existing } = await supabaseAdmin
            .from("venues")
            .select("id")
            .eq("slug", slug)
            .single();

        if (!existing) {
            slugExists = false;
        } else {
            slug = `${slug}-${Math.random().toString(36).substring(2, 6)}`;
            slugAttempts++;
        }
    }

    // Generate a synthetic google_place_id for admin-created venues
    const googlePlaceId = `admin_created_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    // Create vendor
    const { data: vendor, error: vendorError } = await supabaseAdmin
        .from("venues")
        .insert({
            google_place_id: googlePlaceId,
            slug,
            name: input.name,
            address: input.address || null,
            phone: input.phone || null,
            revolut_link: input.revolut_link || null,
            whatsapp: input.whatsapp || null,
            website: input.website || null,
            hours_json: input.hours_json || null,
            photos_json: input.photos_json || null,
            status: "pending",
            country: input.country,
        })
        .select()
        .single();

    if (vendorError || !vendor) {
        // Cleanup auth user
        await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
        logger.error("Failed to create vendor", { error: vendorError?.message });
        return errorResponse("Failed to create vendor", 500, vendorError?.message);
    }

    // Create venue_users membership
    const { data: membership, error: membershipError } = await supabaseAdmin
        .from("venue_users")
        .insert({
            venue_id: vendor.id,
            auth_user_id: authData.user.id,
            role: "owner",
            is_active: true,
        })
        .select()
        .single();

    if (membershipError) {
        // Cleanup vendor and auth user
        await supabaseAdmin.from("venues").delete().eq("id", vendor.id);
        await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
        logger.error("Failed to create vendor membership", { error: membershipError.message });
        return errorResponse("Failed to create vendor membership", 500, membershipError.message);
    }

    await audit.log(AuditAction.VENDOR_CREATE, EntityType.VENDOR, vendor.id, {
        name: input.name,
        slug,
        ownerEmail: input.owner_email,
    });

    return jsonResponse({
        success: true,
        vendor: {
            ...vendor,
            owner_email: input.owner_email,
        },
        membership,
    }, 201);
}

async function handleUpdateVendor(
    supabaseAdmin: any,
    input: z.infer<typeof updateVendorSchema>,
    audit: any,
    logger: any
) {
    logger.info("Updating vendor", { vendorId: input.venue_id });

    const updateData: Record<string, any> = {};
    if (input.name !== undefined) updateData.name = input.name;
    if (input.address !== undefined) updateData.address = input.address;
    if (input.phone !== undefined) updateData.phone = input.phone;
    if (input.revolut_link !== undefined) updateData.revolut_link = input.revolut_link;
    if (input.whatsapp !== undefined) updateData.whatsapp = input.whatsapp;
    if (input.website !== undefined) updateData.website = input.website;
    if (input.hours_json !== undefined) updateData.hours_json = input.hours_json;
    if (input.photos_json !== undefined) updateData.photos_json = input.photos_json;
    if (input.status !== undefined) updateData.status = input.status;

    const { data: vendor, error } = await supabaseAdmin
        .from("venues")
        .update(updateData)
        .eq("id", input.venue_id)
        .select()
        .single();

    if (error) {
        logger.error("Failed to update vendor", { error: error.message });
        return errorResponse("Failed to update vendor", 500, error.message);
    }

    await audit.log(AuditAction.VENDOR_UPDATE, EntityType.VENDOR, input.venue_id, updateData);

    return jsonResponse({ success: true, vendor });
}

async function handleDeleteVendor(
    supabaseAdmin: any,
    input: z.infer<typeof deleteVendorSchema>,
    audit: any,
    logger: any
) {
    logger.info("Deleting vendor", { vendorId: input.venue_id });

    // Get venue_users to clean up auth users
    const { data: vendorUsers } = await supabaseAdmin
        .from("venue_users")
        .select("auth_user_id")
        .eq("venue_id", input.venue_id);

    // Delete vendor (cascades to venue_users, menu_items, tables, etc.)
    const { error } = await supabaseAdmin
        .from("venues")
        .delete()
        .eq("id", input.venue_id);

    if (error) {
        logger.error("Failed to delete vendor", { error: error.message });
        return errorResponse("Failed to delete vendor", 500, error.message);
    }

    await audit.log(AuditAction.VENDOR_DELETE, EntityType.VENDOR, input.venue_id, {
        deletedUserCount: vendorUsers?.length || 0,
    });

    return jsonResponse({ success: true, deleted: input.venue_id });
}

async function handleListVendors(supabaseAdmin: any, logger: any) {
    logger.info("Listing all venues for admin");

    const { data: venues, error } = await supabaseAdmin
        .from("venues")
        .select(`
      id, name, slug, address, phone, revolut_link, whatsapp, website,
      status, country, hours_json, photos_json, created_at, updated_at,
      venue_users (
        id, auth_user_id, role, is_active
      )
    `)
        .order("created_at", { ascending: false });

    if (error) {
        logger.error("Failed to list venues", { error: error.message });
        return errorResponse("Failed to list venues", 500, error.message);
    }

    // Fetch emails for owners
    const venuesWithEmails = await Promise.all(
        (venues || []).map(async (vendor: any) => {
            const owner = vendor.venue_users?.find((u: any) => u.role === "owner");
            let ownerEmail = null;
            if (owner) {
                const { data: userData } = await supabaseAdmin.auth.admin.getUserById(owner.auth_user_id);
                ownerEmail = userData?.user?.email || null;
            }
            return { ...vendor, owner_email: ownerEmail };
        })
    );

    return jsonResponse({ success: true, venues: venuesWithEmails });
}

async function handleListAdmins(supabaseAdmin: any, logger: any) {
    logger.info("Listing all admin users");

    const { data: admins, error } = await supabaseAdmin
        .from("admin_users")
        .select("*")
        .order("created_at", { ascending: false });

    if (error) {
        logger.error("Failed to list admins", { error: error.message });
        return errorResponse("Failed to list admins", 500, error.message);
    }

    // Fetch emails for admins
    const adminsWithEmails = await Promise.all(
        (admins || []).map(async (admin: any) => {
            const { data: userData } = await supabaseAdmin.auth.admin.getUserById(admin.auth_user_id);
            return { ...admin, email: userData?.user?.email || null };
        })
    );

    return jsonResponse({ success: true, admins: adminsWithEmails });
}

async function handleToggleAdminStatus(
    supabaseAdmin: any,
    input: z.infer<typeof toggleAdminSchema>,
    audit: any,
    logger: any
) {
    logger.info("Toggling admin status", { adminId: input.admin_id, isActive: input.is_active });

    const { data: admin, error } = await supabaseAdmin
        .from("admin_users")
        .update({ is_active: input.is_active })
        .eq("id", input.admin_id)
        .select()
        .single();

    if (error) {
        logger.error("Failed to update admin status", { error: error.message });
        return errorResponse("Failed to update admin status", 500, error.message);
    }

    await audit.log(AuditAction.ADMIN_UPDATE, EntityType.ADMIN_USER, input.admin_id, {
        is_active: input.is_active,
    });

    return jsonResponse({ success: true, admin });
}

async function handleListCountries(supabaseAdmin: any, logger: any) {
    logger.info("Listing all active countries");

    const { data: countries, error } = await supabaseAdmin
        .from("countries")
        .select("code, name, currency, currency_symbol, is_active")
        .eq("is_active", true)
        .order("name", { ascending: true });

    if (error) {
        logger.error("Failed to list countries", { error: error.message });
        return errorResponse("Failed to list countries", 500, error.message);
    }

    return jsonResponse({ success: true, countries: countries || [] });
}
