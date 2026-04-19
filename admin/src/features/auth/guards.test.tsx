// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { MemoryRouter, Route, Routes } from 'react-router-dom';

import type { AdminRole } from '../../config/constants';
import { AuthContext, type AuthState } from '../../hooks/auth-context';
import { AuthGuard } from './AuthGuard';
import { RoleGuard } from './RoleGuard';

const baseAdmin = {
  id: 'test-admin-001',
  user_id: 'test-user-001',
  phone: '+35699123456',
  display_name: 'Test admin',
  role: 'super_admin' as const,
  permissions: {},
  is_active: true,
  invited_by: null,
  last_login_at: '2026-01-01T00:00:00.000Z',
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
};

function buildAuthState({
  role,
  isLoading = false,
}: {
  role?: AdminRole;
  isLoading?: boolean;
}): AuthState {
  return {
    session: null,
    admin: role
        ? {
            ...baseAdmin,
            role,
            display_name: `${role} user`,
          }
        : null,
    isLoading,
    error: null,
    requestOtp: async () => true,
    verifyOtp: async () => true,
    signOut: async () => {},
  };
}

function renderWithAuth(ui: React.ReactNode, authState: AuthState) {
  return render(
    <AuthContext.Provider value={authState}>
      <MemoryRouter>{ui}</MemoryRouter>
    </AuthContext.Provider>,
  );
}

describe('admin auth and role guards', () => {
  it('redirects unauthenticated users to login', () => {
    render(
      <AuthContext.Provider value={buildAuthState({})}>
        <MemoryRouter initialEntries={['/protected']}>
          <Routes>
            <Route path="/login" element={<div>Login page</div>} />
            <Route
              path="/protected"
              element={
                <AuthGuard>
                  <div>Protected page</div>
                </AuthGuard>
              }
            />
          </Routes>
        </MemoryRouter>
      </AuthContext.Provider>,
    );

    expect(screen.getByText('Login page')).toBeTruthy();
    expect(screen.queryByText('Protected page')).toBeNull();
  });

  it('shows a loading state while auth is resolving', () => {
    renderWithAuth(
      <AuthGuard>
        <div>Protected page</div>
      </AuthGuard>,
      buildAuthState({ isLoading: true }),
    );

    expect(screen.getByText('Loading...')).toBeTruthy();
  });

  it('blocks users below the required role', () => {
    renderWithAuth(
      <RoleGuard minRole="admin">
        <div>Manage users</div>
      </RoleGuard>,
      buildAuthState({ role: 'moderator' }),
    );

    expect(screen.getByText('Access Denied')).toBeTruthy();
    expect(screen.queryByText('Manage users')).toBeNull();
  });

  it('renders protected content when the role requirement is satisfied', () => {
    renderWithAuth(
      <RoleGuard minRole="moderator">
        <div>Moderation queue</div>
      </RoleGuard>,
      buildAuthState({ role: 'admin' }),
    );

    expect(screen.getByText('Moderation queue')).toBeTruthy();
    expect(screen.queryByText('Access Denied')).toBeNull();
  });
});
