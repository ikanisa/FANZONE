import type { PlatformUser } from '../../types';

export function getUserDisplayName(user: PlatformUser): string {
  const metadataDisplayName = user.raw_user_meta_data.display_name;

  return user.display_name ||
    (typeof metadataDisplayName === 'string' ? metadataDisplayName : null) ||
    user.email ||
    user.phone ||
    'Unknown user';
}

export function getUserStatus(user: PlatformUser): string {
  if (user.status) return user.status;
  if (user.raw_user_meta_data.wallet_frozen) return 'frozen';
  if (user.raw_user_meta_data.is_banned) return 'banned';
  if (user.raw_user_meta_data.is_suspended) return 'suspended';
  return 'active';
}
