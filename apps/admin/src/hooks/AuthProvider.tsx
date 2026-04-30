import { useCallback, useEffect, useState, type ReactNode } from "react";
import {
  FunctionsFetchError,
  FunctionsHttpError,
  FunctionsRelayError,
} from "@supabase/supabase-js";

import {
  clearStoredAdminSession,
  isAdminRefreshExpired,
  isAdminSessionExpired,
  isSupabaseConfigured,
  persistAdminSession,
  readStoredAdminSession,
  supabaseAuth,
  type AdminSessionSnapshot,
} from "../lib/supabase";
import { fetchAdminMe, fetchAdminMeWithAccessToken } from "../lib/adminData";
import type { AdminUser } from "../types";
import { AuthContext, UNCONFIGURED_ADMIN_ERROR } from "./auth-context";

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
  refresh_token?: string;
  expires_at?: number;
  refresh_expires_at?: number;
  user?: {
    id?: string;
    phone?: string | null;
  } | null;
}

const ADMIN_SESSION_REFRESH_LEAD_MS = 45_000;

function toAdminAuthErrorMessage(error: unknown, fallback: string) {
  if (!(error instanceof Error)) {
    return fallback;
  }

  const message = error.message.toLowerCase();
  if (message.includes("otp") || message.includes("token")) {
    return "The verification code is invalid or expired. Request a new WhatsApp code and try again.";
  }
  if (
    message.includes("signups not allowed") ||
    message.includes("user not found")
  ) {
    return "This WhatsApp number is not provisioned for FANZONE admin access.";
  }
  if (message.includes("rate limit")) {
    return "Too many code requests. Wait a moment and try again.";
  }
  if (message.includes("whatsapp api not configured")) {
    return "WhatsApp OTP delivery is not configured for this environment.";
  }
  if (message.includes("failed to create session")) {
    return "Authentication succeeded, but the admin session could not be created. Check auth configuration and try again.";
  }
  if (message.includes("jwt signing secret is not configured")) {
    return "WhatsApp auth is missing its JWT signing secret in this environment.";
  }

  return error.message || fallback;
}

