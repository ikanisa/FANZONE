// @vitest-environment jsdom
import { act, render, waitFor } from '@testing-library/react';
import { useContext, useEffect } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthContext, type AuthState } from './auth-context';
import { AuthProvider } from './AuthProvider';

const {
  invokeMock,
  fromMock,
  readStoredAdminSessionMock,
  persistAdminSessionMock,
  clearStoredAdminSessionMock,
  isAdminSessionExpiredMock,
} = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  fromMock: vi.fn(),
  readStoredAdminSessionMock: vi.fn(),
  persistAdminSessionMock: vi.fn(),
  clearStoredAdminSessionMock: vi.fn(),
  isAdminSessionExpiredMock: vi.fn(),
}));

vi.mock('../lib/supabase', () => ({
  isSupabaseConfigured: true,
  supabase: {
    from: fromMock,
  },
  supabaseAuth: {
    functions: {
      invoke: invokeMock,
    },
  },
  readStoredAdminSession: readStoredAdminSessionMock,
  persistAdminSession: persistAdminSessionMock,
  clearStoredAdminSession: clearStoredAdminSessionMock,
  isAdminSessionExpired: isAdminSessionExpiredMock,
}));

let latestAuthState: AuthState | null = null;

function Probe() {
  const authState = useContext(AuthContext);

  useEffect(() => {
    latestAuthState = authState;
  }, [authState]);

  return null;
}

describe('AuthProvider', () => {
  beforeEach(() => {
    latestAuthState = null;

    readStoredAdminSessionMock.mockReturnValue(null);
    isAdminSessionExpiredMock.mockImplementation((session) => !session);

    fromMock.mockImplementation(() => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            single: async () => ({
              data: {
                id: 'admin-row-1',
                user_id: 'user-1',
                phone: '+35699123456',
                display_name: 'Admin',
                role: 'admin',
                is_active: true,
              },
              error: null,
            }),
          }),
        }),
      }),
    }));
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('sends WhatsApp OTP through the shared edge function', async () => {
    invokeMock.mockResolvedValue({
      data: { success: true, message: 'OTP sent via WhatsApp' },
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
      result = await latestAuthState!.requestOtp('+35699123456');
    });

    expect(result).toBe(true);
    expect(invokeMock).toHaveBeenCalledWith('whatsapp-otp', {
      body: {
        action: 'send',
        phone: '+35699123456',
      },
    });
  });

  it('verifies the WhatsApp OTP and persists the custom bearer session', async () => {
    invokeMock.mockResolvedValue({
      data: {
        success: true,
        access_token: 'access-token',
        expires_at: 1_800_000_000,
        user: {
          id: 'user-1',
          phone: '+35699123456',
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
      result = await latestAuthState!.verifyOtp('+35699123456', '123456');
    });

    expect(result).toBe(true);
    expect(persistAdminSessionMock).toHaveBeenCalledWith({
      accessToken: 'access-token',
      userId: 'user-1',
      expiresAt: 1_800_000_000,
      phone: '+35699123456',
    });

    await waitFor(() => {
      expect(latestAuthState?.admin?.user_id).toBe('user-1');
      expect(latestAuthState?.session?.accessToken).toBe('access-token');
    });
  });
});
