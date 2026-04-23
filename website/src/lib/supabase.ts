import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim() ?? '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? '';

export const isSupabaseConfigured =
  supabaseUrl.length > 0 && supabaseAnonKey.length > 0;

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
      },
      global: {
        headers: {
          'x-client-info': 'fanzone-website',
          'x-fanzone-channel': 'web',
        },
      },
    })
  : null;

let viewerSessionPromise: Promise<string | null> | null = null;

export async function ensureWebsiteSession(): Promise<string | null> {
  if (!supabase) return null;
  if (viewerSessionPromise) return viewerSessionPromise;

  viewerSessionPromise = (async () => {
    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession();

    if (sessionError) {
      console.warn('Failed to resolve Supabase session', sessionError);
    }

    if (session?.user?.id) {
      return session.user.id;
    }

    const { data, error } = await supabase.auth.signInAnonymously();
    if (error) {
      console.warn('Anonymous sign-in failed', error);
      return null;
    }

    return data.user?.id ?? null;
  })();

  try {
    return await viewerSessionPromise;
  } finally {
    viewerSessionPromise = null;
  }
}
