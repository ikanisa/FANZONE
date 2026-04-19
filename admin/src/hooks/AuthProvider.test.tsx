// @vitest-environment jsdom
import { act, render, waitFor } from '@testing-library/react';
import { useContext, useEffect } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Session } from '@supabase/supabase-js';

import { AuthContext, type AuthState } from './auth-context';
import { AuthProvider } from './AuthProvider';

const {
  invokeMock,
  getSessionMock,
  onAuthStateChangeMock,
  setSessionMock,
  signOutMock,
  fromMock,
} = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  getSessionMock: vi.fn(),
  onAuthStateChangeMock: vi.fn(),
  setSessionMock: vi.fn(),
  signOutMock: vi.fn(),
  fromMock: vi.fn(),
}));

vi.mock('../lib/supabase', () => ({
  isSupabaseConfigured: true,
  supabase: {
    auth: {
      getSession: getSessionMock,
      onAuthStateChange: onAuthStateChangeMock,
      setSession: setSessionMock,
      signOut: signOutMock,
    },
    functions: {
      invoke: invokeMock,
    },
    from: fromMock,
  },
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
  let authStateCallback: ((event: string, session: Session | null) => void) | null;

  beforeEach(() => {
    latestAuthState = null;
    authStateCallback = null;

    getSessionMock.mockResolvedValue({
      data: { session: null },
    });

    onAuthStateChangeMock.mockImplementation((callback) => {
      authStateCallback = callback;
      return {
        data: {
          subscription: {
            unsubscribe: vi.fn(),
          },
        },
      };
    });

    setSessionMock.mockResolvedValue({
      data: { session: null, user: null },
      error: null,
    });

    signOutMock.mockResolvedValue({ error: null });

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

  it('verifies the WhatsApp OTP and establishes a browser session from the custom token response', async () => {
    const signedInSession = {
      user: {
        id: 'user-1',
      },
    } as Session;

    invokeMock.mockResolvedValue({
      data: {
        success: true,
        access_token: 'access-token',
        refresh_token: null,
      },
      error: null,
    });

    setSessionMock.mockImplementation(async () => {
      authStateCallback?.('SIGNED_IN', signedInSession);
      return {
        data: { session: signedInSession, user: signedInSession.user },
        error: null,
      };
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
    expect(setSessionMock).toHaveBeenCalledWith({
      access_token: 'access-token',
      refresh_token: 'access-token',
    });

    await waitFor(() => {
      expect(latestAuthState?.admin?.user_id).toBe('user-1');
    });
  });
});
