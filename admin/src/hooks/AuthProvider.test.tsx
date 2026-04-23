// @vitest-environment jsdom
import { act, render, waitFor } from "@testing-library/react";
import { useContext, useEffect } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AuthContext, type AuthState } from "./auth-context";
import { AuthProvider } from "./AuthProvider";

const {
  invokeMock,
  fetchAdminMeMock,
  fetchAdminMeWithAccessTokenMock,
  readStoredAdminSessionMock,
  persistAdminSessionMock,
  clearStoredAdminSessionMock,
  isAdminSessionExpiredMock,
  isAdminRefreshExpiredMock,
} = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  fetchAdminMeMock: vi.fn(),
  fetchAdminMeWithAccessTokenMock: vi.fn(),
  readStoredAdminSessionMock: vi.fn(),
  persistAdminSessionMock: vi.fn(),
  clearStoredAdminSessionMock: vi.fn(),
  isAdminSessionExpiredMock: vi.fn(),
  isAdminRefreshExpiredMock: vi.fn(),
}));

vi.mock("../lib/supabase", () => ({
  isSupabaseConfigured: true,
  supabaseAuth: {
    functions: {
      invoke: invokeMock,
    },
  },
  readStoredAdminSession: readStoredAdminSessionMock,
  persistAdminSession: persistAdminSessionMock,
  clearStoredAdminSession: clearStoredAdminSessionMock,
  isAdminSessionExpired: isAdminSessionExpiredMock,
  isAdminRefreshExpired: isAdminRefreshExpiredMock,
}));

vi.mock("../lib/adminData", () => ({
  fetchAdminMe: fetchAdminMeMock,
  fetchAdminMeWithAccessToken: fetchAdminMeWithAccessTokenMock,
}));

let latestAuthState: AuthState | null = null;

function Probe() {
  const authState = useContext(AuthContext);

  useEffect(() => {
    latestAuthState = authState;
  }, [authState]);

  return null;
}

describe("AuthProvider", () => {
  beforeEach(() => {
    latestAuthState = null;

    readStoredAdminSessionMock.mockReturnValue(null);
    isAdminSessionExpiredMock.mockImplementation((session) => !session);
    isAdminRefreshExpiredMock.mockImplementation((session) => !session);

    fetchAdminMeMock.mockResolvedValue({
      id: "admin-row-1",
      user_id: "user-1",
      phone: "+11199123456",
      display_name: "Admin",
      role: "admin",
      is_active: true,
    });
    fetchAdminMeWithAccessTokenMock.mockResolvedValue({
      id: "admin-row-1",
      user_id: "user-1",
      phone: "+11199123456",
      display_name: "Admin",
      role: "admin",
      is_active: true,
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("sends WhatsApp OTP through the shared edge function", async () => {
    invokeMock.mockResolvedValue({
      data: { success: true, message: "OTP sent via WhatsApp" },
      error: null,
    });

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );

    await waitFor(() => {
      expect(latestAuthState?.isLoading).toBe(false);
    });

    let result = false;
    await act(async () => {
      result = await latestAuthState!.requestOtp("+11199123456");
    });

    expect(result).toBe(true);
    expect(invokeMock).toHaveBeenCalledWith("whatsapp-otp", {
      body: {
        action: "send",
        phone: "+11199123456",
      },
    });
  });

  it("verifies the WhatsApp OTP and persists the custom bearer session", async () => {
    invokeMock.mockResolvedValue({
      data: {
        success: true,
        access_token: "access-token",
        refresh_token: "refresh-token",
        expires_at: 1_800_000_000,
        refresh_expires_at: 1_900_000_000,
        user: {
          id: "user-1",
          phone: "+11199123456",
        },
      },
      error: null,
    });

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );

    await waitFor(() => {
      expect(latestAuthState?.isLoading).toBe(false);
    });

    let result = false;
    await act(async () => {
      result = await latestAuthState!.verifyOtp("+11199123456", "123456");
    });

    expect(result).toBe(true);
    expect(persistAdminSessionMock).toHaveBeenCalledWith({
      accessToken: "access-token",
      refreshToken: "refresh-token",
      userId: "user-1",
      expiresAt: 1_800_000_000,
      refreshExpiresAt: 1_900_000_000,
      phone: "+11199123456",
    });
    expect(fetchAdminMeWithAccessTokenMock).toHaveBeenCalledWith(
      "access-token",
    );

    await waitFor(() => {
      expect(latestAuthState?.admin?.user_id).toBe("user-1");
      expect(latestAuthState?.session?.accessToken).toBe("access-token");
    });
  });

  it("rejects non-admin OTP verification without persisting the session", async () => {
    invokeMock.mockResolvedValue({
      data: {
        success: true,
        access_token: "access-token",
        refresh_token: "refresh-token",
        expires_at: 1_800_000_000,
        refresh_expires_at: 1_900_000_000,
        user: {
          id: "user-2",
          phone: "+11199123456",
        },
      },
      error: null,
    });
    fetchAdminMeWithAccessTokenMock.mockResolvedValue(null);

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );

    await waitFor(() => {
      expect(latestAuthState?.isLoading).toBe(false);
    });

    let result = false;
    await act(async () => {
      result = await latestAuthState!.verifyOtp("+11199123456", "123456");
    });

    expect(result).toBe(false);
    expect(persistAdminSessionMock).not.toHaveBeenCalled();
    expect(clearStoredAdminSessionMock).toHaveBeenCalled();

    await waitFor(() => {
      expect(latestAuthState?.session).toBeNull();
      expect(latestAuthState?.admin).toBeNull();
      expect(latestAuthState?.error).toBe(
        "Access denied. You are not an admin.",
      );
    });
  });
});
