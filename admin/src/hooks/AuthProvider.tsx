import { useCallback, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';

import { supabase, isDemoMode, isSupabaseConfigured } from '../lib/supabase';
import type { AdminUser } from '../types';
import { AuthContext, DEMO_ADMIN, UNCONFIGURED_ADMIN_ERROR } from './auth-context';

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

function getInitialAuthSnapshot(): InitialAuthSnapshot {
  if (isDemoMode) {
    return {
      session: null,
      admin: DEMO_ADMIN,
      isLoading: false,
      error: null,
    };
  }

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
    if (isDemoMode) {
      return { admin: DEMO_ADMIN, error: null };
    }

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
    if (!isSupabaseConfigured || isDemoMode) {
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

  const signIn = useCallback(async (email: string, password: string) => {
    if (isDemoMode) {
      setAdmin(DEMO_ADMIN);
      setError(null);
      return;
    }

    if (!isSupabaseConfigured) {
      setError(UNCONFIGURED_ADMIN_ERROR);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const { error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (authError) throw authError;
    } catch (authError: unknown) {
      setError(authError instanceof Error ? authError.message : 'Sign in failed.');
      setIsLoading(false);
    }
  }, []);

  const signOut = useCallback(async () => {
    if (isDemoMode) {
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
      value={{ session, admin, isLoading, error, signIn, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}
