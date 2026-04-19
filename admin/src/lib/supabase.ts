// FANZONE Admin — Supabase Client
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from '../config/env';

export const adminEnvError =
  'Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable WhatsApp OTP sign-in.';

type AdminSupabaseClient = SupabaseClient;

export const isSupabaseConfigured = Boolean(env.supabaseUrl && env.supabaseAnonKey);

let supabaseClient: AdminSupabaseClient | null = null;

function createSupabaseBrowserClient(): AdminSupabaseClient {
  return createClient(
    env.supabaseUrl,
    env.supabaseAnonKey,
    {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        storage: typeof window === 'undefined' ? undefined : window.localStorage,
      },
    },
  );
}

export function getSupabaseClient(): AdminSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(adminEnvError);
  }

  supabaseClient ??= createSupabaseBrowserClient();
  return supabaseClient;
}

export const supabase: AdminSupabaseClient = new Proxy(
  {} as AdminSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === 'function' ? value.bind(client) : value;
    },
  },
);
