export interface Partner {
  id: string;
  name: string;
  slug: string | null;
  category: string;
  description: string | null;
  logo_url: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  website_url: string | null;
  country: string;
  market: string;
  status: string;
  is_featured: boolean;
  approved_by: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface Reward {
  id: string;
  partner_id: string | null;
  title: string;
  description: string | null;
  category: string | null;
  fet_cost: number;
  original_value: string | null;
  currency: string;
  image_url: string | null;
  inventory_total: number | null;
  inventory_remaining: number | null;
  valid_from: string | null;
  valid_until: string | null;
  country: string;
  market: string;
  is_featured: boolean;
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface Redemption {
  id: string;
  user_id: string;
  reward_id: string | null;
  partner_id: string | null;
  fet_amount: number;
  status: string;
  redemption_code: string | null;
  admin_notes: string | null;
  reviewed_by: string | null;
  fraud_flag: boolean;
  created_at: string;
  updated_at: string;
}
