import { useCallback, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';

import { supabase, isSupabaseConfigured } from '../lib/supabase';
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
  session: Session | null;
  admin: AdminUser | null;
  isLoading: boolean;
  error: string | null;
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

  return error.message || fallback;
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
  const [session, setSession] = useState<Session | null>(
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

    const applySession = async (nextSession: Session | null) => {
      if (!isActive) return;

      setSession(nextSession);

      if (!nextSession?.user?.id) {
        setAdmin(null);
        setError(null);
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      const profile = await fetchAdminProfile(nextSession.user.id);

      if (!isActive) return;

      setAdmin(profile.admin);
      setError(profile.error);
      setIsLoading(false);
    };

    void supabase.auth
      .getSession()
      .then(({ data: { session: currentSession } }) => applySession(currentSession));

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      void applySession(nextSession);
    });

    return () => {
      isActive = false;
      subscription.unsubscribe();
    };
  }, [fetchAdminProfile]);

  const requestOtp = useCallback(async (phone: string) => {
    if (!isSupabaseConfigured) {
      setError(UNCONFIGURED_ADMIN_ERROR);
      return false;
    }

    setIsLoading(true);
    setError(null);

    try {
      const { error: authError } = await supabase.auth.signInWithOtp({
        phone,
        options: {
          channel: 'whatsapp',
          shouldCreateUser: false,
        },
      });

      if (authError) throw authError;
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
      const { error: authError } = await supabase.auth.verifyOtp({
        phone,
        token: otp,
        // Supabase expects the shared phone verifier type `sms` here even
        // when the OTP was delivered through the WhatsApp channel.
        type: 'sms',
      });

      if (authError) throw authError;
    } catch (authError: unknown) {
      setError(
        toAdminAuthErrorMessage(
          authError,
          'Unable to verify the WhatsApp code.',
        ),
      );
      setIsLoading(false);
      return false;
    }

    return true;
  }, []);

  const signOut = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setSession(null);
      setAdmin(null);
      setError(null);
      return;
    }

    await supabase.auth.signOut();
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
