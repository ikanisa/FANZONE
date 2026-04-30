export const env = {
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL as string || '',
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY as string || '',
  mode: import.meta.env.MODE,
  appName: 'FANZONE Admin',
  version: '1.0.0',
} as const;

if (!env.supabaseUrl || !env.supabaseAnonKey) {
  console.warn(
    `[FANZONE Admin] Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. Admin auth and data access remain locked in ${env.mode}.`
  );
}
