import type { Json, MenuCategoryRow, MenuItemRow } from "@fanzone/core";
import { supabase } from "../lib/supabase";

export interface VenueMenuRows {
  categories: MenuCategoryRow[];
  items: MenuItemRow[];
}

export interface VenueMenuCategoryCreateInput {
  venueId: string;
  name: string;
  displayOrder: number;
  isVisible?: boolean;
}

export interface VenueMenuItemCreateInput {
  venueId: string;
  categoryId: string;
  name: string;
  description?: string | null;
  price: number;
  currencyCode: string;
  imageUrl?: string | null;
  fetEarnPercentOverride?: number | null;
  isAvailable?: boolean;
  displayOrder: number;
  metadata?: Json | null;
}

export interface VenueMenuItemUpdateInput {
  itemId: string;
  name: string;
  description?: string | null;
  price: number;
  imageUrl?: string | null;
  fetEarnPercentOverride?: number | null;
}

function menuItemInsertPayload(input: VenueMenuItemCreateInput) {
  return {
    venue_id: input.venueId,
    category_id: input.categoryId,
    name: input.name,
    description: input.description ?? null,
    price: input.price,
    currency_code: input.currencyCode,
    image_url: input.imageUrl ?? null,
    fet_earn_percent_override: input.fetEarnPercentOverride ?? null,
    is_available: input.isAvailable ?? true,
    display_order: input.displayOrder,
    metadata: input.metadata ?? null,
  };
}

export async function fetchVenueMenuRows(
  venueId: string,
): Promise<VenueMenuRows> {
  const [categoryResult, itemResult] = await Promise.all([
    supabase
      .from("menu_categories")
      .select("*")
      .eq("venue_id", venueId)
      .order("display_order", { ascending: true }),
    supabase
      .from("menu_items")
      .select("*")
      .eq("venue_id", venueId)
      .order("display_order", { ascending: true }),
  ]);

  if (categoryResult.error) throw categoryResult.error;
  if (itemResult.error) throw itemResult.error;

  return {
    categories: (categoryResult.data ?? []) as MenuCategoryRow[],
    items: (itemResult.data ?? []) as MenuItemRow[],
  };
}

export async function createVenueMenuCategory(
  input: VenueMenuCategoryCreateInput,
): Promise<MenuCategoryRow> {
  const { data, error } = await supabase
    .from("menu_categories")
    .insert({
      venue_id: input.venueId,
      name: input.name,
      display_order: input.displayOrder,
      is_visible: input.isVisible ?? true,
    })
    .select()
    .single();

  if (error) throw error;
  return data as MenuCategoryRow;
}

export async function updateVenueMenuCategoryOrder(
  categoryId: string,
  displayOrder: number,
): Promise<void> {
  const { error } = await supabase
    .from("menu_categories")
    .update({ display_order: displayOrder })
    .eq("id", categoryId);

  if (error) throw error;
}

export async function setVenueMenuCategoryVisibility(
  categoryId: string,
  isVisible: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("menu_categories")
    .update({ is_visible: isVisible })
    .eq("id", categoryId);

  if (error) throw error;
}

export async function createVenueMenuItem(
  input: VenueMenuItemCreateInput,
): Promise<MenuItemRow> {
  const { data, error } = await supabase
    .from("menu_items")
    .insert(menuItemInsertPayload(input))
    .select()
    .single();

  if (error) throw error;
  return data as MenuItemRow;
}

export async function createVenueMenuItems(
  items: VenueMenuItemCreateInput[],
): Promise<void> {
  if (items.length === 0) return;

  const { error } = await supabase
    .from("menu_items")
    .insert(items.map(menuItemInsertPayload));

  if (error) throw error;
}

export async function updateVenueMenuItem(
  input: VenueMenuItemUpdateInput,
): Promise<void> {
  const { error } = await supabase
    .from("menu_items")
    .update({
      name: input.name,
      price: input.price,
      description: input.description ?? null,
      image_url: input.imageUrl ?? null,
      fet_earn_percent_override: input.fetEarnPercentOverride ?? null,
    })
    .eq("id", input.itemId);

  if (error) throw error;
}

export async function setVenueMenuItemAvailability(
  itemId: string,
  isAvailable: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("menu_items")
    .update({ is_available: isAvailable })
    .eq("id", itemId);

  if (error) throw error;
}

export async function deleteVenueMenuItem(itemId: string): Promise<void> {
  const { error } = await supabase.from("menu_items").delete().eq("id", itemId);

  if (error) throw error;
}
