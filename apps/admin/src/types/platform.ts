export interface PlatformUser {
  id: string;
  email: string | null;
  phone: string | null;
  raw_user_meta_data: Record<string, unknown>;
  created_at: string;
  last_sign_in_at: string | null;
  display_name?: string | null;
  status?: string;
  ban_reason?: string | null;
  suspend_reason?: string | null;
  wallet_freeze_reason?: string | null;
  available_balance_fet?: number;
  locked_balance_fet?: number;
}

export interface Wallet {
  user_id: string;
  available_balance_fet: number;
  locked_balance_fet: number;
  updated_at: string;
  created_at: string;
}

export interface WalletTransaction {
  id: string;
  user_id: string;
  tx_type: string;
  direction: string;
  amount_fet: number;
  balance_before_fet: number;
  balance_after_fet: number;
  reference_type: string | null;
  reference_id: string | null;
  metadata: Record<string, unknown> | null;
  title: string | null;
  created_at: string;
  display_name?: string;
  flagged?: boolean;
}

export interface PlatformFeatureChannelConfig {
  channel: "mobile" | "web";
  is_visible: boolean;
  is_enabled: boolean;
  show_in_navigation: boolean;
  show_on_home: boolean;
  sort_order: number;
  route_key: string | null;
  entry_key: string | null;
  navigation_label: string | null;
  placement_key: string | null;
  metadata: Record<string, unknown>;
}

export interface PlatformFeatureRecord {
  id: string;
  feature_key: string;
  display_name: string;
  description: string | null;
  status: "active" | "inactive" | "hidden" | "beta" | "scheduled" | string;
  is_enabled: boolean;
  navigation_group: string | null;
  default_route_key: string | null;
  admin_notes: string | null;
  metadata: Record<string, unknown>;
  auth_required: boolean;
  role_restrictions: unknown;
  dependency_config: Record<string, unknown>;
  rollout_config: Record<string, unknown>;
  schedule_start_at: string | null;
  schedule_end_at: string | null;
  mobile_channel: PlatformFeatureChannelConfig;
  web_channel: PlatformFeatureChannelConfig;
  created_at: string;
  updated_at: string;
}

export interface PlatformContentBlockRecord {
  id: string;
  block_key: string;
  block_type: string;
  title: string;
  content: Record<string, unknown>;
  target_channel: "mobile" | "web" | "both";
  is_active: boolean;
  sort_order: number;
  feature_key: string | null;
  feature_display_name: string | null;
  placement_key: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}
