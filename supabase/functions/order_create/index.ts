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
  optionalAuth,
} from "../_shared/mod.ts";

// --- Input Validation Schema ---
const orderItemSchema = z
  .object({
    menu_item_id: z.string().uuid(),
    quantity: z.number().int().positive().optional(),
    qty: z.number().int().positive().optional(),
    add_ons: z.unknown().optional(),
    modifiers_json: z.unknown().optional(),
  })
  .refine((item) => item.quantity !== undefined || item.qty !== undefined, {
    message: "quantity is required",
  });

const createOrderSchema = z
  .object({
    venue_id: z.string().uuid(),
    table_number: z.string().trim().min(1).max(24),
    payment_method: z
      .enum(["cash", "momo", "revolut", "other"])
      .default("cash"),
    items: z.array(orderItemSchema).min(1),
    special_instructions: z.string().max(1000).nullable().optional(),
    notes: z.string().max(1000).nullable().optional(),
  });

type CreateOrderInput = z.infer<typeof createOrderSchema>;

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "order_create" });

  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, undefined, req);
  }

  try {
    logger.requestStart(req.method, "/order_create");

    // Initialize admin client
    const supabaseAdmin = createAdminClient();

    // Authentication required — FANZONE mandates a verified Supabase user.
    const authResult = await optionalAuth(req, logger);
    const userId = authResult?.user?.id ?? null;

    if (!userId) {
      return errorResponse(
        "Authentication required to place orders",
        401,
        undefined,
        req,
      );
    }

    logger.info("Auth check", { authenticated: true, userId });

    // Parse + validate input
    const body = await req.json();
    const parsed = createOrderSchema.safeParse(body);
    if (!parsed.success) {
      logger.warn("Validation failed", { errors: parsed.error.issues });
      return errorResponse(
        "Invalid request data",
        400,
        parsed.error.issues,
        req,
      );
    }

    const input: CreateOrderInput = parsed.data;
    logger.info("Processing order", {
      venueId: input.venue_id,
      tableNumber: input.table_number,
      itemCount: input.items.length,
    });

    // Create audit logger
    const audit = createAuditLogger(supabaseAdmin, userId, requestId, logger);

    // ========================================================================
    // STEP 1: Validate venue exists and is active
    // ========================================================================
    const { data: venue, error: venueError } = await supabaseAdmin
      .from("venues")
      .select("id, is_active, country_code, currency_code")
      .eq("id", input.venue_id)
      .single();

    if (venueError || !venue) {
      logger.warn("Venue not found", { venueId: input.venue_id });
      return errorResponse("Venue not found", 404, undefined, req);
    }

    if (!venue.is_active) {
      logger.warn("Venue not active", { venueId: input.venue_id });
      return errorResponse("Venue is not active", 400, undefined, req);
    }

    // ========================================================================
    // STEP 2: Resolve app-entered table number
    // ========================================================================
    const tableNumber = input.table_number.trim().replace(/\s+/g, " ");
    const { data: table, error: tableError } = await supabaseAdmin
      .from("tables")
      .upsert(
        {
          venue_id: input.venue_id,
          table_number: tableNumber,
          is_active: true,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "venue_id,table_number" },
      )
      .select("id, table_number")
      .single();

    if (tableError || !table) {
      logger.error("Failed to resolve table number", {
        venueId: input.venue_id,
        tableNumber,
        error: tableError?.message,
      });
      return errorResponse(
        "Failed to resolve table number",
        500,
        tableError?.message,
        req,
      );
    }

    // ========================================================================
    // STEP 3: Fetch menu items and validate availability
    // ========================================================================
    const menuItemIds = input.items.map((item) => item.menu_item_id);
    const { data: menuItems, error: menuItemsError } = await supabaseAdmin
      .from("menu_items")
      .select(
        "id, name, description, price, currency_code, is_available, venue_id",
      )
      .in("id", menuItemIds)
      .eq("venue_id", input.venue_id);

    if (menuItemsError || !menuItems || menuItems.length === 0) {
      logger.warn("Menu items not found", { menuItemIds });
      return errorResponse("Menu items not found", 404, undefined, req);
    }

    const menuItemsMap = new Map(menuItems.map((item) => [item.id, item]));
    for (const inputItem of input.items) {
      const menuItem = menuItemsMap.get(inputItem.menu_item_id);
      if (!menuItem) {
        return errorResponse(
          `Menu item ${inputItem.menu_item_id} not found`,
          404,
          undefined,
          req,
        );
      }
      if (!menuItem.is_available) {
        return errorResponse(
          `Menu item ${menuItem.name} is not available`,
          400,
          undefined,
          req,
        );
      }
      const quantity = inputItem.quantity ?? inputItem.qty!;
      if (quantity <= 0) {
        return errorResponse(
          `Invalid quantity for ${menuItem.name}`,
          400,
          undefined,
          req,
        );
      }
    }

    // ========================================================================
    // STEP 4: Compute total amount server-side
    // ========================================================================
    let totalAmount = 0;
    const orderItemsData = input.items.map((inputItem) => {
      const menuItem = menuItemsMap.get(inputItem.menu_item_id)!;
      const quantity = inputItem.quantity ?? inputItem.qty!;
      const itemTotal = Number(menuItem.price) * quantity;
      totalAmount += itemTotal;

      return {
        menu_item_id: menuItem.id,
        item_name_snapshot: menuItem.name,
        item_description_snapshot: menuItem.description,
        quantity,
        unit_price: menuItem.price,
        line_total: Math.round(itemTotal * 100) / 100,
        currency_code: menuItem.currency_code || venue.currency_code,
        add_ons: inputItem.add_ons || inputItem.modifiers_json || [],
      };
    });

    totalAmount = Math.round(totalAmount * 100) / 100;

    // ========================================================================
    // STEP 5: Generate unique order code
    // ========================================================================
    const generateOrderCode = () => {
      const timestamp = Date.now().toString(36).toUpperCase().slice(-4);
      const random = Math.random().toString(36).substring(2, 6).toUpperCase();
      return `FZ-${timestamp}-${random}`;
    };

    let orderCode = generateOrderCode();
    let attempts = 0;
    let codeExists = true;

    while (codeExists && attempts < 10) {
      const { data: existing } = await supabaseAdmin
        .from("orders")
        .select("id")
        .eq("venue_id", input.venue_id)
        .eq("order_code", orderCode)
        .single();

      if (!existing) {
        codeExists = false;
      } else {
        orderCode = generateOrderCode();
        attempts++;
      }
    }

    if (codeExists) {
      logger.error("Failed to generate unique order code after retries");
      return errorResponse(
        "Failed to generate unique order code",
        500,
        undefined,
        req,
      );
    }

    // ========================================================================
    // STEP 6: Insert order and order items
    // ========================================================================
    const currencyCode = venue.currency_code ||
      (venue.country_code === "RW" ? "RWF" : "EUR");
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .insert({
        venue_id: input.venue_id,
        table_id: table.id,
        user_id: userId,
        order_code: orderCode,
        status: "submitted",
        payment_method: input.payment_method,
        payment_status: "pending",
        subtotal_amount: totalAmount,
        tax_amount: 0,
        tip_amount: 0,
        total_amount: totalAmount,
        currency_code: currencyCode,
        special_instructions: input.special_instructions || input.notes || null,
      })
      .select()
      .single();

    if (orderError || !order) {
      logger.error("Failed to create order", { error: orderError?.message });
      return errorResponse(
        "Failed to create order",
        500,
        orderError?.message,
        req,
      );
    }

    const { error: stateEventError } = await supabaseAdmin.from(
      "order_state_events",
    ).insert({
      order_id: order.id,
      venue_id: input.venue_id,
      actor_user_id: userId,
      previous_status: null,
      next_status: "submitted",
      reason: "Order submitted by customer",
      source: "order_create",
      metadata: {
        request_id: requestId,
        table_number: tableNumber,
        item_count: input.items.length,
      },
    });
    if (stateEventError) {
      logger.error("Failed to write initial order state event", {
        orderId: order.id,
        error: stateEventError.message,
      });
      await supabaseAdmin.from("orders").delete().eq("id", order.id);
      return errorResponse(
        "Failed to create order state event",
        500,
        stateEventError.message,
        req,
      );
    }

    // Insert order items
    const orderItemsToInsert = orderItemsData.map((item) => ({
      order_id: order.id,
      ...item,
    }));

    const { data: insertedItems, error: itemsError } = await supabaseAdmin
      .from("order_items")
      .insert(orderItemsToInsert)
      .select();

    if (itemsError || !insertedItems) {
      logger.error("Failed to insert order items, cleaning up order", {
        error: itemsError?.message,
      });
      await supabaseAdmin.from("orders").delete().eq("id", order.id);
      return errorResponse(
        "Failed to create order items",
        500,
        itemsError?.message,
        req,
      );
    }

    // ========================================================================
    // STEP 7: Write audit log
    // ========================================================================
    await audit.log(AuditAction.ORDER_CREATE, EntityType.ORDER, order.id, {
      vendorId: input.venue_id,
      tableId: table.id,
      tableNumber,
      orderCode,
      totalAmount,
      itemCount: input.items.length,
    });

    // ========================================================================
    // STEP 8: Return created order with items
    // ========================================================================
    const durationMs = Date.now() - startTime;
    logger.requestEnd(201, durationMs);

    return jsonResponse(
      {
        success: true,
        requestId,
        order: {
          ...order,
          items: insertedItems,
        },
      },
      201,
      req,
    );
  } catch (error) {
    const durationMs = Date.now() - startTime;
    logger.error("Order creation error", { error: String(error), durationMs });
    return errorResponse("Internal server error", 500, String(error), req);
  }
});
