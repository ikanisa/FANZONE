import type { AdminRole } from '../config/constants';

export interface AdminUser {
  id: string;
  user_id: string;
  email: string;
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
  admin_email?: string;
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
