/* eslint-disable react-refresh/only-export-components */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import {
  clearStoredVenueSession,
  getSupabaseAuthClient,
  isVenueRefreshExpired,
  isVenueSessionExpired,
  persistVenueSession,
  readStoredVenueSession,
  resetSupabaseClient,
  type VenueSessionSnapshot,
} from "../lib/supabase";

interface WhatsAppOtpResponse {
  success?: boolean;
  error?: string;
  access_token?: string;
  refresh_token?: string;
  expires_at?: number;
  refresh_expires_at?: number;
  user?: {
    id?: string;
    phone?: string | null;
  } | null;
}

interface VenueAuthContextValue {
  session: VenueSessionSnapshot | null;
  isLoading: boolean;
  error: string | null;
  requestOtp: (phone: string) => Promise<boolean>;
  verifyOtp: (phone: string, otp: string) => Promise<boolean>;
  logout: () => Promise<void>;
}

const VenueAuthContext = createContext<VenueAuthContextValue | null>(null);

function normalizePhone(phone: string) {
  const trimmed = phone.replace(/[\s\-()]/g, "");
  return trimmed.startsWith("+") ? trimmed : `+${trimmed}`;
}

function sessionFromResponse(data: WhatsAppOtpResponse, phone: string): VenueSessionSnapshot {
  if (
    data.success !== true ||
    !data.access_token ||
    !data.refresh_token ||
    !data.user?.id ||
    !data.expires_at ||
    !data.refresh_expires_at
  ) {
    throw new Error(data.error || "Server did not return a valid venue session.");
  }

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    userId: data.user.id,
    expiresAt: data.expires_at,
    refreshExpiresAt: data.refresh_expires_at,
    phone: data.user.phone ?? phone,
  };
}

function authErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return fallback;
}

export function VenueAuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<VenueSessionSnapshot | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const applySession = useCallback((nextSession: VenueSessionSnapshot | null) => {
    if (nextSession) {
      persistVenueSession(nextSession);
    } else {
      clearStoredVenueSession();
    }
    resetSupabaseClient();
    setSession(nextSession);
    window.dispatchEvent(new Event("fanzone:venue-auth-change"));
  }, []);

  const refreshSession = useCallback(
    async (currentSession: VenueSessionSnapshot) => {
      if (isVenueRefreshExpired(currentSession)) {
        applySession(null);
        return null;
      }

      const { data, error: invokeError } =
        await getSupabaseAuthClient().functions.invoke<WhatsAppOtpResponse>(
          "whatsapp-otp",
          {
            body: {
              action: "refresh",
              refresh_token: currentSession.refreshToken,
            },
          },
        );

      if (invokeError) throw invokeError;

      const nextSession = sessionFromResponse(
        data ?? {},
        currentSession.phone,
      );
      applySession(nextSession);
      return nextSession;
    },
    [applySession],
  );

  useEffect(() => {
    let cancelled = false;

    async function loadStoredSession() {
      const stored = readStoredVenueSession();
      try {
        if (!stored) {
          if (!cancelled) applySession(null);
          return;
        }

        if (isVenueSessionExpired(stored, 45_000)) {
          const refreshed = await refreshSession(stored);
          if (!cancelled) setSession(refreshed);
          return;
        }

        if (!cancelled) {
          resetSupabaseClient();
          setSession(stored);
        }
      } catch (err) {
        if (!cancelled) {
          applySession(null);
          setError(authErrorMessage(err, "Venue session expired. Sign in again."));
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    void loadStoredSession();
    return () => {
      cancelled = true;
    };
  }, [applySession, refreshSession]);

  const requestOtp = useCallback(async (phone: string) => {
    setError(null);
    const normalized = normalizePhone(phone);
    try {
      const { data, error: invokeError } =
        await getSupabaseAuthClient().functions.invoke<WhatsAppOtpResponse>(
          "whatsapp-otp",
          {
            body: { action: "send", phone: normalized },
          },
        );

      if (invokeError) throw invokeError;
      if (data?.success !== true) {
        throw new Error(data?.error || "Could not send the WhatsApp OTP.");
      }

      return true;
    } catch (err) {
      setError(authErrorMessage(err, "Could not send the WhatsApp OTP."));
      return false;
    }
  }, []);

  const verifyOtp = useCallback(
    async (phone: string, otp: string) => {
      setError(null);
      const normalized = normalizePhone(phone);
      try {
        const { data, error: invokeError } =
          await getSupabaseAuthClient().functions.invoke<WhatsAppOtpResponse>(
            "whatsapp-otp",
            {
              body: { action: "verify", phone: normalized, otp },
            },
          );

        if (invokeError) throw invokeError;
        const nextSession = sessionFromResponse(data ?? {}, normalized);
        applySession(nextSession);
        return true;
      } catch (err) {
        setError(authErrorMessage(err, "WhatsApp OTP verification failed."));
        return false;
      }
    },
    [applySession],
  );

  const logout = useCallback(async () => {
    const currentSession = readStoredVenueSession();
    applySession(null);
    if (!currentSession?.refreshToken) return;

    try {
      await getSupabaseAuthClient().functions.invoke("whatsapp-otp", {
        body: {
          action: "logout",
          refresh_token: currentSession.refreshToken,
        },
      });
    } catch {
      // Local logout already completed.
    }
  }, [applySession]);

  const value = useMemo<VenueAuthContextValue>(
    () => ({
      session,
      isLoading,
      error,
      requestOtp,
      verifyOtp,
      logout,
    }),
    [error, isLoading, logout, requestOtp, session, verifyOtp],
  );

  return (
    <VenueAuthContext.Provider value={value}>
      {children}
    </VenueAuthContext.Provider>
  );
}

export function useVenueAuth() {
  const context = useContext(VenueAuthContext);
  if (!context) {
    throw new Error("useVenueAuth must be used within VenueAuthProvider");
  }
  return context;
}