async function getFunctionErrorMessage(error: unknown, fallback: string) {
  if (error instanceof FunctionsHttpError) {
    try {
      const payload = (await error.context.json()) as { error?: string };
      if (typeof payload?.error === "string" && payload.error.trim()) {
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
  const [isLoading, setIsLoading] = useState<boolean>(
    initialSnapshot.isLoading,
  );
  const [error, setError] = useState<string | null>(initialSnapshot.error);

  const fetchAdminProfile = useCallback(
    async (accessToken?: string): Promise<AdminProfileResult> => {
      try {
        const admin = accessToken
          ? await fetchAdminMeWithAccessToken(accessToken)
          : await fetchAdminMe();
        if (!admin) {
          return {
            admin: null,
            error: "Access denied. You are not an admin.",
          };
        }

        return {
          admin: admin as AdminUser,
          error: null,
        };
      } catch {
        return {
          admin: null,
          error: "Failed to verify admin access.",
        };
      }
    },
    [],
  );

  const clearAuthState = useCallback((nextError: string | null = null) => {
    clearStoredAdminSession();
    setSession(null);
    setAdmin(null);
    setError(nextError);
  }, []);

  const buildSessionSnapshot = useCallback(
    (data: WhatsAppOtpVerifyResponse, phone: string): AdminSessionSnapshot => {
      if (
        !data.access_token ||
        !data.refresh_token ||
        !data.user?.id ||
        !data.expires_at ||
        !data.refresh_expires_at
      ) {
        throw new Error("Server did not return a valid session.");
      }

      return {
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        userId: data.user.id,
        expiresAt: data.expires_at,
        refreshExpiresAt: data.refresh_expires_at,
        phone: data.user.phone ?? phone,
      };
    },
    [],
  );

  const refreshSession = useCallback(
    async (
      currentSession: AdminSessionSnapshot,
    ): Promise<AdminSessionSnapshot | null> => {
      try {
        const { data, error: invokeError } =
          await supabaseAuth.functions.invoke<WhatsAppOtpVerifyResponse>(
            "whatsapp-otp",
            {
              body: {
                action: "refresh",
                refresh_token: currentSession.refreshToken,
              },
            },
          );

        if (invokeError) {
          throw new Error(
            await getFunctionErrorMessage(
              invokeError,
              "Unable to refresh the admin session.",
            ),
          );
        }

        if (data?.success !== true) {
          throw new Error(
            data?.error || "Unable to refresh the admin session.",
          );
        }

        const nextSession = buildSessionSnapshot(
          data,
          data.user?.phone ?? currentSession.phone ?? "",
        );
        const profile = await fetchAdminProfile(nextSession.accessToken);
        if (!profile.admin) {
          clearAuthState(
            profile.error ?? "Access denied. You are not an admin.",
          );
          return null;
        }

        persistAdminSession(nextSession);
        setSession(nextSession);
        setAdmin(profile.admin);
        setError(null);
        return nextSession;
      } catch (authError: unknown) {
        clearAuthState(
          toAdminAuthErrorMessage(
            authError,
            "Your admin session expired. Request a new WhatsApp code to continue.",
          ),
        );
        return null;
      }
    },
    [buildSessionSnapshot, clearAuthState, fetchAdminProfile],
  );

  useEffect(() => {
    if (!isSupabaseConfigured) {
      return;
    }

    let isActive = true;

    const restore = async () => {
      const storedSession = readStoredAdminSession();
      if (!storedSession || isAdminRefreshExpired(storedSession)) {
        if (!isActive) return;
        clearAuthState(
          storedSession
            ? "Your admin session expired. Request a new WhatsApp code to continue."
            : null,
        );
        setIsLoading(false);
        return;
      }

      let activeSession = storedSession;
      const refreshDeadlineMs =
        storedSession.expiresAt * 1000 -
        Date.now() -
        ADMIN_SESSION_REFRESH_LEAD_MS;
      if (isAdminSessionExpired(storedSession) || refreshDeadlineMs <= 0) {
        const refreshed = await refreshSession(storedSession);
        if (!isActive) return;
        if (!refreshed) {
          setIsLoading(false);
          return;
        }
        activeSession = refreshed;
      }

      if (!isActive) return;
      setIsLoading(true);

      const profile = await fetchAdminProfile(activeSession.accessToken);
      if (!isActive) return;

      if (!profile.admin) {
        clearAuthState(profile.error ?? "Access denied. You are not an admin.");
        setIsLoading(false);
        return;
      }

      setSession(activeSession);
      setAdmin(profile.admin);
      setError(null);
      setIsLoading(false);
    };

    void restore();

    return () => {
      isActive = false;
    };
  }, [clearAuthState, fetchAdminProfile, refreshSession]);

  useEffect(() => {
    if (!session) {
      return;
    }

    const refreshInMs =
      session.expiresAt * 1000 - Date.now() - ADMIN_SESSION_REFRESH_LEAD_MS;
    const timeoutMs = Math.min(Math.max(refreshInMs, 0), 2_147_483_647);

    const timeout = window.setTimeout(() => {
      void refreshSession(session);
    }, timeoutMs);

    return () => {
      window.clearTimeout(timeout);
    };
  }, [refreshSession, session]);

  const requestOtp = useCallback(async (phone: string) => {
    if (!isSupabaseConfigured) {
      setError(UNCONFIGURED_ADMIN_ERROR);
      return false;
    }

    setIsLoading(true);
    setError(null);

    try {
      const { data, error: invokeError } =
        await supabaseAuth.functions.invoke<WhatsAppOtpSendResponse>(
          "whatsapp-otp",
          {
            body: {
              action: "send",
              phone,
            },
          },
        );

      if (invokeError) {
        throw new Error(
          await getFunctionErrorMessage(
            invokeError,
            "Unable to send a WhatsApp verification code.",
          ),
        );
      }

      if (data?.success !== true) {
        throw new Error(
          data?.error || "Unable to send a WhatsApp verification code.",
        );
      }
    } catch (authError: unknown) {
      setError(
        toAdminAuthErrorMessage(
          authError,
          "Unable to send a WhatsApp verification code.",
        ),
      );
      setIsLoading(false);
      return false;
    }

    setIsLoading(false);
    return true;
  }, []);

  const verifyOtp = useCallback(
    async (phone: string, otp: string) => {
      if (!isSupabaseConfigured) {
        setError(UNCONFIGURED_ADMIN_ERROR);
        return false;
      }

      setIsLoading(true);
      setError(null);

      try {
        const { data, error: invokeError } =
          await supabaseAuth.functions.invoke<WhatsAppOtpVerifyResponse>(
            "whatsapp-otp",
            {
              body: {
                action: "verify",
                phone,
                otp,
              },
            },
          );

        if (invokeError) {
          throw new Error(
            await getFunctionErrorMessage(
              invokeError,
              "Unable to verify the WhatsApp code.",
            ),
          );
        }

        if (data?.success !== true) {
          throw new Error(data?.error || "Unable to verify the WhatsApp code.");
        }

        const nextSession = buildSessionSnapshot(data, phone);
        const profile = await fetchAdminProfile(nextSession.accessToken);
        if (!profile.admin) {
          clearAuthState(
            profile.error ?? "Access denied. You are not an admin.",
          );
          setIsLoading(false);
          return false;
        }

        persistAdminSession(nextSession);
        setSession(nextSession);
        setAdmin(profile.admin);
        setError(null);
        setIsLoading(false);
        return true;
      } catch (authError: unknown) {
        clearAuthState(
          toAdminAuthErrorMessage(
            authError,
            "Unable to verify the WhatsApp code.",
          ),
        );
        setIsLoading(false);
        return false;
      }
    },
    [buildSessionSnapshot, clearAuthState, fetchAdminProfile],
  );

  const signOut = useCallback(async () => {
    if (session?.refreshToken) {
      try {
        await supabaseAuth.functions.invoke("whatsapp-otp", {
          body: {
            action: "logout",
            refresh_token: session.refreshToken,
          },
        });
      } catch {
        // Clear local state even if the revoke request fails.
      }
    }

    clearAuthState();
  }, [clearAuthState, session]);

  return (
    <AuthContext.Provider
      value={{
        session,
        admin,
        isLoading,
        error,
        requestOtp,
        verifyOtp,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
