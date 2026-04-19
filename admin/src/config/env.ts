// FANZONE Admin — Environment Configuration
const isLocalDev = import.meta.env.DEV;

export const env = {
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL as string || '',
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY as string || '',
  allowDemoMode: isLocalDev && import.meta.env.VITE_ALLOW_DEMO_MODE === 'true',
  mode: import.meta.env.MODE,
  appName: 'FANZONE Admin',
  version: '1.0.0',
} as const;

if (!env.supabaseUrl || !env.supabaseAnonKey) {
  console.warn(
    env.allowDemoMode
      ? '[FANZONE Admin] Missing Supabase env. Demo mode is enabled explicitly.'
      : `[FANZONE Admin] Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. Admin auth will remain locked in ${env.mode}.`
  );
}
