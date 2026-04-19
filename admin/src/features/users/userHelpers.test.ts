import { describe, expect, it } from 'vitest';

import type { PlatformUser } from '../../types';
import { getUserDisplayName, getUserStatus } from './userHelpers';

const baseUser: PlatformUser = {
  id: 'user-1',
  email: null,
  phone: null,
  raw_user_meta_data: {},
  created_at: '2026-01-01T00:00:00.000Z',
  last_sign_in_at: null,
};

describe('userHelpers', () => {
  it('prefers explicit display_name over metadata and contact fields', () => {
    const displayName = getUserDisplayName({
      ...baseUser,
      display_name: 'Primary Name',
      raw_user_meta_data: { display_name: 'Fallback Name' },
      email: 'user@example.com',
    });

    expect(displayName).toBe('Primary Name');
  });

  it('falls back to metadata display name and status flags', () => {
    const displayName = getUserDisplayName({
      ...baseUser,
      raw_user_meta_data: { display_name: 'Metadata Name', wallet_frozen: true },
    });
    const status = getUserStatus({
      ...baseUser,
      raw_user_meta_data: { wallet_frozen: true },
    });

    expect(displayName).toBe('Metadata Name');
    expect(status).toBe('frozen');
  });
});
