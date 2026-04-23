export interface ModerationReport {
  id: string;
  reporter_user_id: string | null;
  target_type: string;
  target_id: string;
  reason: string;
  description: string | null;
  severity: string;
  status: string;
  resolution_notes: string | null;
  created_at: string;
  updated_at: string;
}
