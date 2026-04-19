// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { MemoryRouter } from 'react-router-dom';

import type { AdminRole } from '../../config/constants';
import { Sidebar } from './Sidebar';
import { AuthContext, DEMO_ADMIN, type AuthState } from '../../hooks/auth-context';

function buildAuthState(role: AdminRole): AuthState {
  return {
    session: null,
    admin: {
      ...DEMO_ADMIN,
      role,
      display_name: `${role} user`,
    },
    isLoading: false,
    error: null,
    signIn: async () => {},
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
