import { useCallback, useEffect, useState, type ReactNode } from 'react';
import {
  FunctionsFetchError,
  FunctionsHttpError,
  FunctionsRelayError,
} from '@supabase/supabase-js';

import {
  clearStoredAdminSession,
  isAdminSessionExpired,
  isSupabaseConfigured,
  persistAdminSession,
  readStoredAdminSession,
  supabase,
  supabaseAuth,
  type AdminSessionSnapshot,
} from '../lib/supabase';
import type { AdminUser } from '../types';
import { AuthContext, UNCONFIGURED_ADMIN_ERROR } from './auth-context';

interface AuthProviderProps {
  children: ReactNode;
}

interface AdminProfileResult {
  admin: AdminUser | null;
  error: string | null;
}

interface InitialAuthSnapshot {
  session: AdminSessionSnapshot | null;
  admin: AdminUser | null;
  isLoading: boolean;
  error: string | null;
}

interface WhatsAppOtpSendResponse {
  success?: boolean;
  message?: string;
  error?: string;
}

interface WhatsAppOtpVerifyResponse extends WhatsAppOtpSendResponse {
  access_token?: string;
  expires_at?: number;
  user?: {
    id?: string;
    phone?: string | null;
  } | null;
}

function toAdminAuthErrorMessage(error: unknown, fallback: string) {
  if (!(error instanceof Error)) {
    return fallback;
  }

  const message = error.message.toLowerCase();
  if (message.includes('otp') || message.includes('token')) {
    return 'The verification code is invalid or expired. Request a new WhatsApp code and try again.';
  }
  if (message.includes('signups not allowed') || message.includes('user not found')) {
    return 'This WhatsApp number is not provisioned for FANZONE admin access.';
  }
  if (message.includes('rate limit')) {
    return 'Too many code requests. Wait a moment and try again.';
  }
  if (message.includes('whatsapp api not configured')) {
    return 'WhatsApp OTP delivery is not configured for this environment.';
  }
  if (message.includes('failed to create session')) {
    return 'Authentication succeeded, but the admin session could not be created. Check auth configuration and try again.';
  }
  if (message.includes('jwt signing secret is not configured')) {
    return 'WhatsApp auth is missing its JWT signing secret in this environment.';
  }

  return error.message || fallback;
}

async function getFunctionErrorMessage(error: unknown, fallback: string) {
  if (error instanceof FunctionsHttpError) {
    try {
      const payload = await error.context.json() as { error?: string };
      if (typeof payload?.error === 'string' && payload.error.trim()) {
        return payload.error;
      }
    } catch {
      // Fall through to the generic error message.
    }
  }

  if (
    error instanceof FunctionsHttpError ||
    error instanceof FunctionsRelayError ||
    error instanceof FunctionsFetchError
  ) {
    return error.message || fallback;
  }

  if (error instanceof Error) {
    return error.message || fallback;
  }

  return fallback;
}

function getInitialAuthSnapshot(): InitialAuthSnapshot {
  if (!isSupabaseConfigured) {
    return {
      session: null,
      admin: null,
      isLoading: false,
      error: UNCONFIGURED_ADMIN_ERROR,
    };
  }

  return {
    session: null,
    admin: null,
    isLoading: true,
    error: null,
  };
}

