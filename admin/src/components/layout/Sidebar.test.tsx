// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { MemoryRouter } from 'react-router-dom';

import type { AdminRole } from '../../config/constants';
import { Sidebar } from './Sidebar';
import { AuthContext, type AuthState } from '../../hooks/auth-context';

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

function buildAuthState(role: AdminRole): AuthState {
  return {
    session: null,
    admin: {
      ...baseAdmin,
      role,
      display_name: `${role} user`,
    },
    isLoading: false,
    error: null,
    requestOtp: async () => true,
    verifyOtp: async () => true,
    signOut: async () => {},
  };
}

function renderSidebar(role: AdminRole, initialPath = '/') {
  return render(
    <AuthContext.Provider value={buildAuthState(role)}>
      <MemoryRouter initialEntries={[initialPath]}>
        <Sidebar />
      </MemoryRouter>
    </AuthContext.Provider>,
  );
}

describe('Sidebar RBAC', () => {
  it('shows only viewer-safe navigation for viewer role', () => {
    renderSidebar('viewer');

    expect(screen.getByRole('link', { name: 'Dashboard' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Analytics' })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Users' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'FET Tokens' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Settings' })).toBeNull();
  });

  it('shows admin operations but hides super-admin controls for admin role', () => {
    renderSidebar('admin');

    expect(screen.getByRole('link', { name: 'Users' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Notifications' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Audit Logs' })).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Settings' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Admin Access' })).toBeNull();
  });

  it('shows system controls for super-admin role', () => {
    renderSidebar('super_admin');

    expect(screen.getByRole('link', { name: 'Settings' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Admin Access' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Users' })).toBeTruthy();
  });
});
