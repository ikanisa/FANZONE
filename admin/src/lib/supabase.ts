// FANZONE Admin — Supabase Client
import { createClient } from '@supabase/supabase-js';
import { env } from '../config/env';

export const adminEnvError =
  'Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.';

export const supabase = createClient(
  env.supabaseUrl || 'https://placeholder.supabase.co',
  env.supabaseAnonKey || 'placeholder',
  {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      storage: globalThis.localStorage,
    },
  }
);

export const isSupabaseConfigured = Boolean(env.supabaseUrl && env.supabaseAnonKey);
export const isDemoMode = !isSupabaseConfigured && env.allowDemoMode;
