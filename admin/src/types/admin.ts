import type { AdminRole } from "../config/constants";

export interface AdminUser {
  id: string;
  user_id: string;
  phone: string | null;
  display_name: string;
  role: AdminRole;
  permissions: Record<string, boolean>;
  is_active: boolean;
  invited_by: string | null;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface AuditLog {
  id: string;
  admin_user_id: string;
  action: string;
  module: string;
  target_type: string | null;
  target_id: string | null;
  before_state: Record<string, unknown> | null;
  after_state: Record<string, unknown> | null;
  metadata: Record<string, unknown>;
  ip_address: string | null;
  created_at: string;
  admin_name?: string;
  admin_phone?: string;
}

export interface AdminNote {
  id: string;
  admin_user_id: string;
  target_type: string;
  target_id: string;
  content: string;
  created_at: string;
  admin_name?: string;
}

export interface FeatureFlag {
  id: string;
  key: string;
  label: string;
  description: string | null;
  is_enabled: boolean;
  market: string;
  module: string | null;
  config: Record<string, unknown>;
  updated_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface RuntimeConfigEntry {
  key: string;
  value: unknown;
  created_at: string;
  updated_at: string;
}

export interface LaunchMoment {
  tag: string;
  title: string;
  subtitle: string;
  kicker: string;
  region_key: string;
  sort_order: number;
  is_active: boolean;
  updated_at: string;
}

export interface PhonePreset {
  country_code: string;
  dial_code: string;
  hint: string;
  min_digits: number;
  updated_at: string;
}

export interface CurrencyDisplayMetadata {
  currency_code: string;
  symbol: string;
  decimals: number;
  space_separated: boolean;
  updated_at: string;
}

export interface CountryRegionEntry {
  country_code: string;
  region: string;
  country_name: string;
  flag_emoji: string;
  updated_at: string;
}

export interface CountryCurrencyEntry {
  country_code: string;
  currency_code: string;
  country_name: string | null;
  updated_at: string;
}
