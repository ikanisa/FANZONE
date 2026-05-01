import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@fanzone/core";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "";
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

export const venueEnvError =
  "Venue environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable venue operations.";

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

type VenueSupabaseClient = SupabaseClient<Database>;

let supabaseClient: VenueSupabaseClient | null = null;

export function getSupabaseClient(): VenueSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(venueEnvError);
  }

  supabaseClient ??= createClient<Database>(supabaseUrl, supabaseAnonKey);
  return supabaseClient;
}

export const supabase: VenueSupabaseClient = new Proxy(
  {} as VenueSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === "function" ? value.bind(client) : value;
    },
  },
);
