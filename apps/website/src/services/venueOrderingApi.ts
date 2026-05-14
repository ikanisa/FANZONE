import type {
  MenuCategory,
  MenuItem,
  Order,
  PaymentMethod,
  Venue,
} from "../types";
import { ensureClient, type JsonRecord } from "./apiClient";
import {
  mapMenuCategoryRow,
  mapMenuItemRow,
  mapOrderRow,
  mapVenueRow,
} from "./apiMappers";

export async function fetchVenues(countryCode?: string): Promise<Venue[]> {
  const client = await ensureClient();
  if (!client) return [];

  let query = client.from("venues").select("*").eq("is_active", true);

  if (countryCode) {
    query = query.eq("country_code", countryCode);
  }

  const { data, error } = await query.order("name");
  if (error) throw error;

  return ((data || []) as JsonRecord[]).map(mapVenueRow);
}

export async function fetchVenueBySlug(slug: string): Promise<Venue | null> {
  const client = await ensureClient();
  if (!client) return null;

  const { data, error } = await client
    .from("venues")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();

  if (error) throw error;
  return data ? mapVenueRow(data as JsonRecord) : null;
}

export async function fetchMenu(
  venueId: string,
): Promise<{ categories: MenuCategory[]; items: MenuItem[] }> {
  const client = await ensureClient();
  if (!client) return { categories: [], items: [] };

  const [catRes, itemRes] = await Promise.all([
    client
      .from("menu_categories")
      .select("*")
      .eq("venue_id", venueId)
      .eq("is_visible", true)
      .order("display_order"),
    client
      .from("menu_items")
      .select("*")
      .eq("venue_id", venueId)
      .eq("is_available", true)
      .order("display_order"),
  ]);

  if (catRes.error) throw catRes.error;
  if (itemRes.error) throw itemRes.error;

  return {
    categories: ((catRes.data || []) as JsonRecord[]).map(mapMenuCategoryRow),
    items: ((itemRes.data || []) as JsonRecord[]).map(mapMenuItemRow),
  };
}

export async function placeOrder(payload: {
  venueId: string;
  tableId?: string;
  tablePublicCode?: string;
  paymentMethod: PaymentMethod;
  items: Array<{ menuItemId: string; quantity: number }>;
}): Promise<Order> {
  const client = await ensureClient();
  if (!client) throw new Error("Supabase client not available");

  const body: Record<string, unknown> = {
    venue_id: payload.venueId,
    payment_method: payload.paymentMethod,
    items: payload.items.map((item) => ({
      menu_item_id: item.menuItemId,
      quantity: item.quantity,
    })),
  };

  if (payload.tableId) {
    body.table_id = payload.tableId;
  } else if (payload.tablePublicCode) {
    body.table_public_code = payload.tablePublicCode;
  } else {
    throw new Error("Table context is required to place an order");
  }

  const { data, error } = await client.functions.invoke("order_create", {
    body,
  });

  if (error) throw error;
  if (!data?.success || !data.order) {
    throw new Error("Order creation failed");
  }

  return mapOrderRow(
    data.order as JsonRecord & { items?: JsonRecord[] },
    payload.paymentMethod,
  );
}
