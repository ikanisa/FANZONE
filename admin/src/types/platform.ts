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
