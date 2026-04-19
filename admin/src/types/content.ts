export interface ContentBanner {
  id: string;
  title: string;
  subtitle: string | null;
  image_url: string | null;
  action_url: string | null;
  placement: string;
  priority: number;
  country: string;
  is_active: boolean;
  valid_from: string | null;
  valid_until: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface Campaign {
  id: string;
  title: string;
  message: string;
  type: string;
  segment: Record<string, unknown>;
  status: string;
  scheduled_at: string | null;
  sent_at: string | null;
  recipient_count: number;
  country: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface ModerationReport {
  id: string;
  reporter_user_id: string | null;
  target_type: string;
  target_id: string;
  reason: string;
  description: string | null;
  status: string;
  severity: string;
  assigned_to: string | null;
  resolution_notes: string | null;
  created_at: string;
  updated_at: string;
}
