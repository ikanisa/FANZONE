import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@fanzone/core';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

export const tvEnvError =
  'TV display environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.';

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

type TvSupabaseClient = SupabaseClient<Database>;

let supabaseClient: TvSupabaseClient | null = null;

export function getSupabaseClient(): TvSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(tvEnvError);
  }

  supabaseClient ??= createClient<Database>(supabaseUrl, supabaseAnonKey, {
    realtime: {
      params: {
        eventsPerSecond: 8,
      },
    },
  });
  return supabaseClient;
}

export const supabase: TvSupabaseClient = new Proxy({} as TvSupabaseClient, {
  get(_target, property, receiver) {
    const client = getSupabaseClient();
    const value = Reflect.get(client, property, receiver);
    return typeof value === 'function' ? value.bind(client) : value;
  },
});