export function AuthProvider({ children }: AuthProviderProps) {
  const initialSnapshot = getInitialAuthSnapshot();
  const [session, setSession] = useState<AdminSessionSnapshot | null>(
    initialSnapshot.session,
  );
  const [admin, setAdmin] = useState<AdminUser | null>(initialSnapshot.admin);
  const [isLoading, setIsLoading] = useState<boolean>(initialSnapshot.isLoading);
  const [error, setError] = useState<string | null>(initialSnapshot.error);

  const fetchAdminProfile = useCallback(async (userId: string): Promise<AdminProfileResult> => {
    try {
      const { data, error: fetchError } = await supabase
        .from('admin_users')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .single();

      if (fetchError || !data) {
        return {
          admin: null,
          error: 'Access denied. You are not an admin.',
        };
      }

      return {
        admin: data as AdminUser,
        error: null,
      };
    } catch {
      return {
        admin: null,
        error: 'Failed to verify admin access.',
      };
    }
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      return;
    }

    let isActive = true;

    const restore = async () => {
      const storedSession = readStoredAdminSession();
      if (!storedSession || isAdminSessionExpired(storedSession)) {
        clearStoredAdminSession();
        if (!isActive) return;
        setSession(null);
        setAdmin(null);
        setError(
          storedSession
            ? 'Your admin session expired. Request a new WhatsApp code to continue.'
            : null,
        );
        setIsLoading(false);
        return;
      }

      if (!isActive) return;
      setSession(storedSession);
      setIsLoading(true);

      const profile = await fetchAdminProfile(storedSession.userId);
      if (!isActive) return;

      setAdmin(profile.admin);
      setError(profile.error);
      setIsLoading(false);
    };

    void restore();

    return () => {
      isActive = false;
    };
  }, [fetchAdminProfile]);

  useEffect(() => {
    if (!session) {
      return;
    }

    const expiresInMs = Math.max(0, session.expiresAt * 1000 - Date.now());
    const timeoutMs = Math.min(expiresInMs + 1_000, 2_147_483_647);

    const timeout = window.setTimeout(() => {
      clearStoredAdminSession();
      setSession(null);
      setAdmin(null);
      setError('Your admin session expired. Request a new WhatsApp code to continue.');
    }, timeoutMs);

    return () => {
      window.clearTimeout(timeout);
    };
  }, [session]);

  const requestOtp = useCallback(async (phone: string) => {
    if (!isSupabaseConfigured) {
      setError(UNCONFIGURED_ADMIN_ERROR);
      return false;
    }

    setIsLoading(true);
    setError(null);

    try {
      const { data, error: invokeError } = await supabaseAuth.functions.invoke<WhatsAppOtpSendResponse>(
        'whatsapp-otp',
        {
          body: {
            action: 'send',
            phone,
          },
        },
      );

      if (invokeError) {
        throw new Error(
          await getFunctionErrorMessage(
            invokeError,
            'Unable to send a WhatsApp verification code.',
          ),
        );
      }

      if (data?.success !== true) {
        throw new Error(
          data?.error || 'Unable to send a WhatsApp verification code.',
        );
      }
    } catch (authError: unknown) {
      setError(
        toAdminAuthErrorMessage(
          authError,
          'Unable to send a WhatsApp verification code.',
        ),
      );
      setIsLoading(false);
      return false;
    }

    setIsLoading(false);
    return true;
  }, []);

  const verifyOtp = useCallback(async (phone: string, otp: string) => {
    if (!isSupabaseConfigured) {
      setError(UNCONFIGURED_ADMIN_ERROR);
      return false;
    }

    setIsLoading(true);
    setError(null);

    try {
      const { data, error: invokeError } = await supabaseAuth.functions.invoke<WhatsAppOtpVerifyResponse>(
        'whatsapp-otp',
        {
          body: {
            action: 'verify',
            phone,
            otp,
          },
        },
      );

      if (invokeError) {
        throw new Error(
          await getFunctionErrorMessage(
            invokeError,
            'Unable to verify the WhatsApp code.',
          ),
        );
      }

      if (data?.success !== true) {
        throw new Error(data?.error || 'Unable to verify the WhatsApp code.');
      }

      if (!data.access_token || !data.user?.id || !data.expires_at) {
        throw new Error('Server did not return a valid session.');
      }

      const nextSession: AdminSessionSnapshot = {
        accessToken: data.access_token,
        userId: data.user.id,
        expiresAt: data.expires_at,
        phone: data.user.phone ?? phone,
      };

      persistAdminSession(nextSession);
      setSession(nextSession);

      const profile = await fetchAdminProfile(nextSession.userId);
      setAdmin(profile.admin);
      setError(profile.error);
      setIsLoading(false);
      return profile.admin != null;
    } catch (authError: unknown) {
      clearStoredAdminSession();
      setSession(null);
      setAdmin(null);
      setError(
        toAdminAuthErrorMessage(
          authError,
          'Unable to verify the WhatsApp code.',
        ),
      );
      setIsLoading(false);
      return false;
    }
  }, [fetchAdminProfile]);

  const signOut = useCallback(async () => {
    clearStoredAdminSession();
    setSession(null);
    setAdmin(null);
    setError(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{ session, admin, isLoading, error, requestOtp, verifyOtp, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}
