import { createContext } from 'react';
import type { Session } from '@supabase/supabase-js';

import type { AdminUser } from '../types';

export interface AuthState {
  session: Session | null;
  admin: AdminUser | null;
  isLoading: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export const UNCONFIGURED_ADMIN_ERROR =
  'Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.';

export const DEMO_ADMIN: AdminUser = {
  id: 'demo-admin-001',
  user_id: 'demo-user-001',
  email: 'admin@fanzone.mt',
  display_name: 'Demo Admin',
  role: 'super_admin',
  permissions: {},
  is_active: true,
  invited_by: null,
  last_login_at: '2026-01-01T00:00:00.000Z',
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
};

export const AuthContext = createContext<AuthState | null>(null);
