import { createContext } from 'react';

import type { AdminSessionSnapshot } from '../lib/supabase';
import type { AdminUser } from '../types';

export interface AuthState {
  session: AdminSessionSnapshot | null;
  admin: AdminUser | null;
  isLoading: boolean;
  error: string | null;
  requestOtp: (phone: string) => Promise<boolean>;
  verifyOtp: (phone: string, otp: string) => Promise<boolean>;
  signOut: () => Promise<void>;
}

export const UNCONFIGURED_ADMIN_ERROR =
  'Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable WhatsApp OTP sign-in.';

export const AuthContext = createContext<AuthState | null>(null);
